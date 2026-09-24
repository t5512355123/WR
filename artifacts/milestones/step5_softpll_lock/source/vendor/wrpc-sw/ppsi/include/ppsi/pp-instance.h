#ifndef __PPSI_PP_INSTANCE_H__
#define __PPSI_PP_INSTANCE_H__

/*
 * The "instance structure is the most important object in ppsi: is is
 * now part of a separate header because ppsi.h must refer to it, and
 * to diagnostic macros, but also diag-macros.h needs to look at
 * ppi->flags.
 */
#ifndef __PPSI_PPSI_H__
#warning "Please include <ppsi/ppsi.h>, don't refer to pp-instance.h"
#endif

/*
 * Runtime options. Default values can be overridden by command line.
 */
struct pp_runtime_opts {
	uint32_t updated_fields_mask;
	int clock_quality_clockClass;                 // ClockQuality.clockClass
	int clock_quality_clockAccuracy;              // ClockQuality.clockAccuracy
	int clock_quality_offsetScaledLogVariance;    // ClockQuality.offsetScaledLogVariance
	int timeSource;                               // timePropertiesDS_t.timeSource
	Boolean ptpTimeScale;                         // timePropertiesDS_t.timeScale
	Boolean frequencyTraceable;                   // timePropertiesDS_t.frequencyTraceable
	Boolean timeTraceable;                        // timePropertiesDS_t.timeTraceable
	Integer32 ttl;
	int flags;		/* see below */
	Integer16 ap, ai;
	Integer16 s;
	int priority1;
	int priority2;
	int domainNumber;
	int ptpPpsThresholdMs;
	int gmDelayToGenPpsSec;
	Boolean externalPortConfigurationEnabled;
	Boolean slaveOnly;
	Boolean forcePpsGen;
	Boolean ptpFallbackPpsGen;
	void *arch_opts;
};

/*
 * Flags for the above structure
 */
#define PP_FLAG_NO_ADJUST  0x01
/* I'd love to use inlines, but we still miss some structure at this point*/
#define pp_can_adjust(ppi)      (!(OPTS(ppi)->flags & PP_FLAG_NO_ADJUST))

/* slave_only:1, -- moved to ppi, no more global */
/* master_only:1, -- moved to ppi, no more global */
/* ethernet_mode:1, -- moved to ppi, no more global */



/* We need globally-accessible structures with preset defaults */
extern struct pp_runtime_opts __pp_default_rt_opts;
extern const struct pp_instance_cfg __pp_default_instance_cfg;
/*
 * Communication channel. Is the abstraction of a unix socket, so that
 * this struct is platform independent
 */
#define PP_MAC_ADRESS_SIZE 6

struct pp_channel {
	union {
		int fd;		/* Posix wants fid descriptor */
		void *custom;	/* Other archs want other stuff */
	};
	void *arch_chan_data;	/* Other arch-private info, if any */
	unsigned char addr[PP_MAC_ADRESS_SIZE];	/* Our own MAC address */
	int pkt_present;
};


/*
 * Foreign master record. Used to manage Foreign masters. In the specific
 * it is called foreignMasterDS, see 9.3.2.4
 */
struct pp_frgn_master {
	/* BMC related information */
	UInteger16 sequenceId;
	UInteger16 stepsRemoved;
	Integer16 currentUtcOffset;
	/* on which port we received the frame */
	PortIdentity receivePortIdentity;
	PortIdentity sourcePortIdentity;
	ClockQuality grandmasterClockQuality;
	ClockIdentity grandmasterIdentity;
	UInteger8 grandmasterPriority1;
	UInteger8 grandmasterPriority2;
	Enumeration8 timeSource;
	Octet flagField[2];
	/* Private data */
	Boolean  qualified; // TRUE if qualified
	unsigned long lastAnnounceMsgMs; // Last time in ms when the announce message was received
	/* used by extension */
	UInteger16      ext_specific[4]; /* Extension specific. Must be  UInteger16 to align it in the structure*/
	unsigned char peer_mac[6];
};

/*
 * Servo. Structs which contain filters for delay average computation. They
 * are used in servo.c src, where specific function for time setting of the
 * machine are implemented.
 *
 * pp_avg_fltr: It is a variable cutoff/delay low-pass, infinite impulse
 * response (IIR) filter. The meanDelay filter has the difference equation:
 * s*y[n] - (s-1)*y[n-1] = x[n]/2 + x[n-1]/2,
 * where increasing the stiffness (s) lowers the cutoff and increases the delay.
 */
struct pp_avg_fltr {
	int64_t m; /* magnitude */
	int64_t y;
	int64_t s_exp;
};

/* Servo flags for communication diagnostic tool */

#define PP_SERVO_FLAG_VALID	    (1<<0)
#define PP_SERVO_FLAG_WAIT_HW	(1<<1)

#define PP_SERVO_RESET_DATA_SIZE        (sizeof(struct pp_servo)-offsetof(struct pp_servo,state))
#define PP_SERVO_RESET_DATA(servo)      memset(&servo->state,0,PP_SERVO_RESET_DATA_SIZE);

struct pp_servo {
	/* ptp servo specific data */
	long long obs_drift;
	struct pp_avg_fltr mpd_fltr;

	/* Data shared with extension servo */
	struct pp_time delayMM; /* Shared with extension servo */
	struct pp_time delayMS; /* Shared with extension servo */
	struct pp_time meanDelay; /* Shared with extension servo */
	struct pp_time offsetFromMaster; /* Shared with extension servo */
	uint8_t flags; /* PP_SERVO_FLAG_INVALID, PP_SERVO_FLAG_VALID, ...*/

	/*
	 * ----- All data after this line will be cleared during by a servo initialization
	 */
	/* Data used only by extensions */
	uint8_t state;

	/* ptp servo specific data */
	uint8_t servo_locked; /* TRUE when servo is locked. This info can be used by HAL */
	uint8_t got_sync; /* True when T1/T2 are available */

	const char *servo_state_name; /* Updated by the servo itself */

	/* Data shared with extension servo */
	uint32_t update_count; /* incremented each time the servo is running */
	struct pp_time update_time; /* Last updated time of the servo */
	struct pp_time t1, t2, t3, t4, t5, t6;
};

enum { /* The two sockets. They are called "net path" for historical reasons */
	PP_NP_GEN =	0,
	PP_NP_EVT,
	__NR_PP_NP,
};

/*
 * Struct containg the result of ppsi.conf parsing: one for each link
 * (see lib/conf.c). Actually, protocol are in the main ppi.
 */
struct pp_instance_cfg {
 	char port_name[16];
	char iface_name[16];
	int  profile;   /* PPSI_PROFILE_PTP, PPSI_PROFILE_WR, PPSI_PROFILE_HA */
	int delayMechanism;   /* Should be enum ENDelayMechanism but forced to int for configuration parsing */
	int announce_interval; /* Announce messages interval */
	int announce_receipt_timeout; /* Announce interval receipt timeout*/
	int sync_interval; /* Sync messages interval */
	int min_delay_req_interval; /* delay request messages interval */
	int min_pdelay_req_interval;/* pdelay request messages interval */
#if	CONFIG_HAS_EXT_L1SYNC
	Boolean l1SyncEnabled; /* L1SYNC: protocol enabled */
	Boolean l1SyncRxCoherencyIsRequired; /* L1SYNC: Rx coherency is required */
	Boolean l1SyncTxCoherencyIsRequired; /* L1SYNC: Tx coherency is required */
	Boolean l1SyncCongruencyIsRequired; /* L1SYNC: Congruency isrRequired */
	Boolean l1SyncOptParamsEnabled; /* L1SYNC: Optional parameters enabled */
	int l1syncInterval; /* L1SYNC: l1sync messages interval */
	int l1syncReceiptTimeout; /* L1SYNC: l1sync messages receipt timeout */
	Boolean  l1SyncOptParamsTimestampsCorrectedTx; /* L1SYNC: correction of the transmitted egress timestamps */
#endif
	int64_t egressLatency_ps; /* egressLatency in picos */
	int64_t ingressLatency_ps; /* ingressLatency in picos */
	int64_t constantAsymmetry_ps; /* constantAsymmetry in picos */
	double delayCoefficient; /* fiber delay coefficient as a double */
	int64_t scaledDelayCoefficient; /* fiber delay coefficient as RelativeDifference type */
	int desiredState; /* externalPortConfigurationPortDS.desiredState */
	Boolean masterOnly; /* masterOnly */
	Boolean asymmetryCorrectionEnable; /* asymmetryCorrectionPortDS.enable */
};

/*
 * This enumeration correspond to the protocol detection state of a pp_instance.
 * It is used to decide which instance/protocol must be active on a given port.
 */
typedef enum  {
	PP_PDSTATE_NONE, /* Link state not applied : No extension */
	PP_PDSTATE_WAIT_MSG, /* Waiting fist message */
	PP_PDSTATE_PDETECTION, /* Checking if the peer instance is using the same protocol */
	PP_PDSTATE_PDETECTED,  /* Expected protocol detected*/
	PP_PDSTATE_FAILURE, /* Impossible to connect correctly to a peer instance - extension disabled */
} pp_pdstate_t;


typedef enum {
	PP_EXSTATE_DISABLE, /* Extension is disabled */
	PP_EXSTATE_ACTIVE, /* Extension active */
	PP_EXSTATE_PTP /* Extension uses only PTP protocol */
} pp_exstate_t;
/*
 * Structure for the individual ppsi link
 */
struct pp_instance {
	int state;
	int next_state, next_delay, is_new_state; /* set by state processing */
	const struct pp_state_table_item *current_state_item;
	void *arch_inst_data;		/* if arch needs it */
	void *ext_data;			/* if protocol ext needs it */
	int protocol_extension; /* PPSI_EXT_NONE, PPSI_EXT_WR, PPSI_EXT_L1S */
	const struct pp_ext_hooks *ext_hooks; /* if protocol ext needs it */
	unsigned long d_flags;		/* diagnostics, ppi-specific flags */
	unsigned char flags;		/* protocol flags (see below) */
	int	proto;			/* same as in config file */
	int delayMechanism;			/* same as in config file */

	/* Pointer to global instance owning this pp_instance*/
	struct pp_globals *glbs;

	/* Operations that may be different in each instance */
	const struct pp_network_operations *n_ops;
	const struct pp_time_operations *t_ops;

	/*
	 * The buffer for this fsm are allocated. Then we need two
	 * extra pointer to track separately the frame and payload.
	 * So send/recv use the frame, pack/unpack use the payload.
	 */
	void *__tx_buffer, *__rx_buffer;
	void *tx_frame, *rx_frame, *tx_ptp, *rx_ptp;

	/* The net_path used to be allocated separately, but there's no need */
	struct pp_channel ch[__NR_PP_NP];	/* general and event ch */
	Integer32 mcast_addr[MECH_MAX_SUPPORTED + 1];	/* only ipv4/udp */
	int tx_offset, rx_offset;		/* ptp payload vs send/recv */
	unsigned char peer[6];			/* Our peer's MAC address from last received msg*/
	unsigned char activePeer[6];	/* Our peer's MAC address we talk with */
	uint16_t peer_vid;	/* Our peer's VID (for PROTO_VLAN) */

	/* Times, for the various offset computations */
	struct pp_time t1, t2, t3, t4, t5, t6;		/* *the* stamps */
	uint64_t syncCF;				/* transp. clocks */
	struct pp_time last_rcv_time, last_snt_time;	/* two temporaries */

	/* Page 85: each port shall maintain an implementation-specific
	 * foreignMasterDS data set for the purposes of qualifying Announce
	 * messages */
	UInteger16 frgn_rec_num;
	Integer16  frgn_rec_best;
	UInteger32 frgn_master_time_window_ms;
	struct pp_frgn_master frgn_master[PP_NR_FOREIGN_RECORDS];

	portDS_t *portDS;		 /* page 72 */
	struct pp_servo *servo;  /* Servo moved from globals because we may have more than one servo : redundancy */

	/** (IEEE1588-2019) */
	asymmetryCorrectionPortDS_t asymmetryCorrectionPortDS; /*draft P1588_v_29: page 99*/
	timestampCorrectionPortDS_t timestampCorrectionPortDS; /*draft P1588_v_29: page 99*/
	externalPortConfigurationPortDS_t  externalPortConfigurationPortDS; /*draft P1588: Clause 17.6.3*/
	/************************* */

	timeOutInstCnt_t tmo_cfg[PP_TO_COUNT];
	UInteger16 recv_sync_sequence_id;

	UInteger16 sent_seq[__PP_NR_MESSAGES_TYPES]; /* last sent this type */
	MsgHeader received_ptp_header;

	Boolean link_up;
	char *iface_name; /* for direct actions on hardware */
	char *port_name; /* for diagnostics, mainly */
	int port_idx;
	int vlans_array_len; /* those looking at shared mem must check */
	int vlans[CONFIG_VLAN_ARRAY_SIZE];
	int nvlans; /* according to configuration */
	struct pp_instance_cfg cfg;

	unsigned long ptp_tx_count;
	unsigned long ptp_rx_count;
	Boolean received_dresp; /* Count the number of delay response messages received for a given delay request */
	Boolean received_dresp_fup; /* Count the number of delay response follow up messages received for a given delay request */
	Boolean ptp_support; /* True if allow pure PTP support */
	Boolean bmca_execute; /* True: Ask fsm to run bmca state decision */
	pp_pdstate_t pdstate;  /* Protocol detection state */
	pp_exstate_t extState; /* Extension state */
};

/* The following things used to be bit fields. Other flags are now enums */
#define PPI_FLAG_WAITING_FOR_F_UP	0x02
#define PPI_FLAG_WAITING_FOR_RF_UP	0x04
#define PPI_FLAGS_WAITING		0x06 /* both of the above */

struct pp_globals_cfg {
	int cfg_items;			/* Remember how many we parsed */
	int cur_ppi_n;	/* Remember which instance we are configuring */
};

/*
 * Structure for the multi-port ppsi instance.
 */
struct pp_globals {
	struct pp_instance *pp_instances;

	/* Real time options */
	struct pp_runtime_opts *rt_opts;

	/* Data sets */
	defaultDS_t *defaultDS;			/* page 65 */
	currentDS_t *currentDS;			/* page 67 */
	parentDS_t *parentDS;			/* page 68 */
	timePropertiesDS_t *timePropertiesDS;	/* page 70 */

	/* Index of the pp_instance receiving the "Ebest" clock */
	int ebest_idx;
	int ebest_updated; /* set to 1 when ebest_idx changes */

	int nlinks;
	int max_links;
	struct pp_globals_cfg cfg;

	int rxdrop, txdrop;		/* fault injection, per thousand */

	void *arch_glbl_data;		/* if arch needs it */
	void *global_ext_data;		/* if protocol ext needs it */

	/* FIXME Here include all is common to many interfaces */
};

#endif /* __PPSI_PP_INSTANCE_H__ */
