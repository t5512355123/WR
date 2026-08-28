#ifndef __CHEBY__WRC_DIAGS__H__
#define __CHEBY__WRC_DIAGS__H__
#define WRC_DIAGS_SIZE 140 /* 0x8c */

/* Version register */
#define WRC_DIAGS_VER 0x0UL
#define WRC_DIAGS_VER_ID_MASK 0xffffffffUL
#define WRC_DIAGS_VER_ID_SHIFT 0

/* Ctrl */
#define WRC_DIAGS_CTRL 0x4UL
#define WRC_DIAGS_CTRL_DATA_VALID 0x1UL
#define WRC_DIAGS_CTRL_DATA_SNAPSHOT 0x100UL

/* WRPC Diag: servo status */
#define WRC_DIAGS_WDIAG_SSTAT 0x8UL
#define WRC_DIAGS_WDIAG_SSTAT_WR_MODE 0x1UL
#define WRC_DIAGS_WDIAG_SSTAT_SERVOSTATE_MASK 0xf00UL
#define WRC_DIAGS_WDIAG_SSTAT_SERVOSTATE_SHIFT 8

/* WRPC Diag: Port status */
#define WRC_DIAGS_WDIAG_PSTAT 0xcUL
#define WRC_DIAGS_WDIAG_PSTAT_LINK 0x1UL
#define WRC_DIAGS_WDIAG_PSTAT_LOCKED 0x2UL
/* Firmware-only static-p startup-lifetime diagnostic carried in PSTAT/ASTAT
 * high bits. Each checkpoint stores p - shell_init_cmd in six bits. */
#define WRC_DIAGS_BOOT_STARTUP_P_OFFSET_MASK 0x3fUL
#define WRC_DIAGS_BOOT_STARTUP_P_OFFSET_INVALID 0x3fUL
#define WRC_DIAGS_BOOT_STARTUP_P_AT_RESET_EARLY_SHIFT 2
#define WRC_DIAGS_BOOT_STARTUP_P_AFTER_BSS_DATA_INIT_SHIFT 8
#define WRC_DIAGS_BOOT_STARTUP_P_AFTER_BOARD_INIT_SHIFT 14
#define WRC_DIAGS_BOOT_STARTUP_P_AFTER_SHELL_INIT_SHIFT 20
#define WRC_DIAGS_BOOT_STARTUP_P_BEFORE_SHELL_BOOT_SCRIPT_SHIFT 26
#define WRC_DIAGS_BOOT_STARTUP_P_AT_BOOT_SCRIPT_ENTRY_SHIFT 8
#define WRC_DIAGS_BOOT_STARTUP_VALID_MASK_SHIFT 14
#define WRC_DIAGS_BOOT_STARTUP_VALID_MASK_MASK 0x3fUL
#define WRC_DIAGS_BOOT_STARTUP_TRACE_VALID (1UL << 20)

/* WRPC Diag: PTP state */
#define WRC_DIAGS_WDIAG_PTPSTAT 0x10UL
#define WRC_DIAGS_WDIAG_PTPSTAT_PTPSTATE_MASK 0xffUL
#define WRC_DIAGS_WDIAG_PTPSTAT_PTPSTATE_SHIFT 0
/* Firmware-only boot-init execution evidence. The PTP state remains in the
 * low byte; these high-byte fields are read-only shadows for bring-up. */
#define WRC_DIAGS_WDIAG_PTPSTAT_BOOT_INIT_ENTER_MASK 0x00000f00UL
#define WRC_DIAGS_WDIAG_PTPSTAT_BOOT_INIT_ENTER_SHIFT 8
#define WRC_DIAGS_WDIAG_PTPSTAT_BOOT_INIT_INDEX_MASK 0x0000f000UL
#define WRC_DIAGS_WDIAG_PTPSTAT_BOOT_INIT_INDEX_SHIFT 12
#define WRC_DIAGS_WDIAG_PTPSTAT_MODE_MASTER_CALL_MASK 0x00ff0000UL
#define WRC_DIAGS_WDIAG_PTPSTAT_MODE_MASTER_CALL_SHIFT 16
#define WRC_DIAGS_WDIAG_PTPSTAT_MODE_MASTER_RETURN_MASK 0xff000000UL
#define WRC_DIAGS_WDIAG_PTPSTAT_MODE_MASTER_RETURN_SHIFT 24

/* Existing private mapping self-test words. The low 16 bits retain the
 * mapping counter/inverse; the high 16 bits carry VLAN/pfilter progress. */
#define WRC_DIAGS_WDIAG_MAPPING_COUNTER 0x134UL
#define WRC_DIAGS_WDIAG_MAPPING_INVERSE 0x138UL
#define WRC_DIAGS_WDIAG_MAPPING_PROGRESS_SHIFT 16
#define WRC_DIAGS_WDIAG_MAPPING_PROGRESS_MASK 0xffff0000UL
#define WRC_DIAGS_VLAN_CMD_ENTER (1UL << 0)
#define WRC_DIAGS_PFILTER_ENTER (1UL << 1)
#define WRC_DIAGS_PFILTER_BEFORE_DISABLE (1UL << 2)
#define WRC_DIAGS_PFILTER_RULE_INDEX_MASK (0x3fUL << 3)
#define WRC_DIAGS_PFILTER_RULE_INDEX_SHIFT 3
#define WRC_DIAGS_PFILTER_AFTER_RULE_WRITE (1UL << 9)
#define WRC_DIAGS_PFILTER_BEFORE_ENABLE (1UL << 10)
#define WRC_DIAGS_PFILTER_RETURN (1UL << 11)
#define WRC_DIAGS_VLAN_CMD_RETURN (1UL << 12)

/* Private read-only lock-wait forensics words. These are firmware shadows
 * outside the generated standard map and never feed back into WR control. */
#define WRC_DIAGS_WDIAG_MODE_MASTER_STAGE 0x158UL
#define WRC_DIAGS_WDIAG_LOCK_WAIT_SUBSTAGE 0x15cUL
#define WRC_DIAGS_WDIAG_LOCK_WAIT_ITERATION 0x160UL
#define WRC_DIAGS_WDIAG_LOCK_WAIT_START_TICS 0x164UL
#define WRC_DIAGS_WDIAG_LOCK_WAIT_CURRENT_TICS 0x168UL
#define WRC_DIAGS_WDIAG_LOCK_WAIT_LAST_LOCK_RESULT 0x16cUL
#define WRC_DIAGS_WDIAG_PERSISTENT_MAGIC 0x170UL
#define WRC_DIAGS_WDIAG_PERSISTENT_MODE_MASTER_STAGE 0x174UL
#define WRC_DIAGS_WDIAG_PERSISTENT_LOCK_WAIT_SUBSTAGE 0x178UL
#define WRC_DIAGS_WDIAG_PERSISTENT_BOOT_GENERATION 0x17cUL
#define WRC_DIAGS_WDIAG_PERSISTENT_STAGE_HISTORY0 0x180UL
#define WRC_DIAGS_WDIAG_PERSISTENT_STAGE_HISTORY1 0x184UL
#define WRC_DIAGS_WDIAG_PERSISTENT_STAGE_HISTORY2 0x188UL
#define WRC_DIAGS_WDIAG_PERSISTENT_STAGE_HISTORY3 0x18cUL
#define WRC_DIAGS_WDIAG_PERSISTENT_SPLL_CHECK_LOCK_STAGE 0x190UL
#define WRC_DIAGS_WDIAG_PERSISTENT_SPLL_CHECK_LOCK_CHANNEL 0x194UL
#define WRC_DIAGS_WDIAG_PERSISTENT_SPLL_CHECK_LOCK_STATE 0x198UL
#define WRC_DIAGS_WDIAG_PERSISTENT_SPLL_CHECK_LOCK_BOOT_GENERATION 0x19cUL
#define WRC_DIAGS_WDIAG_PERSISTENT_CMD_STAGE 0x1a0UL
#define WRC_DIAGS_WDIAG_PERSISTENT_CMD_RX_BYTE_COUNT 0x1a4UL
#define WRC_DIAGS_WDIAG_PERSISTENT_CMD_LAST_BYTE 0x1a8UL
#define WRC_DIAGS_WDIAG_PERSISTENT_CMD_LENGTH 0x1acUL
#define WRC_DIAGS_WDIAG_PERSISTENT_CMD_HASH 0x1b0UL
#define WRC_DIAGS_WDIAG_PERSISTENT_CMD_BOOT_GENERATION 0x1b4UL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_MAGIC 0x1b8UL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_COUNT 0x1bcUL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_MCAUSE 0x1c0UL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_MEPC 0x1c4UL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_MTVAL 0x1c8UL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_RA 0x1ccUL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_SP 0x1d0UL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_BOOT_GENERATION 0x1d4UL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_LAST_MODE_MASTER_STAGE 0x1d8UL
#define WRC_DIAGS_WDIAG_PERSISTENT_FAULT_LAST_SPLL_CHECK_LOCK_STAGE 0x1dcUL
/* Read-only firmware shell-ready gate. These words are diagnostic shadows
 * only; they do not feed back into the WR control path. */
#define WRC_DIAGS_WDIAG_FIRMWARE_MAIN_LOOP_REACHED 0x1e0UL
#define WRC_DIAGS_WDIAG_SHELL_POLL_LOOP_REACHED 0x1e4UL
#define WRC_DIAGS_WDIAG_BOOT_INIT_SEQUENCE_DONE 0x1e8UL
#define WRC_DIAGS_WDIAG_FIRMWARE_SHELL_READY 0x1ecUL
#define WRC_DIAGS_WDIAG_FIRMWARE_MAIN_LOOP_GENERATION 0x1f0UL
#define WRC_DIAGS_WDIAG_SHELL_POLL_GENERATION 0x1f4UL
#define WRC_DIAGS_WDIAG_BOOT_INIT_GENERATION 0x1f8UL

/* WRPC Diag: AUX state */
#define WRC_DIAGS_WDIAG_ASTAT 0x14UL
#define WRC_DIAGS_WDIAG_ASTAT_AUX_MASK 0xffUL
#define WRC_DIAGS_WDIAG_ASTAT_AUX_SHIFT 0

/* WRPC Diag: Tx PTP Frame cnts */
#define WRC_DIAGS_WDIAG_TXFCNT 0x18UL

/* WRPC Diag: Rx PTP Frame cnts */
#define WRC_DIAGS_WDIAG_RXFCNT 0x1cUL

/* WRPC Diag:local time [msb of s] */
#define WRC_DIAGS_WDIAG_SEC_MSB 0x20UL

/* WRPC Diag: local time [lsb of s] */
#define WRC_DIAGS_WDIAG_SEC_LSB 0x24UL

/* WRPC Diag: local time [ns] */
#define WRC_DIAGS_WDIAG_NS 0x28UL

/* WRPC Diag: Round trip (mu) [msb of ps] */
#define WRC_DIAGS_WDIAG_MU_MSB 0x2cUL

/* WRPC Diag: Round trip (mu) [lsb of ps] */
#define WRC_DIAGS_WDIAG_MU_LSB 0x30UL

/* WRPC Diag: Master-slave delay (dms) [msb of ps] */
#define WRC_DIAGS_WDIAG_DMS_MSB 0x34UL

/* WRPC Diag: Master-slave delay (dms) [lsb of ps] */
#define WRC_DIAGS_WDIAG_DMS_LSB 0x38UL

/* WRPC Diag: Total link asymmetry [ps] */
#define WRC_DIAGS_WDIAG_ASYM 0x3cUL

/* WRPC Diag: Clock offset (cko) [ps] */
#define WRC_DIAGS_WDIAG_CKO 0x40UL

/* WRPC Diag: Phase setpoint (setp) [ps] */
#define WRC_DIAGS_WDIAG_SETP 0x44UL

/* WRPC Diag: Update counter (ucnt) */
#define WRC_DIAGS_WDIAG_UCNT 0x48UL

/* WRPC Diag: Board temperature [C degree] */
#define WRC_DIAGS_WDIAG_TEMP 0x4cUL

/* WRPC Diag: Aux0 detailed clock status */
#define WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT 0x50UL
#define WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_PHASE_MASK 0xffffffUL
#define WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_PHASE_SHIFT 0
#define WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_MODE_MASK 0x3000000UL
#define WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_MODE_SHIFT 24
#define WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_ENABLED 0x4000000UL
#define WRC_DIAGS_WDIAG_AUX0_DETAIL_STAT_LOCKED 0x8000000UL

/* WRPC Diag: Aux1 detailed clock status */
#define WRC_DIAGS_WDIAG_AUX1_DETAIL_STAT 0x54UL

/* WRPC Diag: Aux2 detailed clock status */
#define WRC_DIAGS_WDIAG_AUX2_DETAIL_STAT 0x58UL

/* WRPC Diag: Aux3 detailed clock status */
#define WRC_DIAGS_WDIAG_AUX3_DETAIL_STAT 0x5cUL

/* WRPC Diag: RX Error count */
#define WRC_DIAGS_WDIAG_RX_ERR_CNT 0x60UL

/* WRPC Diag: Servo Up Timestamp (MSB) */
#define WRC_DIAGS_WDIAG_SERVO_UPTIME_MSB 0x64UL

/* WRPC Diag: Servo Up Timestamp (LSB) */
#define WRC_DIAGS_WDIAG_SERVO_UPTIME_LSB 0x68UL

/* WRPC Diag: Servo restart count */
#define WRC_DIAGS_WDIAG_SERVO_RESTART_COUNT 0x6cUL

/* WRPC Diag: Transceiver bitslide */
#define WRC_DIAGS_WDIAG_BITSLIDE 0x70UL

/* WRPC Diag: delta_Rx_M parameter from the link delay model */
#define WRC_DIAGS_WDIAG_DELTA_RX_M 0x74UL

/* WRPC Diag: delta_Rx_S parameter from the link delay model */
#define WRC_DIAGS_WDIAG_DELTA_RX_S 0x78UL

/* WRPC Diag: delta_Tx_M parameter from the link delay model */
#define WRC_DIAGS_WDIAG_DELTA_TX_M 0x7cUL

/* WRPC Diag: delta_Tx_S parameter from the link delay model */
#define WRC_DIAGS_WDIAG_DELTA_TX_S 0x80UL

/* WRPC Diag: SoftPLL Helper DAC value (HY) */
#define WRC_DIAGS_WDIAG_SPLL_HY 0x84UL

/* WRPC Diag: SoftPLL Main DAC value (MY) */
#define WRC_DIAGS_WDIAG_SPLL_MY 0x88UL

struct wrc_diags {
  /* [0x0]: REG (rw) Version register */
  uint32_t VER;

  /* [0x4]: REG (rw) Ctrl */
  uint32_t CTRL;

  /* [0x8]: REG (ro) WRPC Diag: servo status */
  uint32_t WDIAG_SSTAT;

  /* [0xc]: REG (ro) WRPC Diag: Port status */
  uint32_t WDIAG_PSTAT;

  /* [0x10]: REG (ro) WRPC Diag: PTP state */
  uint32_t WDIAG_PTPSTAT;

  /* [0x14]: REG (ro) WRPC Diag: AUX state */
  uint32_t WDIAG_ASTAT;

  /* [0x18]: REG (ro) WRPC Diag: Tx PTP Frame cnts */
  uint32_t WDIAG_TXFCNT;

  /* [0x1c]: REG (ro) WRPC Diag: Rx PTP Frame cnts */
  uint32_t WDIAG_RXFCNT;

  /* [0x20]: REG (ro) WRPC Diag:local time [msb of s] */
  uint32_t WDIAG_SEC_MSB;

  /* [0x24]: REG (ro) WRPC Diag: local time [lsb of s] */
  uint32_t WDIAG_SEC_LSB;

  /* [0x28]: REG (ro) WRPC Diag: local time [ns] */
  uint32_t WDIAG_NS;

  /* [0x2c]: REG (ro) WRPC Diag: Round trip (mu) [msb of ps] */
  uint32_t WDIAG_MU_MSB;

  /* [0x30]: REG (ro) WRPC Diag: Round trip (mu) [lsb of ps] */
  uint32_t WDIAG_MU_LSB;

  /* [0x34]: REG (ro) WRPC Diag: Master-slave delay (dms) [msb of ps] */
  uint32_t WDIAG_DMS_MSB;

  /* [0x38]: REG (ro) WRPC Diag: Master-slave delay (dms) [lsb of ps] */
  uint32_t WDIAG_DMS_LSB;

  /* [0x3c]: REG (ro) WRPC Diag: Total link asymmetry [ps] */
  uint32_t WDIAG_ASYM;

  /* [0x40]: REG (ro) WRPC Diag: Clock offset (cko) [ps] */
  uint32_t WDIAG_CKO;

  /* [0x44]: REG (ro) WRPC Diag: Phase setpoint (setp) [ps] */
  uint32_t WDIAG_SETP;

  /* [0x48]: REG (ro) WRPC Diag: Update counter (ucnt) */
  uint32_t WDIAG_UCNT;

  /* [0x4c]: REG (ro) WRPC Diag: Board temperature [C degree] */
  uint32_t WDIAG_TEMP;

  /* [0x50]: REG (ro) WRPC Diag: Aux0 detailed clock status */
  uint32_t WDIAG_AUX0_DETAIL_STAT;

  /* [0x54]: REG (ro) WRPC Diag: Aux1 detailed clock status */
  uint32_t WDIAG_AUX1_DETAIL_STAT;

  /* [0x58]: REG (ro) WRPC Diag: Aux2 detailed clock status */
  uint32_t WDIAG_AUX2_DETAIL_STAT;

  /* [0x5c]: REG (ro) WRPC Diag: Aux3 detailed clock status */
  uint32_t WDIAG_AUX3_DETAIL_STAT;

  /* [0x60]: REG (ro) WRPC Diag: RX Error count */
  uint32_t WDIAG_RX_ERR_CNT;

  /* [0x64]: REG (ro) WRPC Diag: Servo Up Timestamp (MSB) */
  uint32_t WDIAG_SERVO_UPTIME_MSB;

  /* [0x68]: REG (ro) WRPC Diag: Servo Up Timestamp (LSB) */
  uint32_t WDIAG_SERVO_UPTIME_LSB;

  /* [0x6c]: REG (ro) WRPC Diag: Servo restart count */
  uint32_t WDIAG_SERVO_RESTART_COUNT;

  /* [0x70]: REG (ro) WRPC Diag: Transceiver bitslide */
  uint32_t WDIAG_BITSLIDE;

  /* [0x74]: REG (ro) WRPC Diag: delta_Rx_M parameter from the link delay model */
  uint32_t WDIAG_DELTA_RX_M;

  /* [0x78]: REG (ro) WRPC Diag: delta_Rx_S parameter from the link delay model */
  uint32_t WDIAG_DELTA_RX_S;

  /* [0x7c]: REG (ro) WRPC Diag: delta_Tx_M parameter from the link delay model */
  uint32_t WDIAG_DELTA_TX_M;

  /* [0x80]: REG (ro) WRPC Diag: delta_Tx_S parameter from the link delay model */
  uint32_t WDIAG_DELTA_TX_S;

  /* [0x84]: REG (ro) WRPC Diag: SoftPLL Helper DAC value (HY) */
  uint32_t WDIAG_SPLL_HY;

  /* [0x88]: REG (ro) WRPC Diag: SoftPLL Main DAC value (MY) */
  uint32_t WDIAG_SPLL_MY;
};

#endif /* __CHEBY__WRC_DIAGS__H__ */
