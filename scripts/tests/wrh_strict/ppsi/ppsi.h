/* Test-only hardware/API boundary. The production servo C is included intact. */
#ifndef WRH_STRICT_TEST_PPSI_H
#define WRH_STRICT_TEST_PPSI_H
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#define CONFIG_ARCH_IS_WRS 0
#define CONFIG_ARCH_IS_WRPC 1
#define __WRPC_H
enum { WRH_TM_GRAND_MASTER, WRH_TM_FREE_MASTER, WRH_TM_BOUNDARY_CLOCK, WRH_TM_DISABLED };
struct test_arch_data { int timingMode; };
extern struct test_arch_data test_arch;
#define WRPC_ARCH_I(p) (&test_arch)
#define CONFIG_HAS_P2P 0
#define TRUE 1
#define PP_EXSTATE_ACTIVE 1
#define PP_SERVO_FLAG_VALID 1
#define PP_SERVO_FLAG_WAIT_HW 2
#define WRH_SPLL_LOCKED 0
#define WRH_SERVO_OFFSET_STABILITY_THRESHOLD 60
enum { WRH_UNINITIALIZED, WRH_SYNC_TAI, WRH_SYNC_NSEC,
       WRH_SYNC_PHASE, WRH_TRACK_PHASE, WRH_WAIT_OFFSET_STABLE };
struct pp_time { int64_t secs, ps; };
struct pp_servo {
    int flags, state, servo_locked, got_sync;
    uint32_t update_count;
    const char *servo_state_name;
    struct pp_time update_time, delayMM, delayMS, offsetFromMaster, t1,t2,t3,t4,t5,t6;
};
typedef struct wrh_servo_t {
    uint32_t n_err_state, n_err_offset, n_err_delta_rtt;
    int32_t cur_setpoint_ps, clock_period_ps;
    int tracking_enabled, readyForSync, doRestart;
    int64_t delayMM_ps, delayMS_ps, skew_ps, offsetMS_ps, prev_delayMS_ps;
    int missed_iters;
} wrh_servo_t;
struct pp_instance { struct pp_servo *servo; void *ext_data; int extState, flags;
                     struct pp_time t1,t2,t3,t4,t5,t6; };
struct test_time_ops {
    int (*get)(struct pp_instance *,struct pp_time *);
    int (*set)(struct pp_instance *,struct pp_time *);
    int (*enable_timing_output)(void *,int);
};
struct test_wrh_ops {
    int (*locking_poll)(struct pp_instance *);
    int (*adjust_in_progress)(void);
    int (*adjust_counters)(int64_t,int32_t);
    int (*adjust_phase)(int32_t);
    int32_t (*get_clock_period)(void);
};
extern struct test_time_ops test_tops, unix_time_ops;
extern struct test_wrh_ops test_ops;
#define SRV(p) ((p)->servo)
#define WRH_SRV(p) ((wrh_servo_t *)(p)->ext_data)
#define TOPS(p) (&test_tops)
#define GLBS(p) ((void *)(p))
#define WRH_OPER() (&test_ops)
#define WRH_SERVO_RESET_DATA(s) memset(&(s)->clock_period_ps,0,sizeof(*(s))-offsetof(wrh_servo_t,clock_period_ps))
#define pp_diag(...) ((void)0)
#define pp_error(...) ((void)0)
void pp_servo_init(struct pp_instance *);
int pp_servo_calculate_delays(struct pp_instance *);
int64_t pp_time_to_picos(const struct pp_time *);
void pp_time_hardwarize(const struct pp_time *,int32_t,int32_t *,int32_t *);
int is_delayMechanismP2P(struct pp_instance *);
int is_timestamp_incorrect_thres(struct pp_instance *,int *,int);
void apply_faulty_stamp(struct pp_instance *,int);
const char *time_to_string(const struct pp_time *);
#endif
