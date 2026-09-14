# EXP-S5-WR-EXTENSION-DISABLE-FIRST-CAUSE-FA1DB23-20260914

## Purpose

Capture the first causal boundary that disables the White Rabbit extension.
This experiment is diagnostic-only: it does not change PI parameters,
timeouts, arbitration, bootstrap, or WR state-machine decisions.

## Provenance and procedure

- Laptop branch: `exp/step5-softpll-lock`
- Source commit: `fa1db238f3e8ba6d75bd99dff85f5f818deaf48a`
- Pain checkout: the same commit, recorded in `raw/pain_head.txt`
- The user had confirmed the physical power-cycle before this run; both boards
  were then recompiled and reprogrammed from this commit.
- Master and Slave firmware builds passed.
- Master and Slave JTAG Quartus builds passed.
- Both programming operations passed. The first Master invocation was blocked
  only by an expired sudo cache and was retried with the authorized sudo
  credential; see `raw/program-master-sudo-note.txt`.
- Quartus reports `timing_closed=NO` for both images. This is retained as an
  implementation caveat and is not treated as a Step5 result.
- The observer ran for 180 seconds, sampled both boards, issued no VUART
  command, and reported zero sample errors for both boards.

## Source change

The firmware now records the first call that disables the WR extension. The
record is sticky for the firmware lifetime and distinguishes:

- `PROTOCOL_DETECTION_TIMEOUT`
- `HANDSHAKE_FAILURE`
- `OTHER_CALLER`

It also records the pre-disable PPSI state and timer low word. Existing WR
failure, S-lock, SoftPLL, and event counters remain read-only observations.

## Results

### Master

The first disable record was observed at approximately `44969 ms`:

```text
FIRST_WR_DISABLE_CAUSE=2(HANDSHAKE_FAILURE)
FIRST_WR_DISABLE_PTP_STATE=6
FIRST_WR_DISABLE_PDSTATE=0
FIRST_WR_DISABLE_EXTSTATE=0
FIRST_WR_DISABLE_TICS_LOW16=0
FIRST_WR_FAILURE_REASON=2(WR_M_LOCK_TIMEOUT)
```

The raw failure word was `WR_FAILURE=01036A01`, with one handshake failure.
The WR extension then remained in `PPSI_EXTSTATE=PTP` and `WRS_IDLE` while
PTP traffic and SoftPLL event counters continued. Master was not a Step5
closed-loop target in this run.

The zero values for the SSTAT timer and pre-disable states are an
observability limitation discovered by this run: the current task-diagnostics
code publishes `SSTAT` only in the configured Slave branch, while the first
Master disable is captured in the Master path. The cause itself is still
independently corroborated by `WR_M_LOCK_TIMEOUT` and the handshake failure
word.

### Slave

No first WR-extension-disable record appeared during the 180-second window:

```text
FIRST_WR_DISABLE_MS=NEVER
FIRST_WR_FAILURE_REASON=0(UNKNOWN)
```

The Slave reached the event-processing path and showed these first observed
milestones:

```text
FIRST_LOCK_ENABLE_MS=1125
FIRST_HELPER_LOCKED_MS=13001
FIRST_MAIN_ENABLED_MS=57385
FIRST_MAIN_FREQ_LOCKED_MS=69188
FIRST_MAIN_PHASE_LOCKED_MS=NEVER
FIRST_MAIN_LOCKED_MS=NEVER
FIRST_PSTAT_LOCKED_MS=NEVER
```

The timeline also contained late state transitions and torn-looking SoftPLL
multiword decodes. Those are retained as telemetry caveats; they are not
converted into a lock or loss claim.

## Verdict

```text
FIRST_CAUSE_TRACE = PARTIAL_PASS
MASTER_FIRST_CAUSE = HANDSHAKE_FAILURE / WR_M_LOCK_TIMEOUT
SLAVE_FIRST_DISABLE = NOT_OBSERVED
STEP5 = NOT_COMPLETE
STEP5_PASS = NO
```

This run does not prove Step5. In particular, it does not show the Slave
maintaining complete Main frequency, phase, Main-lock, and PSTAT-lock
conditions in a valid continuous window.

## Next single experiment

First fix the diagnostic publication gap by making the sticky first-disable
record publish directly when the event occurs, while preserving the standard
SSTAT fields. Then repeat the same bounded 180-second first-cause timeline.
Do not change timeout, PI, arbitration, bootstrap, or recovery policy until
the direct caller/timer/state record is complete. If the repeated run again
shows `WR_M_LOCK_TIMEOUT` on Master but no Slave extension failure, separate
the Master-role timeout from the Slave Step5 lock question instead of using
the Master result as evidence that Slave Step5 failed.

## Raw files

The raw directory contains the exact Pain HEAD, build logs, image hashes,
programming logs, and the complete 180-second observer output. Local file
hashes are recorded in `raw/checksums.sha256`.
