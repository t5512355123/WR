# F4K B Arm Report — Slave Main Kp=600

## Verdict

B is a valid 120-second diagnostic arm for the ABA comparison. It reached the
formal target with valid producer data and no WR terminal, reset, PHY, or
single-reader failure. It did not lock the SoftPLL, and the A1/B/A2
comparison cannot be classified until the A2=300 arm is complete.

~~~text
STEP5_PASS          = NO
MERGE_APPROVED      = NO
B_COMPARISON_READY  = YES
FORMAL_STOP         = NONE
~~~

## Reproducibility identity

~~~text
source_commit        = 34013477fc225a8074840e2ba7e0dfb44e69873d
branch               = exp/step5-softpll-lock
arm                  = B
slave_main_kp        = 600
slave_main_ki        = 1
slave_prelock_boost  = 20
master_main_kp        = 300
master_main_ki        = 1
master_prelock_boost = 20
helper_kp             = -2250
helper_ki             = -2
legacy_candidate      = disabled
configuration_source  = firmware/configs/de5a_slave_identity.h
~~~

The F4J producer snapshot and schema were unchanged. The observer was
read-only, used one reader, performed no control write, did not request a
Helper PI snapshot, and did not drain the debug FIFO. The only functional
experiment variable was the Slave Main Kp value.

## Build and programming

Pain pulled commit 34013477 exactly. The build was performed after that pull,
not from an earlier worktree. Both clean Quartus 17.0 Build 595 compilations
succeeded. The Master and Slave were then programmed successfully on
DE5 [1-11.1] and DE5 [1-11.2], respectively, with zero reported programming
errors or warnings.

The build identity gate passed:

~~~text
Master GIT_COMMIT = 34013477fc225a8074840e2ba7e0dfb44e69873d
Slave  GIT_COMMIT = 34013477fc225a8074840e2ba7e0dfb44e69873d
Master MIF SHA256  = 3f8528690daa38cafece36ccb6d24d8ed8a48aaf914801d94052891e63b583df
Slave  MIF SHA256  = f2300b6ee2901c52ec989d740a4b794a6f5a436d5b733071a461e154cc18da8f
Master SOF SHA256  = 58b18b6d8731c001316742d5de8e5772d1b4cc6972bf74e1eaae248df1f172ff
Slave  SOF SHA256  = c988b68df2ff8992102ab11a985ab55c7d920728339f1597b7072f2c1adcb3b2
Master WNS         = -0.047 ns (TIMING_CLOSED=NO)
Slave  WNS         = -0.268 ns (TIMING_CLOSED=NO)
~~~

## Smoke

The 10-second smoke reached its target without an observer stop:

~~~text
session_elapsed_ms = 10641
producer_valid     = 2
producer_unique    = 1
stop_reason        = NONE
single_reader      = PASS
~~~

The startup portion contained invalid producer reads before the producer became
ready. This is recorded in analysis/B-smoke/verdict.json; the formal window
below had no invalid frames and is the authoritative B measurement.

## Formal capture

~~~text
session_elapsed_ms      = 120023
target_duration_ms      = 120000
hard_duration_ms        = 130000
slave_cycles            = 127
producer_valid          = 127
producer_unique         = 64
producer_duplicates     = 63
producer_span_ms        = 119264
valid_background_bins   = 12
frame_errors            = 0
publication_mismatch    = 0
run_end_reason          = TARGET_REACHED
stop_reason             = NONE
single_reader           = PASS
~~~

Across all 127 retained Slave cycles, Helper was locked, the producer was
valid, WR/PHY were usable, and no terminal condition was observed. The reset
fields remained stable:

~~~text
HELPER_LOCKED       = 127/127 cycles
TERMINAL            = 0/159 WR rows
PSTAT_LOCKED        = 0/159 WR rows
BOOT_GENERATION     = 1
CPU_RESET_COUNT     = 1
WR_CORE_RESET_COUNT = 0
SI_CONFIG_DROP_COUNT= 0
~~~

For the full available producer window, the cumulative deltas were:

~~~text
TOTAL_UPDATES      = 455273
FREQ_UPDATES       = 18305
PHASE_UPDATES      = 436968
PHASE_DETECTOR     = 436968
PHASE_IN_BAND      = 59651
PHASE_OUT_BAND     = 377317
in-band ratio      = 0.136511
phase active ratio = 0.959793
handoff delta      = 84 (42 FREQ_TO_PHASE + 42 PHASE_TO_FREQ)
PHASE_COUNT_AFTER  = 100 at both window endpoints
PSTAT_LOCKED       = not observed
~~~

The formal run therefore demonstrates sustained producer and service activity
at Kp=600, but no closed-loop lock and no Step5 pass.

## Offline replay

The formal log was replayed with
scripts/experiment/step5_f4j_main_producer_handoff_audit.py:

~~~text
classification        = DIAGNOSTIC_IMPLEMENTATION_LIMITED
diagnostic_pass        = false
unique                 = 64
span_ms                = 119264
valid_background_bins  = 12
coverage_pass          = true
step5_runtime_ready    = true
step5_pass             = false
merge_approved         = false
~~~

The implementation-limited classification is expected for F4K because the
capture metadata marks production_control_unchanged=0 to identify the
approved functional Kp experiment. The observer itself remained passive.

## Excluded pre-pull capture

A previous B capture was made before the successful source pull. Its build-info
reported commit 1f6fcd89 and its Slave MIF matched the A1 image, so it is not
evidence for B=600. It was moved to the explicitly named
B-invalid-prepull-1f6fcd8 preservation directory and is excluded from all
comparison inputs.

## Next action

Perform the A2 arm with Slave Main Kp=300, using the same pull, build,
program, smoke, formal, replay, report, and push gates. Only after A2 is
complete should the F4K comparator calculate the common-window ABA result.
