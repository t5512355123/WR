/*
 * Copyright (C) 2018 CERN (www.cern.ch)
 * Author: Jean-Claude BAU & Maciej Lipinski
 *
 * Released according to the GNU LGPL, version 2.1 or any later version.
 */
#include <stdint.h>
#include <inttypes.h>
#include <ppsi/ppsi.h>
// #include "wrs-constants.h"
#include "../proto-standard/common-fun.h"
#include "wrh-servo_state_name.h"

#if CONFIG_ARCH_IS_WRS
#include <libwr/shmem.h>
#else
/* No shmem */
#define wrs_shm_write(ppi, FLAG) do {} while (0)
#endif

/* Define threshold values for SNMP */
#define SNMP_MAX_OFFSET_PS 500
#define SNMP_MAX_DELTA_RTT_PS 1000

/* Enable tracking by default. Disabling the tracking is used for demos. */
static int wrh_tracking_enabled = 1;

/* prototypes */
static int __wrh_servo_update(struct pp_instance *ppi);
static void  setState(struct pp_instance *ppi, int newState);

/* External data */
extern struct wrs_shm_head *ppsi_head;

void wrh_servo_enable_tracking(int enable)
{
	wrh_tracking_enabled = enable;
}

int wrh_servo_init(struct pp_instance *ppi)
{
	wrh_servo_t *s=WRH_SRV(ppi);
	struct pp_servo *gs=SRV(ppi);
	int ret=0;

	pp_servo_init(ppi); // Initialize the standard servo data

	/* shmem lock */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);

	WRH_SERVO_RESET_DATA(s);

	/* Re-read clock period.
	   FIXME: isn't it fixed ?  */
	s->clock_period_ps = WRH_OPER()->get_clock_period();

	/*
	 * Do not reset cur_setpoint, but trim it to be less than one tick.
	 * The softpll code uses the module anyways, but if we unplug-replug
	 * the fiber it will always increase, so don't scare the user
	 */
	if (s->cur_setpoint_ps > s->clock_period_ps)
		s->cur_setpoint_ps %= s->clock_period_ps;

	pp_diag(ppi, servo, 3, "%s.%d: Adjust_phase: %d\n",__func__,__LINE__,s->cur_setpoint_ps);

	WRH_OPER()->adjust_phase(s->cur_setpoint_ps);

	gs->flags |= PP_SERVO_FLAG_VALID;
	TOPS(ppi)->get(ppi, &gs->update_time);
	s->tracking_enabled = wrh_tracking_enabled;
	setState(ppi,WRH_SYNC_TAI);

	/* shmem unlock */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);
	return ret;
}


void wrh_servo_reset(struct pp_instance *ppi)
{
	if ( ppi->extState==PP_EXSTATE_ACTIVE ) {
		/* shmem lock */
		wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);
		ppi->flags = 0;

		WRH_SERVO_RESET_DATA(WRH_SRV(ppi));

		setState(ppi,WRH_UNINITIALIZED);

		/* shmem unlock */
		wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);
	}
}

/**
 *  SYNC/FOLLOW_UP messages have been received: t1/t2 are available
 */
int wrh_servo_got_sync(struct pp_instance *ppi)
{
	struct pp_servo *gs=SRV(ppi);

	/* shmem lock */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);

	gs->t1=ppi->t1;apply_faulty_stamp(ppi,1);
	gs->t2=ppi->t2;apply_faulty_stamp(ppi,2);

	if ( is_delayMechanismP2P(ppi) && gs->got_sync) {
		gs->got_sync=0;
		__wrh_servo_update(ppi);
	} else {
		gs->got_sync=1;
	}

	/* shmem unlock */
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);

	return 0;
}

/**
 *  DELAY_RESPONSE message has been received: t3/t4 are available
 */

int wrh_servo_got_resp(struct pp_instance *ppi)
{
	struct pp_servo *gs=SRV(ppi);
	int ret;
	static int errcount=0;

	if (!gs->got_sync)
		return 0; /* t1 & t2 not available yet */
	gs->got_sync=0;

	if (is_timestamp_incorrect_thres(ppi,&errcount,0xC /* mask=t3&t4 */))
		return 0;

	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);

	gs->t3 = ppi->t3; apply_faulty_stamp(ppi,3);
	gs->t4 = ppi->t4; apply_faulty_stamp(ppi,4);

	ret=__wrh_servo_update(ppi);
	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);
	return ret;
}

#if CONFIG_HAS_P2P
/**
 *  PDELAY_RESPONSE_FUP message has been received: t3/t4/t5/t6 are available
 */
int wrh_servo_got_presp(struct pp_instance *ppi)
{
	struct pp_servo *gs=SRV(ppi);
	static int errcount=0;

	if (is_timestamp_incorrect_thres(ppi,&errcount,0x3C /* t3,t4,t5,t6 */))
		return 0;

	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_BEGIN);

	gs->t3 = ppi->t3; apply_faulty_stamp(ppi,3);
	gs->t4 = ppi->t4; apply_faulty_stamp(ppi,4);
	gs->t5 = ppi->t5; apply_faulty_stamp(ppi,5);
	gs->t6 = ppi->t6; apply_faulty_stamp(ppi,6);

	gs->got_sync=1;

	wrs_shm_write(ppsi_head, WRS_SHM_WRITE_END);

	return 1;
}
#endif

static void setState(struct pp_instance *ppi, int newState)
{
	struct pp_servo *gs=SRV(ppi);
	const char *state_name = wrh_servo_state_name[newState];
	pp_diag(ppi, servo, 1, "new state %s\n", state_name);
	gs->state=newState;
	gs->servo_state_name = state_name;
}

static int __wrh_servo_update(struct pp_instance *ppi)
{
	struct pp_servo *gs=SRV(ppi);
	wrh_servo_t *s=WRH_SRV(ppi);
	int remaining_offset;
	int32_t  offset_ticks;
	int64_t prev_delayMM_ps = 0;
	int locking_poll_ret;

	struct pp_time offsetMS ;
	int32_t  offset_ps;

	if ( gs->state==WRH_UNINITIALIZED ) {
		pp_error("%s : Servo not initialized !!!!\n",__FUNCTION__);
		return 0;
	}

	prev_delayMM_ps = s->delayMM_ps;

	if ( !pp_servo_calculate_delays(ppi) )
		return 0;

	s->delayMM_ps=pp_time_to_picos(&gs->delayMM);
	s->delayMS_ps=pp_time_to_picos(&gs->delayMS);
	offsetMS=gs->offsetFromMaster;
	s->offsetMS_ps=pp_time_to_picos(&offsetMS);
	s->tracking_enabled = wrh_tracking_enabled;

	// Servo updated
	gs->update_count++;
	TOPS(ppi)->get(ppi, &gs->update_time);

	if (!s->readyForSync )
		return 1; /* We have to wait before to start the synchronization */

	locking_poll_ret = WRH_OPER()->locking_poll(ppi);
	if (locking_poll_ret != WRH_SPLL_LOCKED ){
		pp_error("%s: PLL error detected (Err=%d). Force restart.\n",__func__,locking_poll_ret);
		s->doRestart = TRUE;
		return 0;
	}

	/* After each action on the hardware, we must verify if it is over. */
	if (!WRH_OPER()->adjust_in_progress()) {
		gs->flags &= ~PP_SERVO_FLAG_WAIT_HW;
	} else {
		pp_diag(ppi, servo, 1, "servo:busy\n");
		return 1;
	}

	/* So, we didn't return. Choose the right state */
	if (offsetMS.secs) {/* so bad... */
		setState(ppi,WRH_SYNC_TAI);
		pp_diag(ppi, servo, 2, "offsetMS: %li sec ...\n",
				(long)offsetMS.secs);
	} else {
		pp_time_hardwarize(&offsetMS, s->clock_period_ps,
			      &offset_ticks, &offset_ps);
		pp_diag(ppi, servo, 2, "offsetMS: %li sec %09li ticks (%li ps)\n",
			(long)offsetMS.secs, (long)offset_ticks,
			(long)offset_ps);

		if (offset_ticks) /* not that bad */
			setState(ppi,WRH_SYNC_NSEC);
	/* else, let the states below choose the sequence */
	}

	pp_diag(ppi, servo, 3, "wrh_servo state: %s%s\n",
			gs->servo_state_name,
			gs->flags & PP_SERVO_FLAG_WAIT_HW ? " (wait for hw)" : "");

	switch (gs->state) {
	case WRH_SYNC_TAI:
		WRH_OPER()->adjust_counters(offsetMS.secs, 0);
		gs->flags |= PP_SERVO_FLAG_WAIT_HW;
		/*
		 * If nsec wrong, code above forces SYNC_NSEC,
		 * Else, we must ensure we leave this status towards
		 * fine tuning
		 */
		setState(ppi,WRH_SYNC_PHASE);
		break;

	case WRH_SYNC_NSEC:
		WRH_OPER()->adjust_counters(0, offset_ticks);
		gs->flags |= PP_SERVO_FLAG_WAIT_HW;
		setState(ppi,WRH_SYNC_PHASE);
		break;

	case WRH_SYNC_PHASE:
		pp_diag(ppi, servo, 2, "oldsetp %i, offset %i:%04i\n",
			s->cur_setpoint_ps, offset_ticks,
			offset_ps);
		s->cur_setpoint_ps += (offset_ps / 2);
		pp_diag(ppi, servo, 3, "%s.%d: Adjust_phase: %d\n",__func__,__LINE__,s->cur_setpoint_ps);
		WRH_OPER()->adjust_phase(s->cur_setpoint_ps);

		gs->flags |= PP_SERVO_FLAG_WAIT_HW;
		setState(ppi,WRH_WAIT_OFFSET_STABLE);

		if (CONFIG_ARCH_IS_WRS) {
			/*
			 * Now, let's fix …91500 tokens truncated…orr_t_static_done);
  si_corr_probe2(31 downto 0) <= std_logic_vector(si_corr_t_state_leave);
  si_corr_probe2(63 downto 32) <= std_logic_vector(si_corr_t_ready_drop);
  si_corr_probe3(31 downto 0) <= std_logic_vector(si_corr_t_config_drop);
  si_corr_probe3(63 downto 32) <= std_logic_vector(si_corr_t_wr_reset);
  si_corr_probe4(31 downto 0) <= std_logic_vector(si_corr_t_cpu_reset);
  si_corr_probe4(63 downto 32) <= std_logic_vector(si_corr_t_system_start);
  si_corr_probe5(7 downto 0) <= si_corr_static_before;
  si_corr_probe5(15 downto 8) <= si_corr_static_after;
  si_corr_probe5(23 downto 16) <= dco_static_state;
  si_corr_probe5(24) <= si_corr_post_armed;
  si_corr_probe5(25) <= si_config_done;
  si_corr_probe5(26) <= wr_core_reset_n;
  si_corr_probe5(27) <= cpu_reset;
  si_corr_probe5(28) <= dco_runtime_start;
  si_corr_probe5(29) <= dco_bus_done;
  si_corr_probe5(30) <= dco_static_done_pulse;
  si_corr_probe5(31) <= dco_static_access_start;
  si_corr_probe5(34 downto 32) <= dco_runtime_state;
  si_corr_probe5(35) <= dco_bus_state;
  si_corr_probe5(36) <= dco_runtime_bus_enable;
  si_corr_probe5(37) <= dco_system_start;
  si_corr_probe5(63 downto 38) <= (others => '0');
  si_corr_probe6(31 downto 0) <= std_logic_vector(si_corr_post_arm_timestamp);
  si_corr_probe6(63 downto 32) <= std_logic_vector(si_corr_startup_system_start);
  si_corr_probe7(31 downto 0) <= std_logic_vector(si_corr_startup_static_complete);
  si_corr_probe7(32) <= si_corr_startup_ready_final;
  si_corr_probe7(33) <= si_corr_post_armed;
  si_corr_probe7(63 downto 34) <= (others => '0');

  u_si_corr_probe0 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_0_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 28,
                 source_width => 1)
    port map (probe => si_corr_probe0, source => si_corr_source0,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe1 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_1_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 29,
                 source_width => 1)
    port map (probe => si_corr_probe1, source => si_corr_source1,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe2 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_2_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 30,
                 source_width => 1)
    port map (probe => si_corr_probe2, source => si_corr_source2,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe3 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_3_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 31,
                 source_width => 1)
    port map (probe => si_corr_probe3, source => si_corr_source3,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe4 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_4_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 32,
                 source_width => 1)
    port map (probe => si_corr_probe4, source => si_corr_source4,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe5 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_5_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 33,
                 source_width => 1)
    port map (probe => si_corr_probe5, source => si_corr_source5,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe6 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_6_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 34,
                 source_width => 1)
    port map (probe => si_corr_probe6, source => si_corr_source6,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_si_corr_probe7 : altsource_probe
    generic map (instance_id => "WR_SI_CORRELATION_7_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 35,
                 source_width => 1)
    port map (probe => si_corr_probe7, source => si_corr_source7,
              source_clk => CLK_50_B2J, source_ena => '1');

  -- JTAG-readable status: bit 0 is the least-significant status bit.
  sync_probe(15 downto 0) <= CPU_RESET_n & wr_tx_enc_err & wr_rx_enc_err & si_id_error &
                             core_phy_rst & core_phy_tx_disable & QSFPA_INTERRUPT_n &
                             QSFPA_MOD_PRS_n & wr_tx_ready & wr_rx_ready &
                             core_pps_valid & core_tm_time_valid & core_link_ok &
                             core_tm_link_up & wr_ready & si_config_done;
  sync_probe(23 downto 16) <= wr_rx_data;
  sync_probe(27 downto 24) <= wr_rx_bitslide;
  sync_probe(28) <= wr_rx_data_k;
  sync_probe(29) <= wr_debug;
  sync_probe(30) <= core_phy_loopen;
  sync_probe(31) <= '0';
  sync_probe(39 downto 32) <= wr_rx_runningdisp & wr_rx_pattern_ready &
                              wr_rx_patterndetect & wr_rx_syncstatus &
                              wr_rx_errdetect & wr_rx_disperr &
                              wr_rx_locked_to_ref & wr_rx_locked_to_data;
  -- The load counters below observe raw WR SoftPLL DAC requests.  They are
  -- intentionally separate from the SI5340 transaction step counter.
  sync_probe(47 downto 40) <= std_logic_vector(uart_toggle_count);
  sync_probe(55 downto 48) <= std_logic_vector(sfp_scl_toggle_count);
  sync_probe(59 downto 56) <= std_logic_vector(dac_dpll_count(3 downto 0));
  sync_probe(63 downto 60) <= std_logic_vector(dac_hpll_count(3 downto 0));

  u_wr_sync_probe : altsource_probe
    generic map (
      instance_id             => "WR_SYNC_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 0,
      source_width            => 1
    )
    port map (
      probe      => sync_probe,
      source     => sync_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_clock_activity_probe : altsource_probe
    generic map (
      instance_id             => "WR_CLOCK_ACTIVITY_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 7,
      source_width            => 1
    )
    port map (
      probe      => clock_activity_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_global_time_snapshot_probe0 : altsource_probe
    generic map (
      instance_id             => "WR_GLOBAL_TIME_SNAPSHOT_0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 62,
      source_width            => 1
    )
    port map (
      probe      => global_time_snapshot_probe0,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_global_time_snapshot_probe1 : altsource_probe
    generic map (
      instance_id             => "WR_GLOBAL_TIME_SNAPSHOT_1_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 63,
      source_width            => 1
    )
    port map (
      probe      => global_time_snapshot_probe1,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_global_time_live_probe : altsource_probe
    generic map (
      instance_id             => "WR_GLOBAL_TIME_LIVE_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 64,
      source_width            => 1
    )
    port map (
      probe      => global_time_live_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step6b_target_tai_probe : altsource_probe
    generic map (instance_id => "WR_STEP6B_TARGET_TAI_SLAVE",
                 probe_width => 64, sld_auto_instance_index => "NO",
                 sld_instance_index => 67, source_initial_value => "0",
                 source_width => 40)
    port map (probe => step6b_target_tai_probe,
              source => step6b_target_tai_source,
              source_clk => CLK_50_B2J, source_ena => '1');

  u_step6b_arm_status_probe : altsource_probe
    generic map (instance_id => "WR_STEP6B_ARM_STATUS_SLAVE",
                 probe_width => 64, sld_auto_instance_index => "NO",
                 sld_instance_index => 68, source_initial_value => "0",
                 source_width => 1)
    port map (probe => step6b_arm_status_probe,
              source => step6b_arm_source,
              source_clk => CLK_50_B2J, source_ena => '1');

  u_step6b_latched_tai_probe : altsource_probe
    generic map (instance_id => "WR_STEP6B_LATCHED_TAI_SLAVE",
                 probe_width => 64, sld_auto_instance_index => "NO",
                 sld_instance_index => 69, source_width => 1)
    port map (probe => step6b_latched_tai_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');

  u_step6b_actual_tai_probe : altsource_probe
    generic map (instance_id => "WR_STEP6B_ACTUAL_TAI_SLAVE",
                 probe_width => 64, sld_auto_instance_index => "NO",
                 sld_instance_index => 70, source_width => 1)
    port map (probe => step6b_actual_tai_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');

  u_step6b_actual_cycles_probe : altsource_probe
    generic map (instance_id => "WR_STEP6B_ACTUAL_CYCLES_SLAVE",
                 probe_width => 64, sld_auto_instance_index => "NO",
                 sld_instance_index => 71, source_width => 1)
    port map (probe => step6b_actual_cycles_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');

  -- 唯讀 DCO probe。只觀察 clean-9f controller 的 request、I2C state、
  -- step count 與輸入資料，不參與 WR、SoftPLL 或 SI5340 控制。
  dco_probe <= dco_debug;

  u_dco_probe : altsource_probe
    generic map (
      instance_id             => "WR_DCO_ACTIVITY_CLEAN9F_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 8,
      source_width            => 1
    )
    port map (
      probe      => dco_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- JTAG-controlled Step5 experiment probe.  The probe is read-only on the
  -- 64-bit status path and exposes one dedicated source bit to the DCO.
  u_step5_trigger_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_TRIGGER_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 36,
      source_initial_value    => "0",
      source_width            => 1
    )
    port map (
      probe      => dco_step5_debug_probe,
      source     => force_hpll_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_burst_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_BURST_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 37,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_burst_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  step5_polarity_probe(0) <= step5_polarity_source(0);
  step5_polarity_probe(1) <= step5_polarity_active;
  step5_polarity_probe(63 downto 2) <= (others => '0');

  u_step5_polarity_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_POLARITY_SELECT_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 38,
      source_initial_value    => "0",
      source_width            => 1
    )
    port map (
      probe      => step5_polarity_probe,
      source     => step5_polarity_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_tracker_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_TRACKER_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 39,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_tracker_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Calibration-only source: select a bounded forced physical-step count
  -- without changing the fixed Step5 probe indices above.
  u_step5_burst_size_source : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_BURST_SIZE_SOURCE_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 40,
      source_initial_value    => "0000000000000000",
      source_width            => 16
    )
    port map (
      probe      => (others => '0'),
      source     => step5_burst_size_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_burst_wide_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_BURST_WIDE_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 41,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_burst_wide_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_bootstrap_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_BOOTSTRAP_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 42,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_bootstrap_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_position_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_POSITION_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 43,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_position_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_step5_position_accounting_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_POSITION_ACCOUNTING_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 44,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_position_accounting_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Explicit FINC/FDEC completion accounting for the plant-identification
  -- image. This new probe leaves all legacy Step5 probe layouts unchanged.
  u_step5_actuator_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_ACTUATOR_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 49,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_actuator_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Independent runtime transaction provenance. Probe 50 leaves the legacy
  -- actuator-debug layout at probe 49 unchanged.
  u_step5_i2c_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_I2C_PROVENANCE_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 50,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_i2c_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Per-phase payload capture. Probe 51 records all four address/data pairs;
  -- probe 50 retains the compact last-command and ACK status word.
  u_step5_i2c_sequence_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_STEP5_I2C_SEQUENCE_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 51,
      source_width            => 1
    )
    port map (
      probe      => dco_step5_i2c_sequence_debug_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- L2 low-perturbation first-loss probes. These are read-only and use free
  -- source-probe indices after the existing Step5 layout.
  u_step5_liveness_status_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_STATUS_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 52,
                 source_width => 1)
    port map (probe => dco_step5_liveness_status_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_pending_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_PENDING_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 53,
                 source_width => 1)
    port map (probe => dco_step5_liveness_pending_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_start_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_START_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 54,
                 source_width => 1)
    port map (probe => dco_step5_liveness_start_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_completed_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_COMPLETED_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 55,
                 source_width => 1)
    port map (probe => dco_step5_liveness_completed_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_failed_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_FAILED_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 56,
                 source_width => 1)
    port map (probe => dco_step5_liveness_failed_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_wait_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_WAIT_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 57,
                 source_width => 1)
    port map (probe => dco_step5_liveness_wait_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_current_wait_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_CURRENT_WAIT_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 58,
                 source_width => 1)
    port map (probe => dco_step5_liveness_current_wait_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_latency_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_LATENCY_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 59,
                 source_width => 1)
    port map (probe => dco_step5_liveness_latency_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_failure_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_FAILURE_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 60,
                 source_width => 1)
    port map (probe => dco_step5_liveness_failure_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');
  u_step5_liveness_first_loss_probe : altsource_probe
    generic map (instance_id => "WR_STEP5_LIVENESS_FIRST_LOSS_SLAVE", probe_width => 64,
                 sld_auto_instance_index => "NO", sld_instance_index => 61,
                 source_width => 1)
    port map (probe => dco_step5_liveness_first_loss_probe, source => open,
              source_clk => CLK_50_B2J, source_ena => '1');

  -- CPU 執行觀測：[31:0] PC、bit 32 reset、bit 33 fault、bit 34
  -- instruction-valid。此 probe 只讀取，不參與 WR 時序。
  cpu_debug_probe(31 downto 0) <= cpu_pc;
  cpu_debug_probe(32) <= cpu_reset;
  cpu_debug_probe(33) <= cpu_fault;
  cpu_debug_probe(34) <= cpu_im_valid;
  cpu_debug_probe(35) <= CPU_RESET_n;
  cpu_debug_probe(36) <= wr_core_reset_n;
  cpu_debug_probe(37) <= si_config_done;
  cpu_debug_probe(38) <= clk_sys_625_locked;
  cpu_debug_probe(63 downto 39) <= (others => '0');

  u_cpu_debug_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_DEBUG_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 2,
      source_width            => 1
    )
    port map (
      probe      => cpu_debug_probe,
      source     => cpu_debug_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  cpu_marker_probe(31 downto 0) <= cpu_boot_stage_value;
  cpu_marker_probe(32) <= cpu_boot_stage_seen;
  cpu_marker_probe(63 downto 33) <= (others => '0');

  u_cpu_marker_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_MARKER_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 3,
      source_width            => 1
    )
    port map (
      probe      => cpu_marker_probe,
      source     => cpu_marker_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Passive pre-CRT entry snapshot: [31:0] p at entry and [63:32]
  -- boot-generation.  This direct probe never controls or accesses the CPU.
  cpu_entry_probe(31 downto 0) <= cpu_entry_p;
  cpu_entry_probe(63 downto 32) <= cpu_entry_generation;

  u_cpu_entry_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_ENTRY_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 26,
      source_width            => 1
    )
    port map (
      probe      => cpu_entry_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  cpu_store_probe(31 downto 0) <= cpu_last_store_addr;
  cpu_store_probe(63 downto 32) <= cpu_last_store_data;

  u_cpu_store_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_STORE_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 4,
      source_width            => 1
    )
    port map (
      probe      => cpu_store_probe,
      source     => cpu_store_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  cpu_store_count_probe(31 downto 0) <= cpu_internal_store_count;
  cpu_store_count_probe(63 downto 32) <= (others => '0');

  u_cpu_store_count_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_STORE_COUNT_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 5,
      source_width            => 1
    )
    port map (
      probe      => cpu_store_count_probe,
      source     => cpu_store_count_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  cpu_exception_probe(31 downto 0) <= cpu_mepc;
  cpu_exception_probe(63 downto 32) <= cpu_mcause;

  u_cpu_exception_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_EXCEPTION_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 6,
      source_width            => 1
    )
    port map (
      probe      => cpu_exception_probe,
      source     => cpu_exception_source,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- CPU data-port identity diagnostic.  The address probe carries the
  -- captured request address in [31:0] and the next-cycle RAM return word in
  -- [63:32].  The metadata probe carries byte enable [3:0], request-seen bit
  -- 4, return-seen bit 5, and expected-address match bit 6.
  cpu_data_diag_addr_probe <= cpu_data_diag_addr_payload;
  cpu_data_diag_meta_probe <= cpu_data_diag_meta_payload;

  u_cpu_data_diag_addr_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_DATA_DIAG_ADDR_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 9,
      source_width            => 1
    )
    port map (
      probe      => cpu_data_diag_addr_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_data_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_DATA_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 10,
      source_width            => 1
    )
    port map (
      probe      => cpu_data_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- RAM port-B request/return pipeline diagnostic.  Probe 11 carries the
  -- request address in [31:0] and the next-cycle registered-address mirror in
  -- [63:32].  Probe 12 carries q cycle 1 in [31:0] and q cycle 2 in [63:32].
  -- Probe 13 carries byte enable [3:0], request/q1/q2 seen bits [4:6], and
  -- expected-address match bit 7.
  cpu_ram_diag_addr_probe <= cpu_ram_diag_addr_payload;
  cpu_ram_diag_q_probe <= cpu_ram_diag_q_payload;
  cpu_ram_diag_meta_probe <= cpu_ram_diag_meta_payload;

  u_cpu_ram_diag_addr_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_DIAG_ADDR_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 11,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_diag_addr_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_diag_q_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_DIAG_Q_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 12,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_diag_q_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 13,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Probe 14 carries the previous port-B address-register input in [63:32]
  -- and the q value visible before the update at the request edge (q cycle 0)
  -- in [31:0].
  cpu_ram_diag_q0_probe <= cpu_ram_diag_q0_payload;

  u_cpu_ram_diag_q0_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_DIAG_Q0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 14,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_diag_q0_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- RAM port-B reset/release initial-q diagnostic.  Probes 15..18 carry
  -- q while reset, four post-release samples, and q immediately
  -- before/at the first internal load.  Probe 19 carries capture flags.
  cpu_ram_init_diag_probe0 <= cpu_ram_init_diag_payload0;
  cpu_ram_init_diag_probe1 <= cpu_ram_init_diag_payload1;
  cpu_ram_init_diag_probe2 <= cpu_ram_init_diag_payload2;
  cpu_ram_init_diag_probe3 <= cpu_ram_init_diag_payload3;
  cpu_ram_init_diag_meta_probe <= cpu_ram_init_diag_meta_payload;

  u_cpu_ram_init_diag_probe0 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 15,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_probe0,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_init_diag_probe1 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_1_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 16,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_probe1,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_init_diag_probe2 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_2_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 17,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_probe2,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_init_diag_probe3 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_3_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 18,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_probe3,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_init_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_INIT_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 19,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_init_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- Direct raw q_b versus wrapper dm_mem_rdata diagnostic.  Probe 20 carries
  -- primitive q before/at the first internal load, probe 21 carries
  -- primitive q after the load and dm_mem_rdata at the load, and probe 22
  -- carries capture flags.
  cpu_ram_primitive_diag_probe0 <= cpu_ram_primitive_diag_payload0;
  cpu_ram_primitive_diag_probe1 <= cpu_ram_primitive_diag_payload1;
  cpu_ram_primitive_diag_meta_probe <= cpu_ram_primitive_diag_meta_payload;

  u_cpu_ram_primitive_diag_probe0 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PRIMITIVE_DIAG_0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 20,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_primitive_diag_probe0,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_primitive_diag_probe1 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PRIMITIVE_DIAG_1_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 21,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_primitive_diag_probe1,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_primitive_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PRIMITIVE_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 22,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_primitive_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- First port-B load same-edge port-A activity diagnostic.  Probe 23 carries
  -- port-A byte address and write data, probe 24 carries port-B byte address
  -- and primitive q_b, and probe 25 carries port-A write/byte-enable flags.
  cpu_ram_port_a_diag_probe0 <= cpu_ram_port_a_diag_payload0;
  cpu_ram_port_a_diag_probe1 <= cpu_ram_port_a_diag_payload1;
  cpu_ram_port_a_diag_meta_probe <= cpu_ram_port_a_diag_meta_payload;

  u_cpu_ram_port_a_diag_probe0 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PORT_A_DIAG_0_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 23,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_port_a_diag_probe0,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_port_a_diag_probe1 : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PORT_A_DIAG_1_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 24,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_port_a_diag_probe1,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  u_cpu_ram_port_a_diag_meta_probe : altsource_probe
    generic map (
      instance_id             => "WR_CPU_RAM_PORT_A_DIAG_META_SLAVE",
      probe_width             => 64,
      sld_auto_instance_index => "NO",
      sld_instance_index      => 25,
      source_width            => 1
    )
    port map (
      probe      => cpu_ram_port_a_diag_meta_probe,
      source     => open,
      source_clk => CLK_50_B2J,
      source_ena => '1'
    );

  -- The board's SFP I2C pins are open-drain.  WRPC drives only the output
  -- low and releases the line for a logic high.
  QSFPA_SDA <= '0' when sfp_sda_o = '0' else 'Z';
  sfp_sda_i <= QSFPA_SDA;
  QSFPA_SCL <= '0' when sfp_scl_o = '0' else 'Z';
  sfp_scl_i <= QSFPA_SCL;

  QSFPA_MOD_SEL_n <= '0';
  QSFPA_RST_n     <= CPU_RESET_n;
  -- Keep all non-active QSFP-A lanes electrically inactive.
  QSFPA_TX_p(3 downto 1) <= (others => '0');
  SI5340A_OE_n    <= '0';
  SI5340A_RST_n   <= CPU_RESET_n;

  u_si5340a_controller : si5340a_controller_dco
    generic map (
      ENABLE_SAME_CODE_TEST => 0,
      ENABLE_JTAG_HPLL_BURST => 1,
      -- Step5 closed-loop validation: use the measured plant direction and
      -- let the normal HPLL tracker close the residual after bootstrap.
      ENABLE_STEP5_ACTUATOR_IDENTIFICATION => 1,
      ENABLE_STEP5_HPLL_PLANT_TEST => 0,
      ENABLE_NORMAL_HPLL_TRACKER => 1,
      ENABLE_STEP5_BOOTSTRAP => 1,
      -- Restore the last known-good operating point after the 3216 and 3860
      -- bracket candidates both hit an actuator rail.  The 3388 run produced
      -- Helper lock and Main frequency progress; F3a changes only the
      -- firmware phase-guard duration.
      STEP5_BOOTSTRAP_STEPS => 3388,
      STEP5_BOOTSTRAP_REVERSE => 1,
      -- Keep the virtual position account aligned with the measured physical
      -- SI5340 FINC/FDEC step; the 32-code experiment was not physically
      -- realizable and produced an accounting/runaway failure.
      HPLL_TRACKER_CODE_PER_PHYSICAL_STEP => 64,
      -- True baseline revalidation: do not insert an additional accepted-tag
      -- cooldown between normal HPLL transactions. Keep the 64-code physical
      -- step account and all PI gains unchanged.
      STEP5_NORMAL_HPLL_COOLDOWN_LOADS => 0,
      DPLL_TRACKER_CODE_PER_PHYSICAL_STEP => 16,
      JTAG_HPLL_BURST_SIZE => 32
    )
    port map (
      iCLK                   => CLK_50_B2J,
      iRST_n                 => CPU_RESET_n,
      iStart                 => not BUTTON(0),
      iPLL_OUT0_FREQ_SEL     => SI5340_125M,
      iPLL_OUT1_FREQ_SEL     => SI5340_124M992,
      iPLL_OUT2_FREQ_SEL     => SI5340_POWER_DOWN,
      iPLL_OUT3_FREQ_SEL     => SI5340_POWER_DOWN,
      iDPLL_LOAD             => dac_dpll_load,
      iDPLL_DATA             => dac_dpll_data,
      iHPLL_LOAD             => dac_hpll_load,
      iHPLL_DATA             => dac_hpll_data,
      iFORCE_HPLL_ONE_STEP   => force_hpll_source(0),
      iFORCE_HPLL_REVERSE    => step5_polarity_source(0),
      iFORCE_HPLL_BURST_SIZE => step5_burst_size_source,
      I2C_CLK                => SI5340A_I2C_SCL,
      I2C_DATA               => SI5340A_I2C_SDA,
      oPLL_I2C_ID_READ_ERROR => si_id_error,
      oPLL_REG_CONFIG_DONE   => si_config_done,
      oDCO_BUSY              => dco_busy,
      oDCO_ERROR             => dco_error,
      oDCO_STEP_COUNT        => dco_step_count,
      oDCO_DEBUG             => dco_debug,
      oDCO_STEP5_DEBUG       => dco_step5_debug_probe,
      oDCO_STEP5_BURST_DEBUG => dco_step5_burst_debug_probe,
      oDCO_STEP5_BURST_WIDE_DEBUG => dco_step5_burst_wide_debug_probe,
      oDCO_STEP5_TRACKER_DEBUG => dco_step5_tracker_debug_probe,
      oDCO_STEP5_BOOTSTRAP_DEBUG => dco_step5_bootstrap_debug_probe,
      oDCO_STEP5_POSITION_DEBUG => dco_step5_position_debug_probe,
      oDCO_STEP5_POSITION_ACCOUNTING_DEBUG => dco_step5_position_accounting_debug_probe,
      oDCO_STEP5_ACTUATOR_DEBUG => dco_step5_actuator_debug_probe,
      oDCO_STEP5_I2C_DEBUG => dco_step5_i2c_debug_probe,
      oDCO_STEP5_I2C_SEQUENCE_DEBUG => dco_step5_i2c_sequence_debug_probe,
      oDCO_STEP5_POLARITY_ACTIVE => step5_polarity_active,
      oDCO_STEP5_LIVENESS_STATUS => dco_step5_liveness_status_probe,
      oDCO_STEP5_LIVENESS_PENDING => dco_step5_liveness_pending_probe,
      oDCO_STEP5_LIVENESS_START => dco_step5_liveness_start_probe,
      oDCO_STEP5_LIVENESS_COMPLETED => dco_step5_liveness_completed_probe,
      oDCO_STEP5_LIVENESS_FAILED => dco_step5_liveness_failed_probe,
      oDCO_STEP5_LIVENESS_WAIT => dco_step5_liveness_wait_probe,
      oDCO_STEP5_LIVENESS_CURRENT_WAIT => dco_step5_liveness_current_wait_probe,
      oDCO_STEP5_LIVENESS_LATENCY => dco_step5_liveness_latency_probe,
      oDCO_STEP5_LIVENESS_FAILURE => dco_step5_liveness_failure_probe,
      oDCO_STEP5_LIVENESS_FIRST_LOSS => dco_step5_liveness_first_loss_probe,
      oDEBUG_STATIC_STATE    => dco_static_state,
      oDEBUG_STATIC_CONFIG_DONE_PULSE => dco_static_done_pulse,
      oDEBUG_STATIC_ACCESS_START => dco_static_access_start,
      oDEBUG_RUNTIME_STATE   => dco_runtime_state,
      oDEBUG_BUS_STATE       => dco_bus_state,
      oDEBUG_BUS_DONE        => dco_bus_done,
      oDEBUG_RUNTIME_START   => dco_runtime_start,
      oDEBUG_RUNTIME_BUS_ENABLE => dco_runtime_bus_enable,
      oDEBUG_SYSTEM_START    => dco_system_start
    );

  u_wr_arria10_transceiver : wr_arria10_transceiver
    generic map (
      g_family        => "Arria 10 GX E3P1",
      g_use_simple_wa => true
    )
    port map (
      clk_ref_i              => QSFPA_REFCLK_p,
      clk_phy_i              => QSFPA_REFCLK_p,
      reconfig_write_i       => reconfig_write,
      reconfig_read_i        => reconfig_read,
      reconfig_address_i     => reconfig_address,
      reconfig_writedata_i   => reconfig_writedata,
      reconfig_readdata_o    => reconfig_readdata,
      reconfig_waitrequest_o => reconfig_waitrequest,
      reconfig_clk_i         => reconfig_clk,
      reconfig_reset_i       => reconfig_reset,
      ready_o                => wr_ready,
      drop_link_i            => (not wr_core_reset_n) or core_phy_rst,
      loopen_i               => core_phy_loopen,
      sfp_los_i              => '0',
      tx_clk_o               => wr_tx_clk,
      tx_data_i              => core_tx_data,
      tx_ready_o             => wr_tx_ready,
      tx_disparity_o         => wr_tx_disparity,
      tx_enc_err_o           => wr_tx_enc_err,
      tx_data_k_i            => core_tx_k(0),
      rx_clk_o               => wr_rx_clk,
      rx_data_o              => wr_rx_data,
      rx_ready_o             => wr_rx_ready,
      rx_data_k_o            => wr_rx_data_k,
      rx_enc_err_o           => wr_rx_enc_err,
      rx_bitslide_o          => wr_rx_bitslide,
      rx_lockedtodata_o      => wr_rx_locked_to_data,
      rx_lockedtoref_o       => wr_rx_locked_to_ref,
      rx_disperr_o           => wr_rx_disperr,
      rx_errdetect_o         => wr_rx_errdetect,
      rx_syncstatus_o        => wr_rx_syncstatus,
      rx_patterndetect_o     => wr_rx_patterndetect,
      rx_patterndetect_ready_o => wr_rx_pattern_ready,
      rx_runningdisp_o       => wr_rx_runningdisp,
      debug_o                => wr_debug,
      debug_i                => (others => '0'),
      -- Restore the known-good Step1 route: QSFP-A lane 0 carries WR data.
      pad_txp_o              => QSFPA_TX_p(0),
      pad_rxp_i              => QSFPA_RX_p(0)
    );

  -- QSFP-A provides the 125 MHz PHY/reference clock. WR data uses QSFP-A
  -- lane 0 for the Step5 upstream isolation experiment. QSFP-B is unused as
  -- a data lane, but its on-board reference input carries the 124.992 MHz
  -- offset clock required by the DDMTD phase detector.
  -- JTAG-only runtime observation path. It does not participate in WR timing.
  u_jtag_wb_mailbox : entity work.wr_jtag_wb_mailbox
    generic map (
      g_instance_id => "WR_WB_SLAVE"
    )
    port map (
      i_clk        => clk_sys_625,
      i_reset_n    => wr_core_reset_n,
      i_wb_slave_o => core_wb_o,
      o_wb_slave_i => core_wb_i
    );

  u_xwr_core : entity work.xwr_core
    generic map (
      g_with_external_clock_input => false,
      g_board_name                => "DE5A",
      g_phys_uart                 => true,
      g_virtual_uart              => true,
      g_aux_clks                  => 0,
      g_dpram_initf               => "../build/firmware/slave/wrc.mif",
      g_dpram_size                => 49152,
      g_use_platform_specific_dpram => false,
      g_ep_rxbuf_size             => 1024,
      g_pcs_16bit                 => false,
      g_diag_rw_size              => 1,
      g_with_clock_freq_monitor   => true
    )
    port map (
      clk_sys_i                  => clk_sys_625,
      clk_dmtd_i                 => clk_dmtd_62m496,
      clk_ref_i                  => QSFPA_REFCLK_p,
      clk_ext_rst_o              => open,
      rst_n_i                    => wr_core_reset_n,

      dac_hpll_load_p1_o         => dac_hpll_load,
      dac_hpll_data_o            => dac_hpll_data,
      dac_dpll_load_p1_o         => dac_dpll_load,
      dac_dpll_data_o            => dac_dpll_data,

      phy_ref_clk_i              => QSFPA_REFCLK_p,
      phy_tx_data_o              => core_tx_data,
      phy_tx_k_o                 => core_tx_k,
      phy_tx_disparity_i         => wr_tx_disparity,
      phy_tx_enc_err_i           => wr_tx_enc_err,
      phy_rx_data_i              => wr_rx_data,
      phy_rx_rbclk_i             => wr_rx_clk,
      phy_rx_rbclk_sampled_i     => wr_rx_clk,
      phy_rx_k_i(0)              => wr_rx_data_k,
      phy_rx_enc_err_i           => wr_rx_enc_err,
      phy_rx_bitslide_i          => wr_rx_bitslide,
      phy_mdio_master_o          => open,
      phy_rst_o                  => core_phy_rst,
      phy_rdy_i                  => wr_ready,
      phy_loopen_o               => core_phy_loopen,
      phy_loopen_vec_o           => open,
      phy_tx_prbs_sel_o          => open,
      phy_sfp_tx_disable_o       => core_phy_tx_disable,
      phy8_o                     => open,
      phy16_o                    => open,

      led_act_o                  => open,
      led_link_o                 => open,
      scl_o                      => open,
      sda_o                      => open,
      sfp_scl_o                  => sfp_scl_o,
      sfp_scl_i                  => sfp_scl_i,
      sfp_sda_o                  => sfp_sda_o,
      sfp_sda_i                  => sfp_sda_i,
      sfp_det_i                  => QSFPA_MOD_PRS_n,
      btn1_i                     => BUTTON(1),
      btn2_i                     => BUTTON(2),
      spi_sclk_o                 => open,
      spi_ncs_o                  => open,
      spi_mosi_o                 => open,
      uart_rxd_i                 => RS422_DIN,
      uart_txd_o                 => uart_txd,
      owr_pwren_o                => open,
      owr_en_o                   => open,

      slave_i                    => core_wb_i,
      slave_o                    => core_wb_o,
      aux_master_o               => open,
      wrf_src_o                  => open,
      wrf_snk_o                  => open,
      timestamps_o               => open,
      abscal_txts_o              => open,
      abscal_rxts_o              => open,
      fc_tx_pause_ready_o        => open,
      tm_link_up_o               => core_tm_link_up,
      tm_dac_value_o             => open,
      tm_time_valid_o            => core_tm_time_valid,
      tm_tai_o                   => core_tm_tai,
      tm_cycles_o                => core_tm_cycles,
      pps_csync_o                => core_pps_csync,
      pps_valid_o                => core_pps_valid,
      pps_p_o                    => SMA_CLKOUT,
      pps_led_o                  => open,
      rst_aux_n_o                => open,
      aux_diag_o                 => open,
      link_ok_o                  => core_link_ok,
      cpu_pc_o                  => cpu_pc,
      cpu_reset_o               => cpu_reset,
      cpu_fault_o               => cpu_fault,
      cpu_im_valid_o            => cpu_im_valid,
      cpu_boot_stage_value_o    => cpu_boot_stage_value,
      cpu_boot_stage_seen_o     => cpu_boot_stage_seen,
      cpu_entry_p_o             => cpu_entry_p,
      cpu_entry_generation_o    => cpu_entry_generation,
      cpu_last_store_addr_o     => cpu_last_store_addr,
      cpu_last_store_data_o     => cpu_last_store_data,
      cpu_last_store_seen_o     => cpu_last_store_seen,
      cpu_internal_store_count_o => cpu_internal_store_count,
      cpu_mepc_o               => cpu_mepc,
      cpu_mcause_o             => cpu_mcause,
      cpu_data_diag_addr_payload_o => cpu_data_diag_addr_payload,
      cpu_data_diag_meta_payload_o => cpu_data_diag_meta_payload,
      cpu_ram_diag_addr_payload_o => cpu_ram_diag_addr_payload,
      cpu_ram_diag_q_payload_o => cpu_ram_diag_q_payload,
      cpu_ram_diag_meta_payload_o => cpu_ram_diag_meta_payload,
      cpu_ram_diag_q0_payload_o => cpu_ram_diag_q0_payload,
      cpu_ram_init_diag_payload0_o => cpu_ram_init_diag_payload0,
      cpu_ram_init_diag_payload1_o => cpu_ram_init_diag_payload1,
      cpu_ram_init_diag_payload2_o => cpu_ram_init_diag_payload2,
      cpu_ram_init_diag_payload3_o => cpu_ram_init_diag_payload3,
      cpu_ram_init_diag_meta_payload_o => cpu_ram_init_diag_meta_payload,
      cpu_ram_primitive_diag_payload0_o => cpu_ram_primitive_diag_payload0,
      cpu_ram_primitive_diag_payload1_o => cpu_ram_primitive_diag_payload1,
      cpu_ram_primitive_diag_meta_payload_o => cpu_ram_primitive_diag_meta_payload,
      cpu_ram_port_a_diag_payload0_o => cpu_ram_port_a_diag_payload0,
      cpu_ram_port_a_diag_payload1_o => cpu_ram_port_a_diag_payload1,
      cpu_ram_port_a_diag_meta_payload_o => cpu_ram_port_a_diag_meta_payload
    );

  QSFPA_LP_MODE <= core_phy_tx_disable;

  -- Enable both directions of the on-board full-duplex RS422 transceiver.
  RS422_DE   <= '1';
  RS422_RE_n <= '0';
  RS422_DOUT <= uart_txd;

  LED(0)         <= si_config_done;
  LED(1)         <= wr_ready;
  LED(2)         <= core_tm_link_up;
  LED(3)         <= core_link_ok;
  LED_BRACKET(0) <= core_tm_time_valid;
  LED_BRACKET(1) <= core_pps_valid;
  LED_BRACKET(2) <= wr_rx_ready;
  LED_BRACKET(3) <= wr_tx_ready and not si_id_error;
end rtl;
