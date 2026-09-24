#include <ppsi/ppsi.h>

/*
 * PP_NP_GEN/EVT is the event or general message. It selects the socket etc
 * P2P is used to select a destination address for pdelay frames.
 * the numeric 0..5 is the "controlField" (magic ptpV1 numbers in byte 32).
 * PP_LOG is the kind of logInterval to put in byte 33.
 */
const struct pp_msgtype_info pp_msgtype_info[] = {
	[PPM_SYNC_FMT] = {
		PPM_SYNC, PP_SYNC_LENGTH,
		PP_NP_EVT, MECH_E2E,  0, PP_LOG_SYNC },
	[PPM_DELAY_REQ_FMT] = {
			PPM_DELAY_REQ, PP_DELAY_REQ_LENGTH,
		PP_NP_EVT, MECH_E2E, 1, 0x7f },
	[PPM_PDELAY_REQ_FMT] = {
			PPM_PDELAY_REQ,PP_PDELAY_REQ_LENGTH,
		PP_NP_EVT, MECH_P2P, 5, 0x7f },
	[PPM_PDELAY_RESP_FMT] = {
			PPM_PDELAY_RESP, PP_PDELAY_RESP_LENGTH,
		PP_NP_EVT, MECH_P2P, 5, 0x7f },
	[PPM_FOLLOW_UP_FMT] = {
			PPM_FOLLOW_UP, PP_FOLLOW_UP_LENGTH,
		PP_NP_GEN, MECH_E2E, 2, PP_LOG_SYNC },
	[PPM_DELAY_RESP_FMT] = {
			PPM_DELAY_RESP, PP_DELAY_RESP_LENGTH,
		PP_NP_GEN, MECH_E2E, 3, PP_LOG_REQUEST },
	[PPM_PDELAY_R_FUP_FMT] = {
			PPM_PDELAY_R_FUP, PP_PDELAY_RESP_FOLLOW_UP_LENGTH,
		PP_NP_GEN, MECH_P2P, 5, 0x7f },
	[PPM_ANNOUNCE_FMT] = {
			PPM_ANNOUNCE, PP_ANNOUNCE_LENGTH,
		PP_NP_GEN, MECH_E2E, 5, PP_LOG_ANNOUNCE},
	[PPM_SIGNALING_FMT] = {
			PPM_SIGNALING, -1,
		PP_NP_GEN, MECH_E2E, 5, 0x7f},
	[PPM_SIGNALING_NO_FWD_FMT] = {
			PPM_SIGNALING, -1,
			PP_NP_GEN, MECH_P2P, 5, 0x7f},
/* We don't use management, or not in the table-driven code */
	[PPM_MANAGEMENT_FMT] = { PPM_MANAGEMENT, -1, PP_NP_GEN, MECH_E2E, 4, 0x7f},
};

const char  * const pp_msgtype_name[] = {
	[PPM_SYNC] = "sync",
	[PPM_DELAY_REQ] = "delay_req",
	[PPM_PDELAY_REQ] = "pdelay_req",
	[PPM_PDELAY_RESP] ="pdelay_resp",
	[PPM_FOLLOW_UP] = "follow_up",
	[PPM_DELAY_RESP] ="delay_resp",
	[PPM_PDELAY_R_FUP] ="pdelay_resp_follow_up",
	[PPM_ANNOUNCE] ="announce",
	[PPM_SIGNALING] ="signaling",
	[PPM_MANAGEMENT] ="management"
};
