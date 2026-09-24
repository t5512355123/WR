/*
 * Copyright (C) 2011 CERN (www.cern.ch)
 * Author: Alessandro Rubini
 *
 * Released to the public domain
 */
#include <ppsi/ppsi.h>

unsigned long pp_global_d_flags; /* This is the only "global" file in ppsi */

/*
 * This is somehow a duplicate of __pp_diag, but I still want
 * explicit timing in the fsm enter/stay/leave messages,
 * while there's no need to add times to all diagnostic messages
 */
static void pp_fsm_printf(struct pp_instance *ppi, const char *fmt, ...)
{
	va_list args;
	struct pp_time t;
	unsigned long oflags = pp_global_d_flags;

	if (!pp_diag_allow(ppi, fsm, 1))
		return;

	/* temporarily set NOTIMELOG, as we'll print the time ourselves */
	pp_global_d_flags |= PP_FLAG_NOTIMELOG;
	TOPS(ppi)->get(ppi, &t);
	pp_global_d_flags = oflags;

	pp_printf("diag-fsm-1-%s: %09d.%03d: ", ppi->port_name,
		  (int)t.secs, (int)((t.scaled_nsecs >> 16)) / 1000000);
	va_start(args, fmt);
	pp_vprintf(fmt, args);
	va_end(args);
}

/*
 * Diagnostics about state machine, enter, leave, remain
 */
enum {
	STATE_ENTER,
	STATE_LOOP,
	STATE_LEAVE
};

static void pp_diag_fsm(struct pp_instance *ppi, const char *name, int sequence,
			int len)
{
	switch (sequence) {
	case STATE_ENTER:
		/* enter with or without a packet len */
		pp_fsm_printf(ppi, "ENTER %s, packet len %i\n",
			  name, len);
		return;
	case STATE_LOOP:
		if (pp_diag_allow(ppi, fsm, 3))
			pp_fsm_printf(ppi, "%s: reenter in %i ms\n", name,
				      ppi->next_delay);
		return;
	case STATE_LEAVE:
		/* leave has one \n more, so different states are separate */
		pp_fsm_printf(ppi, "LEAVE %s (next: %3i)\n\n",
			      name, ppi->next_state);
		return;
	}
}

static const struct pp_state_table_item *
get_current_state_table_item(struct pp_instance *ppi)
{
	const struct pp_state_table_item *cur_ip = ppi->current_state_item;
	const struct pp_state_table_item *nxt_ip = &pp_state_table[ppi->state];

	if (cur_ip == nxt_ip) {
		ppi->is_new_state = 0;
	}
	else {
		ppi->is_new_state = 1;
		ppi->current_state_item = nxt_ip;
	}

	return nxt_ip;
}

const char *get_state_as_string(struct pp_instance *ppi, int state)
{
	if (state >= 0 && state < PPS_LAST_STATE)
		return pp_state_table[state].name;
	return "INVALID";
}

/*
 * Returns delay to next state, which is always zero.
 */
int pp_leave_current_state(struct pp_instance *ppi)
{
	/* If something has to be done in an extension */
	if ( ppi->ext_hooks->state_change) {
		// When leaving MASTER/SLAVE states, clear the active peer field
		if ( ppi->state==PPS_MASTER || ppi->state==PPS_SLAVE)
			bzero(ppi->activePeer,sizeof(ppi->activePeer));

		ppi->ext_hooks->state_change(ppi);
	}
	
	/* if the next or old state is non standard PTP reset all timeouts */
	if ((ppi->state >= PPS_LAST_STATE)
	    || (ppi->next_state >= PPS_LAST_STATE))
		pp_timeout_setall(ppi);

	ppi->state = ppi->next_state;
	if ( ppi->state==PPS_DISABLED ){
		ppi->pdstate = PP_PDSTATE_NONE; // Clear state
		/* clear extState so that it is displayed correctly in the wr_mon*/
		ppi->extState = PP_EXSTATE_DISABLE;
        }
	ppi->flags &= ~PPI_FLAGS_WAITING;
	pp_diag_fsm(ppi, ppi->current_state_item->name, STATE_LEAVE, 0);
	/* next_delay unused: go to new state now */
	return 0;
}

/*
 * Checks whether a packet has to be discarded and maybe updates port status
 * accordingly. Returns new packet length (0 if packet has to be discarded)
 */
static int pp_packet_prefilter(struct pp_instance *ppi)
{
	MsgHeader *hdr = &ppi->received_ptp_header;

	/*
	 * 9.5.1:
	 * Only PTP messages where the domainNumber field of the PTP message
	 * header (see 13.3.2.5) is identical to the defaultDS.domainNumber
	 * shall be accepted for processing by the protocol.
	 */
	if (hdr->domainNumber != GDSDEF(GLBS(ppi))->domainNumber) {
		pp_diag(ppi, frames, 1, "Wrong domain %i: discard\n",
			hdr->domainNumber);
		return -1;
	}

	/*
	 * Alternate masters (17.4) not supported
	 * 17.4.2, NOTE:
	 * A slave node that does not want to use information from alternate
	 * masters merely ignores all messages with alternateMasterFlag TRUE.
	 */
	if (hdr->flagField[0] & PP_ALTERNATE_MASTER_FLAG) {
		pp_diag(ppi, frames, 1, "Alternate master: discard\n");
		return -1;
	}

	/*
	 * If the message is from the same port that sent it, we should
	 * discard it (9.5.2.2)
	 */
	if (!memcmp(&ppi->received_ptp_header.sourcePortIdentity,
		    &DSPOR(ppi)->portIdentity,
		    sizeof(PortIdentity))) {
		pp_diag(ppi, frames, 1, "Looping frame: discard\n");
		return -1;
	}

	/*
	 * 9.5.2.3 & 9.5.2.2: For BCs the BMC (an extention to it)
	 * handles the Announce (go to Passive), other messages are dropped
	 */	
	if (!memcmp(&hdr->sourcePortIdentity.clockIdentity,
		&DSPOR(ppi)->portIdentity.clockIdentity,
		sizeof(ClockIdentity))) {
		if ( get_numberPorts(DSDEF(ppi)) > 1) {
			/* Announces are handled by the BMC, since otherwise the state 
			 * also the PASSIVE states in this case is overwritten */
			if (hdr->messageType != PPM_ANNOUNCE) {
				/* ignore messages, except announce coming from its own clock */
				return -1;	
			}		
		}
	}
	
	/** 9.2.5 State machines
	 * INITIALIZING: No port of the clock shall place any PTP messages on its communication path.
	 * FAULTY: A port in this state shall not place any PTP messages except for
	 *         management messages that are a required response to another management message on its
	 *         communication path
	 * DISABLED: The port shall not place any messages on its communication path
	 */
	if ( ppi->state==PPS_INITIALIZING || ppi->state==PPS_DISABLED || ppi->state==PPS_FAULTY ) {
		return -1;/* ignore messages all messages */
	}
	return 0;
}

/* used to make basic checks before the individual state is called */
static unsigned char type_length[__PP_NR_MESSAGES_TYPES] = {
	[PPM_SYNC]		= PP_SYNC_LENGTH,
	[PPM_DELAY_REQ]		= PP_DELAY_REQ_LENGTH,
	[PPM_PDELAY_REQ]	= PP_PDELAY_REQ_LENGTH,
	[PPM_PDELAY_RESP]	= PP_PDELAY_RESP_LENGTH,
	[PPM_FOLLOW_UP]		= PP_FOLLOW_UP_LENGTH,
	[PPM_DELAY_RESP]	= PP_DELAY_RESP_LENGTH,
	[PPM_PDELAY_R_FUP]	= PP_PDELAY_RESP_FOLLOW_UP_LENGTH,
	[PPM_ANNOUNCE]		= PP_ANNOUNCE_LENGTH,
	[PPM_SIGNALING]		= PP_HEADER_LENGTH,
	[PPM_MANAGEMENT]	= PP_MANAGEMENT_LENGTH,
};

static int fsm_unpack_verify_frame(struct pp_instance *ppi,
				   void *buf, int len)
{
	int msgtype = 0;

	if (len)
		msgtype = ((*(UInteger8 *) (buf + 0)) & 0x0F);
	if (msgtype >= __PP_NR_MESSAGES_TYPES || len < type_length[msgtype])
		return 1; /* too short */
	if (((*(UInteger8 *) (buf + 1)) & 0x0F) != 2)
		return 1; /* wrong ptp version */
	return msg_unpack_header(ppi, buf, len);
}

/*
 * This is the state machine code. i.e. the extension-independent
 * function that runs the machine. Errors are managed and reported
 * here (based on the diag module). The returned value is the time
 * in milliseconds to wait before reentering the state machine.
 * the normal protocol. If an extended protocol is used, the table used
 * is that of the extension, otherwise the one in state-table-default.c
 */

int pp_state_machine(struct pp_instance *ppi, void *buf, int len)
{
	const struct pp_state_table_item *ip;
	struct pp_time *t = &ppi->last_rcv_time;
	int state, err = 0;
	int msgtype;

	if (len > 0) {
		msgtype = ((*(UInteger8 *) (buf + 0)) & 0x0F);
		pp_diag(ppi, frames, 1,
			"RECV %02d bytes at %9d.%09d.%03d (type %x, %s)\n",
			len, (int)t->secs, (int)(t->scaled_nsecs >> 16),
			((int)(t->scaled_nsecs & 0xffff) * 1000) >> 16,
			msgtype, pp_msgtype_name[msgtype]);
	}

	/*
	 * Discard too short packets
	 */
	if (len < PP_HEADER_LENGTH) {
		len = 0;
		buf = NULL;
	}

	/*
	 * Since all ptp frames have the same header, parse it now,
	 * and centralize some error check.
	 * In case of error continue without a frame, so the current
	 * ptp state can update ppi->next_delay and return a proper value
	 */
	err = fsm_unpack_verify_frame(ppi, buf, len);
	if (err) {
		len = 0;
		buf = NULL;
	}
	else {
		/* Use length from the message (to deal with minimal eth
		   frame size) */
		len = ppi->received_ptp_header.messageLength;
	}

	state = ppi->state;

	ip = get_current_state_table_item(ppi);
	if (!ip) {
		pp_printf("fsm: Unknown state for port %s\n", ppi->port_name);
		return 10000; /* No way out. Repeat message every 10s */
	}

	/* found: handle this state */
	ppi->next_state = state;
	ppi->next_delay = 0;
	if (ppi->is_new_state)
		pp_diag_fsm(ppi, ip->name, STATE_ENTER, len);

	/*
	 * Possibly filter out buf and maybe update port state
	 */
	if (buf) {
		err = pp_packet_prefilter(ppi);
		if (err < 0) {
			buf = NULL;
			len = 0;
		}
	}

	if (ppi->state != ppi->next_state)
		return pp_leave_current_state(ppi);

	if (len) {
		if ( ppi->pdstate == PP_PDSTATE_WAIT_MSG ) {
			/* First frame received since instance initialization */
			int tmo=is_ext_hook_available(ppi,get_tmo_lstate_detection) ?
					(*ppi->ext_hooks->get_tmo_lstate_detection)(ppi)
					: 20000; // 20s per default
			pp_timeout_set(ppi,PP_TO_PROT_STATE, tmo);
			pdstate_set_state_pdetection(ppi);
		}
	} else
		ppi->received_ptp_header.messageType = PPM_NO_MESSAGE;

	err = ip->f1(ppi, buf, len);
	if (err)
		pp_printf("fsm for %s: Error %i in %s\n",
			  ppi->port_name, err, ip->name);

	/* done: if new state mark it, and enter it now (0 ms) */
	if (ppi->state != ppi->next_state)
		return pp_leave_current_state(ppi);

	/* Check protocol state */
	if ( ppi->extState==PP_EXSTATE_ACTIVE
	     && (ppi->pdstate==PP_PDSTATE_PDETECTION
		 || ppi->pdstate==PP_PDSTATE_PDETECTED)
	     && pp_timeout(ppi, PP_TO_PROT_STATE) ) {
		pdstate_disable_extension(ppi);
	}

	/* run bmc independent of state, and since not message driven do this
	 * here 9.2.6.8 */
	if ( ppi->bmca_execute) {

		ppi->bmca_execute=0; /* Clear the trigger */
		ppi->next_state = bmc_apply_state_descision(ppi);

		/* done: if new state mark it, and enter it now (0 ms) */
		if (ppi->state != ppi->next_state)
			return pp_leave_current_state(ppi);
	}

	/* Run the extension state machine. The extension can provide its own time-out */
	if ( is_ext_hook_available(ppi,run_ext_state_machine) ) {
		int delay = ppi->ext_hooks->run_ext_state_machine(ppi,buf,len);

		/* if new state mark it, and enter it now (0 ms) */
		if (ppi->state != ppi->next_state)
			return pp_leave_current_state(ppi);

		if (delay < ppi->next_delay)
			ppi->next_delay=delay;
	}

	pp_diag_fsm(ppi, ip->name, STATE_LOOP, 0);

	return ppi->next_delay;
}

/* link state functions to manage the extension (Enable/disable) */
void pdstate_disable_extension(struct pp_instance * ppi)
{
	ppi->pdstate=PP_PDSTATE_FAILURE;
	if ( ppi->extState==PP_EXSTATE_ACTIVE) {
		if ( ppi->ptp_support )
			ppi->extState=ppi->ptp_support ? PP_EXSTATE_PTP : PP_EXSTATE_DISABLE;
		pp_servo_init(ppi); // Reinitialize the servo
		if ( is_ext_hook_available(ppi,extension_state_changed) )
				ppi->ext_hooks->extension_state_changed(ppi);
	}
}

void pdstate_set_state_pdetection(struct pp_instance * ppi)
{
	if (ppi->pdstate != PP_PDSTATE_NONE ) {
		ppi->pdstate=PP_PDSTATE_PDETECTION;
		pp_timeout_reset(ppi,PP_TO_PROT_STATE);
	}
}

void pdstate_set_state_pdetected(struct pp_instance * ppi)
{
	if (ppi->pdstate != PP_PDSTATE_NONE ) {
		ppi->pdstate=PP_PDSTATE_PDETECTED;
		pp_timeout_reset(ppi,PP_TO_PROT_STATE);
	}
}

/* link state functions to manage the extension (Enable/disable) */
void pdstate_enable_extension(struct pp_instance * ppi)
{
	if (ppi->pdstate == PP_PDSTATE_NONE )
		return;

	ppi->pdstate=PP_PDSTATE_PDETECTED;
	pp_timeout_reset(ppi,PP_TO_PROT_STATE);
	if ( ppi->extState!=PP_EXSTATE_ACTIVE ) {
		ppi->extState=PP_EXSTATE_ACTIVE;
		if ( is_ext_hook_available(ppi,extension_state_changed) )
			ppi->ext_hooks->extension_state_changed(ppi);
	}
}
