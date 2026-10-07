/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Aurelio Colosimo
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */

#ifndef __PPSI_PPSI_H__
#define __PPSI_PPSI_H__
#include <generated/autoconf.h>

#include <stdint.h>
#include <limits.h>
#include <stdarg.h>
#include <float.h>
#include <stddef.h>
#include <ppsi/lib.h>
#include <ppsi/ieee1588_types.h>
#include <ppsi/constants.h>
#include <ppsi/jiffies.h>
#include <ppsi/timeout_def.h>
#include <ppsi/pp-instance.h>
#include <ppsi/diag-macros.h>
#include <ppsi/bmc.h>

#include <arch/arch.h> /* ntohs and so on -- and wr-api.h for wr archs */

/* Protocol extensions */
#include "../proto-ext-whiterabbit/wr-api.h"
#include "../proto-ext-l1sync/l1e-api.h"

/* At this point in time, we need ARRAY_SIZE to conditionally build vlan code */
#undef ARRAY_SIZE
#define ARRAY_SIZE(arr) (sizeof(arr) / sizeof((arr)[0]))

#define CAN_BE_UNUSED __attribute__ ((unused))

/* We can't include pp-printf.h when building freestading, so have it here */
extern int pp_printf(const char *fmt, ...)
	__attribute__((format(printf, 1, 2)));
extern int pp_vprintf(const char *fmt, va_list args)
	__attribute__((format(printf, 1, 0)));
extern int pp_sprintf(char *s, const char *fmt, ...)
	__attribute__((format(printf,2,3)));
extern int pp_vsprintf(char *buf, const char *, va_list)
	__attribute__ ((format (printf, 2, 0)));

/* This structure is never defined, it seems */
struct pp_vlanhdr {
	uint8_t h_dest[6];
	uint8_t h_source[6];
	uint16_t h_tpid;
	uint16_t h_tci;
	uint16_t h_proto;
};

/* Factorize some random information in this table */
struct pp_msgtype_info {
	pp_std_messages msg_type;
	uint16_t msglen;
	unsigned char chtype;
	unsigned char delay_mechanism;
	unsigned char controlField;		/* Table 23 */
	unsigned char logMessageInterval;	/* Table 24, see defines */

#define PP_LOG_ANNOUNCE  0
#define PP_LOG_SYNC      1
#define PP_LOG_REQUEST   2
};

/* Used as index for the pp_msgtype_info array */

enum pp_msg_format {
	PPM_SYNC_FMT		= 0x0,
	PPM_DELAY_REQ_FMT,
	PPM_PDELAY_REQ_FMT,
	PPM_PDELAY_RESP_FMT,
	PPM_FOLLOW_UP_FMT,
	PPM_DELAY_RESP_FMT,
	PPM_PDELAY_R_FUP_FMT,
	PPM_ANNOUNCE_FMT,
	PPM_SIGNALING_FMT,
	PPM_SIGNALING_NO_FWD_FMT,
	PPM_MANAGEMENT_FMT,
	PPM_MSG_FMT_MAX
};

extern const struct pp_msgtype_info pp_msgtype_info[];
extern const char  * const pp_msgtype_name[];

/* Helpers for the fsm (fsm-lib.c) */
extern int pp_lib_may_issue_sync(struct pp_instance *ppi);
extern int pp_lib_may_issue_announce(struct pp_instance *ppi);
extern int pp_lib_may_issue_request(struct pp_instance *ppi);

/* We use data sets a lot, so have these helpers */
static inline struct pp_globals *GLBS(struct pp_instance *ppi)
{
	return ppi->glbs;
}

static inline struct pp_instance *INST(struct pp_globals *ppg,
							int n_instance)
{
	return ppg->pp_instances + n_instance;
}

static inline struct pp_runtime_opts *GOPTS(struct pp_globals *ppg)
{
	return ppg->rt_opts;
}

static inline struct pp_runtime_opts *OPTS(struct pp_instance *ppi)
{
	return GOPTS(GLBS(ppi));
}

static inline defaultDS_t *GDSDEF(struct pp_globals *ppg)
{
	return ppg->defaultDS;
}

static inline  defaultDS_t *DSDEF(struct pp_instance *ppi)
{
	return GDSDEF(GLBS(ppi));
}

static inline currentDS_t *DSCUR(struct pp_instance *ppi)
{
	return GLBS(ppi)->currentDS;
}

static inline parentDS_t *DSPAR(struct pp_instance *ppi)
{
	return GLBS(ppi)->parentDS;
}

static inline portDS_t *DSPOR(struct pp_instance *ppi)
{
	return ppi->portDS;
}

static inline timePropertiesDS_t *DSPRO(struct pp_instance *ppi)
{
	return GLBS(ppi)->timePropertiesDS;
}

static inline timePropertiesDS_t *GDSPRO(struct pp_globals *ppg)
{
	return ppg->timePropertiesDS;
}

static inline const struct pp_time_operations *TOPS(struct pp_instance *ppi) {
	return ppi->t_ops;
}


/* We used to have a "netpath" structure. Keep this until we merge pdelay */
static struct pp_instance *NP(struct pp_instance *ppi)
	__attribute__((deprecated));

static inline struct pp_instance *NP(struct pp_instance *ppi)
{
	return ppi;
}

static inline struct pp_servo *SRV(struct pp_instance *ppi)
{
	return ppi->servo;
}

static inline int is_externalPortConfigurationEnabled (defaultDS_t *def) {
	return CONFIG_HAS_CODEOPT_EXT_PORT_CONF_FORCE_DISABLED == 0
		&& (CONFIG_HAS_CODEOPT_EPC_ENABLED
		    || def->externalPortConfigurationEnabled);
}

static inline int is_delayMechanismP2P(struct pp_instance *ppi) {
	return CONFIG_HAS_P2P && ppi->delayMechanism == MECH_P2P;
}

static inline int is_delayMechanismE2E(struct pp_instance *ppi) {
	return CONFIG_HAS_P2P==0 || ppi->delayMechanism == MECH_E2E;
}

static inline int is_slaveOnly(defaultDS_t *def) {
	return CONFIG_HAS_CODEOPT_SO_FORCE_DISABLED == 0 && CONFIG_HAS_CODEOPT_EPC_ENABLED==0 && def->slaveOnly;
}

static inline int is_masterOnly(portDS_t *portDS) {
#if CONFIG_HAS_CODEOPT_MO_FORCE_DISABLED
	return 0;
#else
	return portDS->masterOnly;
#endif
}


static inline int get_numberPorts(defaultDS_t *def) {
	return CONFIG_HAS_CODEOPT_SINGLE_PORT ? 1 : def->numberPorts;
}

extern void pp_prepare_pointers(struct pp_instance *ppi);

/*
 * Each extension should fill this structure that is used to augment
 * the standard states and avoid code duplications. Please remember
 * that proto-standard functions are picked as a fall-back when non
 * extension-specific code is provided. The set of hooks here is designed
 * based on what White Rabbit does. If you add more please remember to
 * allow NULL pointers.
 */
struct pp_ext_hooks {
	int (*init)(struct pp_instance *ppi, void *buf, int len);
	int (*open)(struct pp_instance *ppi, struct pp_runtime_opts *rt_opts);
	int (*close)(struct pp_instance *ppi);
	int (*listening)(struct pp_instance *ppi, void *buf, int len);
	int (*new_slave)(struct pp_instance *ppi, void *buf, int len);
	int (*handle_resp)(struct pp_instance *ppi);
	int (*handle_announce)(struct pp_instance *ppi);
	int (*handle_sync)(struct pp_instance *ppi);
	int (*handle_followup)(struct pp_instance *ppi);
	int (*handle_preq) (struct pp_instance * ppi);
	int (*handle_presp) (struct pp_instance * ppi);
	int (*handle_signaling) (struct pp_instance * ppi, void *buf, int len);
	int (*handle_dreq)(struct pp_instance *ppi);
	int (*pack_announce)(struct pp_instance *ppi);
	void (*unpack_announce)(struct pp_instance *ppi,void *buf, MsgAnnounce *ann);
	int (*ready_for_slave)(struct pp_instance *ppi); /* returns: 0=Not ready 1=ready */
	int (*state_decision)(struct pp_instance *ppi, int next_state);
	void (*state_change)(struct pp_instance *ppi);
	int (*run_ext_state_machine) (struct pp_instance *ppi, void *buf, int len);
	void (*servo_reset)(struct pp_instance *ppi);
	TimeInterval (*get_ingress_latency)(struct pp_instance *ppi);
	TimeInterval (*get_egress_latency)(struct pp_instance *ppi);
	int (*is_correction_field_compliant)(struct pp_instance *ppi); /* If not defined, it is assumed to be compliant */
	/* If the extension requires hardware support for precise time stamp, returns 1 */
	int (*require_precise_timestamp)(struct pp_instance *ppi);
	int (*get_tmo_lstate_detection) (struct pp_instance *ppi);
	int (*extension_state_changed)(struct pp_instance *ppi); /* Called when extension state as changed */
	int (*bmca_s1)(struct pp_instance *ppi,
			struct pp_frgn_master *frgn_master); /* Called at the end of the S1 treatment in the BMCA */
};

#define is_ext_hook_available(p, c) ( /*p->ext_enabled && */ p->ext_hooks->c)

/*
 * Network methods are encapsulated in a structure, so each arch only needs
 * to provide that structure. This simplifies management overall.
 */
struct pp_network_operations {
	int (*init)(struct pp_instance *ppi);
	int (*exit)(struct pp_instance *ppi);
	int (*recv)(struct pp_instance *ppi, void *pkt, int len,
		    struct pp_time *t);
	int (*send)(struct pp_instance *ppi, void *pkt, int len, enum pp_msg_format msg_fmt);
	int (*check_packet)(struct pp_globals *ppg, int delay_ms);
};

/* This is the struct pp_network_operations to be provided by time- dir */
extern const struct pp_network_operations DEFAULT_NET_OPS;

/* These can be liked and used as fallback by a different timing engine */
extern const struct pp_network_operations unix_net_ops;

/*
 * Time operations, like network operations above, are encapsulated.
 * They may live in their own time-<name> subdirectory.
 *
 * If "set" receives a NULL time value, it should update the TAI offset.
 */
struct pp_time_operations {
	int (*get_utc_time)(struct pp_instance *ppi, int *hours, int *minutes, int *seconds);
	int (*get_utc_offset)(struct pp_instance *ppi, int *offset, int *leap59, int *leap61);
	int (*set_utc_offset)(struct pp_instance *ppi, int offset, int leap59, int leap61);
	int (*get)(struct pp_instance *ppi, struct pp_time *t);
	int (*set)(struct pp_instance *ppi, const struct pp_time *t);
	/* freq_ppb is parts per billion */
	int (*adjust)(struct pp_instance *ppi, long offset_ns, long freq_ppb);
	int (*adjust_offset)(struct pp_instance *ppi, long offset_ns);
	int (*adjust_freq)(struct pp_instance *ppi, long freq_ppb);
	int (*init_servo)(struct pp_instance *ppi);
	unsigned long (*calc_timeout)(struct pp_instance *ppi, int millisec);
	int (*get_GM_lock_state)(struct pp_globals *ppg, pp_timing_mode_state_t *state);
	int (*enable_timing_output)(struct pp_globals *ppg,int enable);
};

#include "timeout_prot.h"

/* This is the struct pp_time_operations to be provided by time- dir */
extern const struct pp_time_operations DEFAULT_TIME_OPS;

/* These can be liked and used as fallback by a different timing engine */
extern const struct pp_time_operations unix_time_ops;


/* FIXME this define is no more used; check whether it should be
 * introduced again */
#define  PP_ADJ_NS_MAX		(500*1000)

/* FIXME Restored to value of ptpd. What does this stand for, exactly? */
#define  PP_ADJ_FREQ_MAX	512000

/* The channel for an instance must be created and possibly destroyed. */
extern int pp_init_globals(struct pp_globals *ppg, struct pp_runtime_opts *opts);
extern int pp_close_globals(struct pp_globals *ppg);

extern int pp_parse_cmdline(struct pp_globals *ppg, int argc, char **argv);


#define PPSI_PROTO_RAW		0
#define PPSI_PROTO_UDP		1
#define PPSI_PROTO_VLAN		2	/* Actually: vlan over raw eth */

/* Define the PPSI extensions */
#define PPSI_EXT_NONE	0
#define PPSI_EXT_WR		1   /* WR extension */ 
#define PPSI_EXT_L1S	2   /* L1SYNC extension */

/* Define the PPSI profiles */  
#define PPSI_PROFILE_PTP     0 /* Default PTP profile without extensions */
#define PPSI_PROFILE_WR      1 /* WR profile using WR extension */
#define PPSI_PROFILE_HA      2 /* HA profile using L1S extension, masterOnly and externalPortConfiguration options */
#define PPSI_PROFILE_CUSTOM  3 /* Custom profile. Give free access to all options and attributes */

/* Servo */
extern void pp_servo_init(struct pp_instance *ppi);
extern void pp_servo_got_sync(struct pp_instance *ppi,int allowTimingOutput); /* got t1 and t2 */
extern int pp_servo_got_resp(struct pp_instance *ppi, int allowTimingOutput); /* got all t1..t4 */
extern void pp_servo_got_psync(struct pp_instance *ppi); /* got t1 and t2 */
extern int pp_servo_got_presp(struct pp_instance *ppi); /* got all t3..t6 */
extern int pp_servo_calculate_delays(struct pp_instance *ppi);
extern RelativeDifference pp_servo_calculateDelayAsymCoefficient(RelativeDifference delayCoeff);

/* bmc.c */
extern void bmc_m1(struct pp_instance *ppi);
extern void bmc_m2(struct pp_instance *ppi);
extern void bmc_m3(struct pp_instance *ppi);
extern void bmc_s1(struct pp_instance *ppi, 
			   struct pp_frgn_master *frgn_master);
extern void bmc_p1(struct pp_instance *ppi);
extern void bmc_p2(struct pp_instance *ppi);
extern int bmc_idcmp(struct ClockIdentity *a, struct ClockIdentity *b);
extern int bmc_pidcmp(struct PortIdentity *a, struct PortIdentity *b);
extern void bmc_store_frgn_master(struct pp_instance *ppi, 
		       struct pp_frgn_master *frgn_master, void *buf, int len);
extern struct pp_frgn_master * bmc_add_frgn_master(struct pp_instance *ppi, struct pp_frgn_master *frgn_master);
extern void bmc_flush_erbest(struct pp_instance *ppi);
extern void bmc_calculate_ebest(struct pp_globals *ppg);
extern int bmc_apply_state_descision(struct pp_instance *ppi);
extern void bmc_update_clock_quality(struct pp_globals *ppg);

/* msg.c */
extern void msg_init_header(struct pp_instance *ppi, void *buf);
extern int msg_from_current_master(struct pp_instance *ppi);
extern int __attribute__((warn_unused_result))
	msg_unpack_header(struct pp_instance *ppi, void *buf, int len);
extern void msg_unpack_sync(void *buf, MsgSync *sync);
extern int msg_pack_sync(struct pp_instance *ppi, struct pp_time *orig_tstamp);
extern void msg_unpack_announce(struct pp_instance *ppi,void *buf, MsgAnnounce *ann);
extern void msg_unpack_follow_up(void *buf, MsgFollowUp *flwup);
extern void msg_unpack_delay_req(void *buf, MsgDelayReq *delay_req);
extern void msg_unpack_delay_resp(void *buf, MsgDelayResp *resp);
extern int msg_pack_signaling(struct pp_instance *ppi,PortIdentity *target_port_identity,
		UInteger16 tlv_type, UInteger16 tlv_length_field);
extern int msg_pack_signaling_no_fowardable(struct pp_instance *ppi,PortIdentity *target_port_identity,
		UInteger16 tlv_type, UInteger16 tlv_length_field);
void msg_unpack_signaling(void *buf, MsgSignaling *signaling);

/* pdelay */
extern void msg_unpack_pdelay_resp_follow_up(void *buf,
					     MsgPDelayRespFollowUp *
					     pdelay_resp_flwup);
extern void msg_unpack_pdelay_resp(void *buf, MsgPDelayResp * presp);
extern void msg_unpack_pdelay_req(void *buf, MsgPDelayReq * pdelay_req);

/* each of them returns 0 if ok, -1 in case of error in send, 1 if stamp err */
typedef enum {
	PP_SEND_OK=0,
	PP_SEND_ERROR=-1,
	PP_SEND_NO_STAMP=1,
    PP_SEND_DROP=-2,
	PP_RECV_DROP=PP_SEND_DROP
}pp_send_status;

extern void *msg_copy_header(MsgHeader *dest, MsgHeader *src); /* REMOVE ME!! */
extern int msg_issue_announce(struct pp_instance *ppi);
extern int msg_issue_sync_followup(struct pp_instance *ppi);
extern int msg_issue_request(struct pp_instance *ppi);
extern int msg_issue_delay_resp(struct pp_instance *ppi,
				struct pp_time *time);
extern int msg_issue_pdelay_resp_followup(struct pp_instance *ppi,
					  struct pp_time *time);
extern int msg_issue_pdelay_resp(struct pp_instance *ppi, struct pp_time *time);

/* Functions for time math */
extern void normalize_pp_time(struct pp_time *t);
extern void pp_time_add(struct pp_time *t1, const struct pp_time *t2);
extern void pp_time_sub(struct pp_time *t1, const struct pp_time *t2);
extern void pp_time_div2(struct pp_time *t);
extern TimeInterval pp_time_to_interval(struct pp_time *ts);
extern TimeInterval picos_to_interval(int64_t picos);
extern void pp_time_add_interval(struct pp_time *t1, TimeInterval t2);
extern void pp_time_sub_interval(struct pp_time *t1, TimeInterval t2);
extern int pp_timeout_log_to_ms(Integer8 logValue);
extern void fixedDelta_to_pp_time(struct FixedDelta fd, struct pp_time *t);

/* Function for time conversion */
extern int64_t pp_time_to_picos(struct pp_time *ts);
extern void picos_to_pp_time(int64_t picos, struct pp_time *ts);
extern void pp_time_hardwarize(struct pp_time *time, int clock_period_ps,int32_t *ticks, int32_t *picos);
extern int64_t interval_to_picos(TimeInterval interval);

extern char *time_to_string(struct pp_time *t);
extern char *interval_to_string(TimeInterval time);
extern char *relative_interval_to_string(RelativeDifference time);

int is_timestamp_incorrect_thres(struct pp_instance *ppsi, int *err_count, int ts_mask);

/*
 * The state machine itself is an array of these structures.
 */

/* Use a typedef, to avoid long prototypes */
typedef int pp_action(struct pp_instance *ppi, void *buf, int len);

struct pp_state_table_item {
	const char *name;
	pp_action *f1;
};

extern const struct pp_state_table_item pp_state_table[];

/* Convert current state as a string value */
const char *get_state_as_string(struct pp_instance *ppi, int state);

/* Standard state-machine functions */
extern pp_action pp_initializing, pp_faulty, pp_disabled, pp_listening,
		 pp_master, pp_passive, pp_uncalibrated,
		 pp_slave, pp_pclock, pp_abscal;

/* Enforce a state change */
extern int pp_leave_current_state(struct pp_instance *ppi);

/* The engine */
extern int pp_state_machine(struct pp_instance *ppi, void *buf, int len);

/* Frame-drop support -- rx before tx, alphabetically */
extern void ppsi_drop_init(struct pp_globals *ppg, unsigned long seed);
extern int ppsi_drop_rx(void);
extern int ppsi_drop_tx(void);

/* link state functions to manage the extension (Enable/disable) */
extern void pdstate_disable_extension(struct pp_instance * ppi);
extern void pdstate_set_state_pdetection(struct pp_instance * ppi);
extern void pdstate_set_state_pdetected(struct pp_instance * ppi);
extern void pdstate_enable_extension(struct pp_instance * ppi);

#include <ppsi/faults.h>
#include <ppsi/timeout_prot.h>
#include <ppsi/conf.h>


#endif /* __PPSI_PPSI_H__ */
