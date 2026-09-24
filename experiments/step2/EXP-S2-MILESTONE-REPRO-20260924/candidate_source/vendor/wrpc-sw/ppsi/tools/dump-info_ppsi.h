/*
 * This header defines structures for dumping other structures from
 * binary files. Every arch has a different endianness and alignment/size,
 * so we can't just use the structures from the host compiler. It used to
 * work for lm32/i386, but it fails with x86-64, so let's change attitude.
 */

#include <stdint.h>

/*
 * To ease copying from header files, allow int, char and other known types.
 * Please add more type as more structures are included here
 */
enum dump_type_ppsi {
	dump_type_UInteger64 = 100,
	dump_type_Integer64,
	dump_type_UInteger32,
	dump_type_Integer32,
	dump_type_UInteger16,
	dump_type_Integer16,
	dump_type_UInteger8,
	dump_type_Integer8,
	dump_type_Enumeration8,
	dump_type_UInteger4,
	dump_type_Boolean,
	dump_type_ClockIdentity,
	dump_type_PortIdentity,
	dump_type_ClockQuality,
	dump_type_TimeInterval,
	dump_type_RelativeDifference,
	dump_type_FixedDelta,
	dump_type_Timestamp,
	dump_type_scaledPicoseconds,

	/* and this is ours */
	dump_type_yes_no_Boolean,
	dump_type_pp_time,
	dump_type_delay_mechanism,
	dump_type_protocol_extension,
	dump_type_wrpc_mode_cfg,
	dump_type_timing_mode,
	dump_type_ppi_state,
	dump_type_ppi_state_Enumeration8,
	dump_type_wr_config,
	dump_type_wr_config_Enumeration8,
	dump_type_wr_role,
	dump_type_wr_role_Enumeration8,
	dump_type_pp_pdstate,
	dump_type_exstate,
	dump_type_pp_servo_flag,
	dump_type_pp_servo_state,
	dump_type_wr_state,
	dump_type_ppi_profile,
	dump_type_ppi_proto,
	dump_type_ppi_flag,
};

typedef Boolean        yes_no_Boolean;
typedef int            delay_mechanism;
typedef int            protocol_extension;
typedef wrh_timing_mode_t timing_mode;
typedef int            wrpc_mode_cfg;
typedef int            ppi_state;
typedef Enumeration8   ppi_state_Enumeration8;
typedef int            wr_config;
typedef Enumeration8   wr_config_Enumeration8;
typedef int            wr_role;
typedef Enumeration8   wr_role_Enumeration8;
typedef pp_pdstate_t   pp_pdstate;
typedef pp_exstate_t   exstate;
typedef unsigned long  pp_servo_flag;
typedef int            pp_servo_state;
#if CONFIG_HAS_EXT_WR
typedef wr_state_t     wr_state;
#endif
typedef int            ppi_profile;
typedef int            ppi_proto;
typedef unsigned char  ppi_flag;
typedef FixedDelta     scaledPicoseconds;
