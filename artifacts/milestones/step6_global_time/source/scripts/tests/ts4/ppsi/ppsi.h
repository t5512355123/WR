/* Native boundary stub: production wr-servo.c is included unmodified. */
#ifndef TS4_TEST_PPSI_H
#define TS4_TEST_PPSI_H
#include <stdint.h>
#include <string.h>
#define CONFIG_ARCH_IS_WRPC 1
#define __WRPC_H
#define __COMMON_FUN_H
#define PP_EXSTATE_ACTIVE 1
#define PPSI_EXT_WR 1
#define WRH_TM_BOUNDARY_CLOCK 2
struct pp_time { int64_t secs, scaled_nsecs; };
struct pp_servo {
    uint32_t update_count;
    unsigned state, got_sync, flags;
    struct pp_time t1,t2,t3,t4,delayMM,delayMS,meanDelay,offsetFromMaster;
};
typedef struct { int32_t cur_setpoint_ps; } wrh_servo_t;
typedef struct {
    struct pp_time delta_txm,delta_rxm,delta_txs,delta_rxs;
    struct pp_time rawT1,rawT2,rawT3,rawT4,rawT5,rawT6,rawDelayMM;
} wr_servo_ext_t;
struct test_wr_data { wrh_servo_t servo; wr_servo_ext_t servo_ext; };
struct test_port { int64_t delayAsymmetry; };
struct pp_instance {
    int protocol_extension,extState;
    struct pp_time t1,t2,t3,t4,t5,t6;
    struct pp_servo *servo;
    struct test_wr_data *ext_data;
    struct test_port *portDS;
    uint16_t recv_sync_sequence_id;
    struct {
        unsigned messageType,domainNumber;
        uint16_t sequenceId;
        struct { struct { unsigned char id[8]; } clockIdentity; uint16_t portNumber; } sourcePortIdentity;
    } received_ptp_header;
};
struct test_arch { int timingMode; };
extern struct test_arch ts_arch;
#define WRPC_ARCH_I(p) (&ts_arch)
#define SRV(p) ((p)->servo)
#define WRH_SRV(p) (&(p)->ext_data->servo)
#define WRE_SRV(p) (&(p)->ext_data->servo_ext)
int is_delayMechanismE2E(struct pp_instance *);
int is_delayMechanismP2P(struct pp_instance *);
void pp_time_add(struct pp_time *,const struct pp_time *);
void pp_time_sub(struct pp_time *,const struct pp_time *);
int wrh_servo_init(struct pp_instance *);
int wrh_servo_got_sync(struct pp_instance *);
int wrh_servo_got_resp(struct pp_instance *);
int wrh_servo_got_presp(struct pp_instance *);
#endif
