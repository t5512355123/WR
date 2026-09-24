# EXP-S5-F4J-PRODUCER-AUDIT-FREQ-COUNT-20260920

## Purpose

Run the bounded 30-second F4J producer audit after the F4J observer freshness-only
patch. The audit is read-only and is intended to correlate, within one coherent
Main producer frame, `FREQ_ERROR`, `FREQ_COUNT_BEFORE/AFTER`, and `BRANCH_ID`.

## Fixed provenance

- FPGA image source: `63bf952a3ea46dd0231f12d6d3e9b86d816ed953`
- Observer/test source: `b4ca04ac`
- Pain checked-out source for corrected run: `eee68028`
- Reprogram: `NO`
- Production-control change: `NONE`
- Command:
  `quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 2400 100 "" 30000 40000 f4j`

## Stop rules

- Stop at the 30-second target or at any F4J early-stop/invalid condition.
- Do not change threshold, delock floor, Kp/Ki, timeout, or any control path.
- Do not run a control candidate after this audit.

## Execution note

The first attempt was invalid because Pain had not yet pulled the observer commit
and reported `TERMINAL_FRESHNESS_MODE=LEGACY`. The old report data was preserved
outside the worktree, Pain was fast-forwarded to `eee68028`, and the corrected
attempt was run on the same live FPGA session without reprogramming.
