# EXP-S5-F4G-COMPACT-HELPER-MAIN-SERVICE-WINDOW-20260915

## Verdict

```text
CLASSIFICATION = INCONCLUSIVE
DIAGNOSTIC_PASS = NO
STEP5_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
```

This experiment did not establish Step 5. It did establish that the compact
Helper/Main producer and service-counter transport can be observed for the
full target window, but the required phase-qualified observation window never
opened because the runtime WR/PHY usable gate was not true.

## Scope and source contract

The experiment was the F4G read-only audit requested by the Step 5 advice:

```text
EXP-S5-F4G-COMPACT-HELPER-MAIN-SERVICE-WINDOW-20260915
```

The pre-hardware source audit is recorded in
[helper_source_contract.md](helper_source_contract.md). It verified the
Helper publication offsets and L2 counter semantics, while correctly leaving
dynamic ownership as unavailable:

```text
SOURCE_CONTRACT_VERIFIED = YES
DYNAMIC_OWNER_VERIFIED = NOT_AVAILABLE
SOURCE_BACKED_CORE = LIMITED
```

Only the read-only F4G observer and its offline analyzer/tests were changed.
No production C/RTL, PI parameters, gain, threshold, timeout, bootstrap,
arbitration, mailbox, or reset logic was changed.

## Reproducibility metadata

| Item | Value |
|---|---|
| Branch | `exp/step5-softpll-lock` |
| Capture source commit | `3708d85b576236b1407efb7d50c99a30c0e42996` |
| Pain checkout | `3708d85b576236b1407efb7d50c99a30c0e42996` |
| Observer role | `f4g` |
| Target duration | `120000 ms` |
| Hard deadline | `130000 ms` |
| Reader contract | one reader; no control writes |
| Raw observer SHA-256 | `be9e24dac855a0e3c0b7858feae8fcb5f041d4138cc6eb9505869fd20fae94d7` |
| Raw archive SHA-256 | `74d17102d854cbfa50b30db90982f11374d84b426d87401eefe500b15513b8db` |

The Pain-side SOF manifest is preserved at
[sof.sha256](raw/attempt-3708d85-f4g-jtag-runtime/sof.sha256):

```text
Master SOF = 968afc4d3338eb285f88ae744e463ea3222c0f610dbe1677b19537619d3db3ee
Slave  SOF = b211159285c7bb52c4a1c50a94d2935a052748a954f385a4b127ccfdbd04c0c2
```

Both JTAG runtime images were built and programmed on Pain at the exact
capture commit. Both builds reported `PASS`; Quartus timing remained open
(`TIMING_CLOSED=NO`). Programming completed with zero JTAG errors on Master
(`DE5 [1-11.1]`) and Slave (`DE5 [1-11.2]`).

## Capture result

The observer command was:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 240 500 "" 120000 130000 f4g
```

The capture ended normally at the target, not at a failure stop:

```text
session_elapsed_ms=120374
slave_cycles=92
master_samples=31
run_end_reason=TARGET_REACHED
stop_reason=NONE
single_reader=PASS
step5_complete=NO
step5_pass=NO
merge_approved=NO
```

The complete raw log is [observer.log](raw/attempt-3708d85-f4g-jtag-runtime/observer.log),
and the transferred archive is
[attempt-3708d85-f4g-jtag-runtime.tgz](raw/attempt-3708d85-f4g-jtag-runtime.tgz).

## Observed evidence

The independent replay is in
[verdict.json](analysis/replay-3708d85-f4g-jtag-runtime/verdict.json),
[bins.csv](analysis/replay-3708d85-f4g-jtag-runtime/bins.csv), and
[counter_support.csv](analysis/replay-3708d85-f4g-jtag-runtime/counter_support.csv).

| Evidence | Result |
|---|---:|
| Helper accepted CORE records | 92 |
| Helper locked records | 92/92 |
| Main CORE valid records | 92/92 |
| Fresh 10-second data bins | 12 |
| Main frequency-locked records | 89/92 |
| Main phase-locked records | 0/92 |
| PHY/WR usable records | 0/92 |
| Phase-qualified records | 0 |
| Reset/generation changes | 0 |
| Main completed delta | 84028 |
| Helper completed delta | 11408 |
| Main failed delta | 0 |
| Helper failed delta | 0 |

The Main and Helper service-counter fields each had 91 trusted same-field
delta samples over the capture coverage (`366..119945 ms`). This is valid
evidence of counter progress, not proof of same-cycle causality. The analyzer
also retained the fact that no trusted Helper/Main demand interval was
available for a demand-versus-service claim.

The late capture still showed fresh Helper CORE data, fresh Main sample
progress in most cycles, `MAIN_ENABLED=1`, `MAIN_FREQ_LOCKED=1`,
`MAIN_PHASE_LOCKED=0`, and `PSTAT_LOCKED=0`. The runtime WR core reported
`PHY_LINK_USABLE=0` throughout the 92 Slave cycles, so the F4G phase gate
properly rejected every cycle. Intermittent position invalidity was treated as
optional telemetry and did not invalidate the CORE transport.

## Interpretation

This run supports the narrower statement that Main/Helper service counters
continued to advance while phase remained unlocked. It does **not** qualify as
`MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK`, because that diagnosis requires
multiple 10-second bins after the WR/PHY phase-qualification gate. It also
does not support `MAIN_DEMAND_SERVICE_GAP_SUSPECTED`, because a trusted demand
interval was not obtained.

The correct result is therefore `INCONCLUSIVE`, not Step 5 pass and not a
parameter-tuning signal. In particular, `MAIN_FREQ_LOCKED=1` and positive
service deltas cannot be promoted to closed-loop lock while `MAIN_PHASE_LOCKED`
and `PSTAT_LOCKED` remain zero and the WR/PHY usable gate is down.

## Offline verification

```text
F4G_TESTS_PASS
py_compile = PASS
source-code git diff --check = PASS
```

The raw observer log is retained verbatim for checksum reproducibility; its
vendor-tool banner contains trailing spaces, so a repository-wide staged diff
check reports those raw-log lines by design.

The experiment ends here as requested. No automatic follow-up experiment was
started.
