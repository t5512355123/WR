# F4K A1 Arm Report — Slave Main Kp=300

## Verdict

A1 is **not ready for the ABA comparison**. The capture was source- and
frame-valid until the White Rabbit session terminated, but it did not reach
the preregistered 120,000 ms formal window and ended with a Slave lock
timeout. This arm is retained as evidence and is not treated as a Step5
result.

~~~text
STEP5_PASS          = NO
MERGE_APPROVED      = NO
A1_COMPARISON_READY = NO
STOP                = WR_SESSION_ENDED
WR_FAILURE_REASON   = 3 (WR_S_LOCK_TIMEOUT)
~~~

## Reproducibility identity

~~~text
source_commit        = 1f6fcd89096dbfa4dfc9ac0f744a6a1fe08449a5
branch               = exp/step5-softpll-lock
arm                  = A1
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
~~~

The F4J producer snapshot and schema were unchanged. The observer was
read-only, used one reader, performed no control write, did not request a
Helper PI snapshot, and did not drain the debug FIFO. The only functional
experiment variable was the Slave Main Kp configuration above.

## Build and programming

Pain pulled the exact source commit and completed clean Master and Slave
builds with Quartus 17.0 Build 595. Both JTAG programming scripts completed
successfully on the intended cables (Master DE5 [1-11.1], Slave DE5 [1-11.2]),
with zero reported programming errors or warnings. The raw program console
was not separately captured; build identity and image/evidence hashes are
preserved under raw/A1/build/ and raw/A1/image-and-evidence.sha256.

~~~text
Master SOF SHA256 = b05175b38fe6c69290ca6551b4c7c2d59342b83ef4cf1f6fdc1534667080d5b5
Slave  SOF SHA256 = 02a3ae5aa3f55782968c889f7ae69c3fff2102619e91d0db92b9e4d9e0a9859d
Master WNS        = -0.047 ns (TIMING_CLOSED=NO)
Slave  WNS        = -0.268 ns (TIMING_CLOSED=NO)
~~~

## Capture procedure and raw evidence

The 10-second smoke was effective:

~~~text
target_duration_ms = 10000
session_elapsed_ms  = 11034
producer_valid      = 12
producer_unique     = 7
stop_reason         = NONE
single_reader       = PASS
~~~

The formal capture used the planned 120,000 ms target and 130,000 ms hard
limit. It stopped at 40,907 ms because the observer detected a terminal WR
condition:

~~~text
session_elapsed_ms      = 40907
target_duration_ms      = 120000
hard_duration_ms        = 130000
slave_cycles            = 43
producer_valid          = 43
producer_unique         = 22
producer_duplicates     = 21
producer_span_ms        = 39830
valid_background_bins   = 4
frame_errors            = 0
publication_mismatch    = 0
run_end_reason          = STOP_WR_SESSION_ENDED
stop_reason             = WR_SESSION_ENDED
~~~

The last Slave WR sample reported WR_FAILURE_RAW=02028A01 and
WR_FAILURE_REASON=3, which maps to WR_S_LOCK_TIMEOUT. At that point
TERMINAL=1, WR_DISABLE_VALID=1, PSTAT_LOCKED=0, and the observer stopped
with WR_SESSION_ENDED. Before termination, the sampled Helper state,
producer validity, WR core validity, and PHY usability remained valid. The
capture also showed BOOT_GENERATION=1, CPU_RESET_COUNT=1,
WR_CORE_RESET_COUNT=0, and SI_CONFIG_DROP_COUNT=0 throughout the retained
rows; the terminal lock failure nevertheless makes the arm unsafe for the
formal comparison gate.

For the available producer window (not a full formal window), the cumulative
counter deltas were:

~~~text
TOTAL_UPDATES      = 151761
PHASE_UPDATES      = 147967
PHASE_DETECTOR     = 147967
PHASE_IN_BAND      = 20182
PHASE_OUT_BAND     = 127785
in-band ratio      = 0.136395
phase active ratio = 0.975000
handoff delta      = 10 (5 FREQ_TO_PHASE + 5 PHASE_TO_FREQ)
PSTAT_LOCKED       = not observed
~~~

These partial-window values are descriptive only. They must not be compared
against B or A2 as if A1 were a valid 120-second arm.

## Offline replay

The captured log was replayed with
scripts/experiment/step5_f4j_main_producer_handoff_audit.py:

~~~text
classification        = DIAGNOSTIC_IMPLEMENTATION_LIMITED
diagnostic_pass       = false
unique                = 22
span_ms               = 39830
valid_background_bins = 4
coverage_pass         = true (coverage only)
step5_pass            = false
merge_approved        = false
~~~

DIAGNOSTIC_IMPLEMENTATION_LIMITED is expected for F4K because the capture
metadata correctly marks production_control_unchanged=0; it is not a claim
that the passive observer changed runtime control. The independent F4K arm
gate additionally rejects this arm for the short formal window and terminal
WR stop.

## Operational note

One preliminary formal invocation was discarded because its tee destination
used an incorrect, non-existent experiment path; it was interrupted and is
not evidence. Only raw/A1/observer-formal.log, saved at the planned path, is
authoritative for this arm.

## Next action

Proceed to the B arm with Slave Main Kp=600, preserving every other control
boundary. If B also terminates at the Slave lock gate, record the failure as
an environmental or pre-lock reproducibility issue rather than inferring a
closed-loop Kp effect. No Step5 PASS or merge decision is possible from this
A1 arm.

