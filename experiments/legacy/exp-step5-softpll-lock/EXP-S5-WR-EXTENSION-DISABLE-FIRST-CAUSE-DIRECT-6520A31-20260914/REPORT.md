# EXP-S5-WR-EXTENSION-DISABLE-FIRST-CAUSE-DIRECT-6520A31-20260914

## Purpose

Repeat the first WR-extension-disable audit after fixing the publication gap
found in `fa1db23`. The change is diagnostic-only. No PI, timeout, bootstrap,
arbitration, recovery, or WR state-machine decision was changed.

## Provenance and procedure

- Branch: `exp/step5-softpll-lock`
- Source commit: `6520a31efbf904f8a3364773e7dd9a759eccf545`
- Pain checked out exactly this commit (`raw/pain_head.txt`).
- The user had confirmed the physical power-cycle before this experiment;
  both boards were recompiled and reprogrammed afterward.
- Master/Slave firmware builds passed.
- Master/Slave JTAG Quartus builds passed.
- Both programming operations passed. The first Master invocation only hit an
  expired sudo cache and was retried successfully; see the raw note.
- Both Quartus builds report `timing_closed=NO`; this remains an existing
  implementation caveat.
- The observer sampled both boards for 180 seconds, sent no VUART command, and
  reported zero sample errors.

## Change validated

The first-disable record is now published immediately at the event, while
preserving the normal SSTAT fields. The periodic diagnostics path also keeps
the record visible. This specifically covers the Master path, which does not
enter the configured Slave-only servo status writer.

## Results

### Master

The first disable was observed at approximately `50675 ms` with a complete
record:

```text
FIRST_WR_DISABLE_CAUSE=2(HANDSHAKE_FAILURE)
FIRST_WR_DISABLE_PTP_STATE=6
FIRST_WR_DISABLE_PDSTATE=3
FIRST_WR_DISABLE_EXTSTATE=1
FIRST_WR_DISABLE_TICS_LOW16=40606
FIRST_WR_FAILURE_REASON=2(WR_M_LOCK_TIMEOUT)
FIRST_WR_FAILURE_TICS_LOW16=40606
```

The live sample was `WR_FAILURE=01036A01`, i.e. one handshake failure. This
corroborates that the Master path reached WR lock handling and then failed at
the Master lock timeout. Afterward it stayed in ordinary PTP (`PPSI_EXTSTATE`
`PTP`, `WRS_IDLE`). This is not the Slave Step5 lock result.

### Slave

No first WR-extension-disable event was observed in the 180-second window:

```text
FIRST_WR_DISABLE_MS=NEVER
FIRST_WR_FAILURE_REASON=NEVER(UNKNOWN)
```

The Slave did reach the SoftPLL event path:

```text
FIRST_LOCK_ENABLE_MS=1118
FIRST_HELPER_LOCKED_MS=63054
FIRST_MAIN_ENABLED_MS=63054
FIRST_MAIN_FREQ_LOCKED_MS=68969
FIRST_MAIN_PHASE_LOCKED_MS=NEVER
FIRST_MAIN_LOCKED_MS=NEVER
FIRST_PSTAT_LOCKED_MS=NEVER
```

The bounded runtime dashboard independently reported:

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = MAIN_PHASE_LOCK
```

Wishbone transport remained trusted (`353/353` three-way matches, zero wrong,
cross-contamination, timeout, and invalid responses). No Step5 lock claim is
made from the helper or frequency bits alone.

## Verdict

```text
DIRECT_FIRST_DISABLE_PUBLICATION = PASS
MASTER_FIRST_CAUSE = HANDSHAKE_FAILURE / WR_M_LOCK_TIMEOUT
SLAVE_FIRST_DISABLE = NOT_OBSERVED
STEP4B = PASS
STEP5 = NOT_COMPLETE
STEP5_PASS = NO
```

The experiment proves the new causal telemetry works and separates the Master
role's timeout from the Slave Step5 question. It does not prove closed-loop
lock: the Slave never reached a valid Main phase lock, Main lock, and PSTAT
lock combination in this window.

## Next decision boundary

The direct-cause telemetry is now adequate for the next diagnosis. Do not
raise timeouts or sweep PI values based on this run. The next experiment must
use the fresh first-cause data to determine why the Slave remains before
`MAIN_PHASE_LOCK`, while keeping the Master-role `WR_M_LOCK_TIMEOUT` separate.

## Raw files

The raw directory contains the exact Pain HEAD, build/program logs, SOF/MIF
hashes, preflight runtime result, and complete first-cause timeline. Local
hashes are recorded in `raw/checksums.sha256`.
