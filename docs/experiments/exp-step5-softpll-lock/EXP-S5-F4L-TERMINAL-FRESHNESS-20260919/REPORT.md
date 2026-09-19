# EXP-S5-F4L-TERMINAL-FRESHNESS-20260919

## Verdict

The observer freshness correction worked, but the F4L smoke did not reach a
valid Main frame. The result is:

    OBSERVER_TERMINAL_FRESHNESS_FIX = PASS
    F4L_TERMINAL_FROM_STICKY_REASON = NOT_OBSERVED
    F4L_SMOKE_SCHEMA              = NOT_READY
    MAIN_PHASE_DIAGNOSTIC         = NOT_OBSERVED
    STEP5_RESULT                  = NOT_PASS

This run must not be used as phase-lock evidence. It stopped because the
freshly programmed Slave Helper had not locked by the 10-second smoke
boundary, not because the observer saw a new WR terminal.

## Provenance

- Date: 2026-09-19
- Branch: exp/step5-softpll-lock
- Source commit: 3a72c1992b8cea47c00abbd0f5fb9cbfd83a2987
- Remote worktree: /home/b10504072/pain-worktrees/EXP-S5-F4L-TERMINAL-FRESHNESS-20260919
- Hardware path: QSFP-A lane0
- Master: DE5 [1-11.1]
- Slave: DE5 [1-11.2]
- Build/program order: Slave then Master
- Reprogram: yes, once for this experiment

## Offline validation

The bundled Python manual harness ran the existing F4G, F4L, and F4M test
functions:

    PASS 18 tests

The system Python command was only a Windows Store placeholder, so the
workspace-bundled Python executable was used. No pytest package was available;
the test functions were executed directly and assertion failures were
reported.

## Build and programming

Build completed:

    JTAG_F4L_STEP5_BUILD=PASS

SOF hashes:

    Slave 3edaacdeb6cabf4030226b886c14f309e70485d66ff2f6deb9ad8eefd9854564
    Master 934c6e60fade1043a5fbd7d9aa6e77dabcfe688c48f405f41da9e868a76c8bc1

Quartus fitter status was successful for both images. Timing remained open:

    Slave setup slack = -0.361 ns
    Master setup slack = -0.289 ns

Both programmer operations succeeded with zero errors and zero warnings:

    JTAG_F4L_SCHEDULE_OBSERVABILITY_PROGRAM=PASS

The complete build and program logs are preserved under raw/build and
raw/program.

## F4L smoke evidence

Command:

    quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 10000 30000 f4l

The observer configuration was read-only with one reader and a 10000 ms smoke
window. The Slave WR core stayed healthy during the observed contexts:

    CORE_TM_LINK_UP=1
    CORE_LINK_OK=1
    PHY_LINK_USABLE=1
    PSTAT_LINK=1
    RESET_CHANGED=0
    WR_FAILURE_REASON=0
    WR_DISABLE_VALID=0
    TERMINAL=0
    TERMINAL_CANDIDATE=0
    TERMINAL_FRESHNESS_MODE=SESSION_EDGE

The freshness fix therefore prevented the historical terminal misclassification
seen in the previous session.

The startup/diagnostic gate did not become valid:

    HELPER_LOCKED=0
    HELPER_LOCK_COUNT=100
    MAIN_F4L_VALID=0
    PAGE0=0
    PAGE1=0
    PAGE2=0

The run ended at 11294 ms with:

    STOP_REASON=F4L_SMOKE_SCHEMA_NOT_READY
    RUN_END_REASON=STOP_F4L_SMOKE_SCHEMA_NOT_READY
    DIAGNOSTIC_COMPLETE=PENDING_OFFLINE_ANALYSIS
    STEP5_COMPLETE=NO
    STEP5_PASS=NO

There was no valid Main F4L summary, integrator, or histogram frame, so phase
drift, integrator balance, and Step5 lock cannot be evaluated from this run.

## Interpretation and next boundary

This experiment separates the previous observer bug from the current startup
boundary:

    sticky WR failure misclassified as new terminal = fixed
    fresh-program Helper acquisition by smoke deadline = not achieved
    Main F4L producer frame = not reached
    Step5 = not pass

Do not run the 120-second formal F4L capture from this result. The next
decision must address the fresh-program Helper startup boundary under the
existing frozen control parameters; it must not tune PI or reinterpret the
missing Main frame as phase failure.

## Raw artifact hashes

    raw/observe/f4l_smoke.log
      SHA256 264F7F7E631CA0467CA33FEAFA2BC1393CF33FFB20B9FF3F69B8639F314CC4F6
    raw/build/overall-build.log
      SHA256 D0E7AE79D2B552E3DF769E668E51A0358BA56028FF2414392BF613C20FFBF3AE
    raw/program/overall-program.log
      SHA256 E4D7CB5EA004DCB4AD73BAAEAA3AE19C07CBB6A691211E46D9D4EB56A563B67B
