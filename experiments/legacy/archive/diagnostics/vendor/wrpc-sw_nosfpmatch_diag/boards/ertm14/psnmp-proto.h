#ifndef __PSNMP_PROTO_H
#define __PSNMP_PROTO_H

#include <hw/wrc_diags_regs.h>
#include <sensors.h>
#include "board-state.h"

/* visually recognizable opcodes */
#define ertm14_get_board_config		0x10
#define ertm14_set_board_config		0x11
#define ertm14_commit_board_config	0x12
#define ertm14_get_mmc_state		0x13
#define ertm14_get_wrc_diags		0x14
#define ertm14_get_wrc_nco		0x15
#define ertm14_subscribe_nco		0x16
#define ertm14_get_sim_board_config	0x17
#define	ertm14_comm_test		0x18
#define	ertm14_ptp_enable		0x19
#define	ertm14_get_sensors		0x20
#define	ertm14_get_version_info		0x21
#define	ertm14_get_fpga_info		0x22
#define	ertm14_get_streamers_diags	0x23
#define	ertm14_reset_streamers_stats	0x24
#define	ertm14_force_measure_channels_power	0x25
#define	ertm14_configure_spll_debug_dump	0x26
#define	ertm14_spll_debug_data	                0x27
#define	ertm14_exec_shell_command	        0x28

static struct ertm14_protocol_op {
	int8_t	opcode;
	size_t	offset1;
	size_t	length1;
	size_t	offset2;
	size_t	length2;
} protocol_ops[] = {
    {
	.opcode = ertm14_get_board_config,
	.offset1 = 1,
	.length1 = 0,
	.offset2 = 0,
	.length2 = sizeof(struct ertm14_board_state),
    },
    {
	.opcode = ertm14_set_board_config,
	.offset1 = 4,
	.length1 = sizeof(struct ertm14_board_state),
	.offset2 = 1,
	.length2 = 0,
    },
    {
	.opcode = ertm14_commit_board_config,
	.offset1 = 4,
	.length1 = sizeof(struct ertm14_board_state),
	.offset2 = 1,
	.length2 = 0,
    },
    {
	.opcode = ertm14_get_mmc_state,
	.offset1 = 1,
	.length1 = 0,
	.offset2 = 0,
	.length2 = sizeof(struct ertm14_mmc_state),
    },
    {
	.opcode = ertm14_get_version_info,
	.offset1 = 1,
	.length1 = 0,
	.offset2 = 0,
	.length2 = sizeof(struct ertm14_version_info),
    },
    {
	.opcode = ertm14_get_fpga_info,
	.offset1 = 1,
	.length1 = 0,
	.offset2 = 0,
	.length2 = sizeof(((struct ertm14_device_metadata *)0)->fpga_buildinfo_text),
    },
    {
	.opcode = ertm14_get_sensors,
	.offset1 = 1,
	.length1 = 0,
	.offset2 = 0,
	.length2 = sizeof(struct proto_wrc_sensor[ERTM14_MAX_SENSORS_COUNT]),
    },
    {
	.opcode = ertm14_get_wrc_diags,
	.offset1 = 1,
	.length1 = 0,
	.offset2 = 0,
	.length2 = sizeof(struct wrc_diags),
    },
    {
	.opcode = ertm14_get_streamers_diags,
	.offset1 = 1,
	.length1 = 0,
	.offset2 = 0,
	.length2 = sizeof(struct WR_STREAMERS_WB),
    },
    {
	.opcode = ertm14_get_wrc_nco,
	.offset1 = 1,
	.length1 = 0,
	.offset2 = 0,
	.length2 = sizeof(struct ertm14_nco_reset[2]),
    },
    {
	.opcode = ertm14_subscribe_nco,
	.offset1 = 4,
	.length1 = sizeof(struct ertm14_nco_reset),
	.offset2 = 0,
	.length2 = 0,
    },
    {
	.opcode = ertm14_ptp_enable,
	.offset1 = 1,
	.length1 = 1,
	.offset2 = 1,
	.length2 = 0,
    },
	{
	.opcode = ertm14_reset_streamers_stats,
	.offset1 = 1,
	.length1 = 1,
	.offset2 = 0,
	.length2 = 0,
    },
	{
	.opcode = ertm14_force_measure_channels_power,
	.offset1 = 1,
	.length1 = 1,
	.offset2 = 0,
	.length2 = 0,
    },
	{
	.opcode = ertm14_configure_spll_debug_dump,
	.offset1 = 4,
	.length1 = sizeof(struct ertm14_spll_debug_dump_request),
	.offset2 = 0,
	.length2 = 0,
    },
	{
	.opcode = ertm14_exec_shell_command,
	.offset1 = 4,
	.length1 = sizeof(struct ertm14_shell_command),
	.offset2 = 0,
	.length2 = 0,
    },
    {
	.opcode = -1,
    },
};

static const int protocol_nops = sizeof(protocol_ops)/sizeof(protocol_ops[0]);

static struct ertm14_protocol_op *get_proto_op(uint8_t opcode)
{
	int i;

	for (i = 0; i < protocol_nops; i++)
		if (protocol_ops[i].opcode == opcode)
			return &protocol_ops[i];
	return NULL;
}

/* auxiliary */
extern void board_to_host(struct ertm14_board_state *board, struct ertm14_board_state *host);

#endif /* __PSNMP_PROTO_H */
