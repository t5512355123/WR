# F4K A2 Arm Report — Slave Main Kp=300

## Verdict

A2 is a valid 120-second diagnostic arm for the ABA comparison. It reached
the formal target with valid producer data and no WR terminal, reset, PHY, or
single-reader failure. It did not lock the SoftPLL: `PSTAT_LOCKED` remained
zero throughout the retained WR rows. The arm is therefore a valid negative
observation, not a Step5 result.

~~~text
STEP5_PASS          = NO
MERGE_APPROVED      = NO
A2_COMPARISON_READY = YES
FORMAL_STOP         = NONE
PSTAT_LOCKED        = 0/159 WR rows
~~

## Reproducibility identity

~~~text
source_commit        = bbfa055e8138013cff484372f27c2c879f3b9d25
branch               = exp/step5-softpll-lock
arm                  = A2
slave_main_kp        = 300
slave_main_ki        = 1
slave_prelock_boost  = 20
master_main_kp       = 300
master_main_ki       = 1
master_prelock_boost = 20
helper_kp             = -2250
helper_ki             = -2
legacy_candidate      = disabled
configuration_source  = firmware/configs/de5a_slave_identity.h
~~

The F4J producer snapshot and schema were unchanged. The observer was
read-only, used one reader, performed no control write, did not request a
Helper PI snapshot, and did not drain the debug FIFO. The only functional
experiment variable was the Slave Main Kp configuration above. The F4K
metadata marks the production-control experiment as changed; this is the
expected comparator marker and does not mean that the observer wrote control
state.

## Build and programming

Pain pulled the exact source commit and completed clean Master and Slave
builds with Quartus 17.0 Build 595. Both images were then programmed on the
intended cables (Master DE5 [1-11.1], Slave DE5 [1-11.2]); both programming
operations reported zero errors and zero warnings. The build identity and
image/evidence hashes are preserved under `raw/A2/build/` and
`raw/A2/image-and-evidence.sha256`.

~~~text
Master GIT_COMMIT = bbfa055e8138013cff484372f27c2c879f3b9d25
Slave  GIT_COMMIT = bbfa055e8138013cff484372f27c2c879f3b9d25
Master MIF SHA256  = 8e62e872bf234fb16e59f7d1818e092642a0b193761ea06b0ba896a4e436a9e7
Slave  MIF SHA256  = ba2ba1e786fb31d94dacbe86dbd6022823a45eae06c9543148a19e7ac8726ae0
Master SOF SHA256  = c3f1ed9c07bd3d3cc00e3c479b2c6aa73b4f69e4b2333f88243a0ed5ee26041e
Slave  SOF SHA256  = ad9b68c8e2e80dc91665524893e550396d0ed66c8c5659dc82f3ac8cfe1c4d5e
Master WNS         = -0.047 ns (TIMING_CLOSED=NO)
Slave  WNS         = -0.268 ns (TIMING_CLOSED=NO)
~~

## Smoke

The 10-second smoke reached its target without an observer stop:

~~~text
target_duration_ms = 10000
session_elapsed_ms = 10204
producer_valid     = 5
producer_unique    = 3
stop_reason        = NONE
single_reader      = PASS
~~

The smoke contains the expected startup warm-up/invalid-read portion. The
formal capture below is the authoritative A2 measurement.

## Formal capture

~~~text
session_elapsed_ms      = 120553
target_duration_ms      = 120000
hard_duration_ms        = 130000
slave_cycles            = 127
producer_valid          = 127
producer_unique         = 64
producer_duplicates     = 63
producer_span_ms        = 118927
valid_background_bins   = 12
frame_errors            = 0
publication_mismatch    = 0
run_end_reason          = TARGET_REACHED
stop_reason             = NONE
single_reader           = PASS
~~

Across all retained cycles, Helper was locked, the producer was valid, WR/PHY
were usable, and no terminal condition was observed. The reset fields stayed
stable:

~~~text
HELPER_LOCKED       = 127/127 cycles
TERMINAL            = 0/159 WR rows
PSTAT_LOCKED        = 0/159 WR rows
BOOT_GENERATION     = 1
CPU_RESET_COUNT     = 1
WR_CORE_RESET_COUNT = 0
SI_CONFIG_DROP_COUNT= 0
~~

For the full available producer window, the cumulative deltas were:

~~~text
TOTAL_UPDATES      = 455282
FREQ_UPDATES       = 17452
PHASE_UPDATES      = 437830
PHASE_DETECTOR     = 437830
PHASE_IN_BAND      = 59607
PHASE_OUT_BAND     = 378223
in-band ratio      = 0.136142
phase active ratio = 0.961668
handoff delta      = 52 (26 FREQ_TO_PHASE + 26 PHASE_TO_FREQ)
PHASE_COUNT_AFTER  = 100 -> 107 at the sampled window endpoints
PSTAT_LOCKED       = not observed
~~

The producer therefore remained active for the complete formal window at
Kp=300, but its activity did not result in closed-loop lock.

## Offline replay

The formal log was replayed with
`scripts/experiment/step5_f4j_main_producer_handoff_audit.py` and the F4K
arm/comparison tooling:

~~~text
classification        = DIAGNOSTIC_IMPLEMENTATION_LIMITED
diagnostic_pass       = false
unique                = 64
span_ms               = 118927
valid_background_bins = 12
coverage_pass         = true
step5_runtime_ready   = true
step5_pass            = false
merge_approved        = false
~~

The implementation-limited classification is expected for F4K because the
capture metadata identifies the approved Kp experiment. The observer remained
passive and the formal safety gates passed.

## Next action

Use this arm as the valid A2 input to the F4K comparator. Do not call Step5
PASS, merge, or change additional control parameters from this arm alone.

