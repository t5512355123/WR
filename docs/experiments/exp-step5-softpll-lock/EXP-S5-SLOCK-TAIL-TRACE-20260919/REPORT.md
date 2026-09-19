# EXP-S5-SLOCK-TAIL-TRACE-20260919

## Verdict

This experiment confirms a real firmware S_LOCK timeout, but does not prove
that the F4L observer created a new terminal event. The result is:

    FIRMWARE_S_LOCK_TIMEOUT_OCCURRED = YES
    F4L_NEW_TERMINAL_EDGE            = NOT_PROVEN
    F4L_STOP_CLASSIFICATION          = STICKY_HISTORICAL_TERMINAL
    STEP5_RESULT                     = NOT_PASS

The Step5 phase-lock condition remains unmet:

    PSTAT_LOCKED = 0
    MAIN_PHASE_LOCKED = 0

## Provenance

- Date: 2026-09-19
- Branch: exp/step5-softpll-lock
- Baseline report/source commit: a81f8edf
- Remote worktree: /home/b10504072/pain-worktrees/EXP-S5-HELPER-STARTUP-RAIL-DIAGNOSTIC-LANE0-20260919
- QSFP path: QSFP-A lane0
- Master: DE5 [1-11.1]
- Slave: DE5 [1-11.2]
- Program/recompile: not performed
- Observer mode: read-only, one reader, one Slave context

The exact command was:

    quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 1 100 "" 3000 3000 f4m

Although the entry point is named f4m, this run was used only to read the
existing S_LOCK tail trace. It was not interpreted as an F4M acquisition run.

## Authoritative S_LOCK evidence

The single STEP5_F4M_FIRST_LOSS_SAMPLE reported:

| Field | Value | Meaning |
|---|---:|---|
| trace_valid | 1 | Trace record is valid |
| SLOCK_MAGIC_RAW | 5752534C | Expected S_LOCK magic |
| SLOCK_STAGE | 4 | Firmware reached timeout-expired stage |
| SLOCK_RETRY | 0 | No retry recorded in this tail record |
| SLOCK_ENTRY_TICS | 64572 | Firmware entry timestamp |
| SLOCK_REMAINING_MS | 0 | Deadline actually expired |
| SLOCK_POLL_RET | 1 | Poll returned a valid result |
| SLOCK_WR_STATE | 2 | S_LOCK state at the trace record |
| SLOCK_SEQ | 3384928 | Firmware trace sequence |

This is stronger evidence than the observer's terminal flag: the firmware
itself recorded stage 4 with zero remaining time.

## Session context

The same one-shot read showed:

- WR link remained usable: CORE_TM_LINK_UP=1, CORE_LINK_OK=1,
  PHY_LINK_USABLE=1, PSTAT_LINK=1.
- No reset-generation change was observed: WR_CORE_RESET_COUNT=0,
  SI_CONFIG_DROP_COUNT=0, RESET_CHANGED=0.
- Helper was locked: HELPER_LOCKED=1, HELPER_LOCK_COUNT=1000.
- Main had started: MAIN_ENABLED=1, SPLL_STATE_RAW=00030006
  (SEQ_WAIT_MAIN in the existing source contract).
- Main frequency acquisition was active/locked in the sampled frame, but
  phase was not locked: MAIN_PHASE_LOCKED=0, PSTAT_LOCKED=0.
- The observer collected only page 0; page 1 and page 2 were not observed
  before the sticky terminal stopped the run.

## Correct interpretation

The direct pre-F4L runtime read already contained WR_FAILURE_REASON=3.
The one-shot tail read now proves that reason 3 corresponds to a real
firmware S_LOCK timeout that reached SLOCK_STAGE=4 and
SLOCK_REMAINING_MS=0.

Therefore the F4L result STOP_WR_SESSION_ENDED must not be reported as a
new failure caused by F4L. The current observer terminal rule sees a
historical/sticky failure reason but does not establish that the reason
changed after the observer started. The F4L page-schedule result is therefore
not interpretable as a Step5 phase-lock result in this session.

## Scope and stop compliance

- No production C or RTL was changed.
- No PI, gain, threshold, timeout, bootstrap, arbiter, mailbox, PHY, reset,
  DAC, or control order was changed.
- No image was rebuilt or programmed.
- The one-shot read was executed once and then stopped.

The local key raw lines are preserved in:

raw/f4m_slock_tail_trace_key_raw.log

This experiment stops here. Do not rerun F4L using the current observer
terminal rule until session-freshness/terminal-edge handling is audited.
