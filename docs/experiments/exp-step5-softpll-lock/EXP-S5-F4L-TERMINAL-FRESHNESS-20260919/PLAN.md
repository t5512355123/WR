# EXP-S5-F4L-TERMINAL-FRESHNESS-20260919

## Objective

Audit and correct the passive F4L/F4S observer's terminal freshness
semantics. A historical WR failure reason must not be treated as a new
observer session terminal. After the offline check, build and program the
unchanged F4L diagnostic image, then run one 10-second F4L smoke.

## Source change

Only the Tcl observer is changed:

- F4L/F4S use a session-local 0-to-1 terminal-candidate edge.
- F4G/F4M retain their legacy health/first-loss semantics.
- The observer emits terminal candidate, state-change, fresh-edge, and mode
  fields.
- No production C, RTL, SDB, PI, gain, threshold, timeout, bootstrap,
  arbiter, mailbox, PHY, reset, DAC, or control order is changed.

## Fixed experiment

- Branch: exp/step5-softpll-lock
- Source commit: 3a72c199
- QSFP path: QSFP-A lane0
- Master: DE5 [1-11.1]
- Slave: DE5 [1-11.2]
- F4L smoke target: 10000 ms
- F4L hard ceiling: 130000 ms
- One reader, read-only, no Helper PI snapshot
- No formal 120-second capture unless this smoke reaches the required schema

## Commands

Offline:

    bundled-python manual harness for test_step5_f4g.py, test_step5_f4l.py, test_step5_f4m.py

Pain build:

    bash scripts/pain/pain_build_jtag_f4l_step5.sh EXP-S5-F4L-TERMINAL-FRESHNESS-20260919

Pain program:

    bash scripts/pain/pain_program_jtag_f4l_step5.sh EXP-S5-F4L-TERMINAL-FRESHNESS-20260919

Observation:

    quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 10000 30000 f4l

## Stop conditions

Stop after the smoke if no valid Main F4L page set is available, if a fresh
terminal edge appears, or if any reset/generation/link/transport guard fails.
Do not extend the smoke or claim Step5 from a missing frame.
