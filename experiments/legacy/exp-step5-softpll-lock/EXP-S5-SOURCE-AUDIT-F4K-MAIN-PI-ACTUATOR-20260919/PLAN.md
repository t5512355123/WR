# EXP-S5-SOURCE-AUDIT-F4K-MAIN-PI-ACTUATOR-20260919

## Scope

Offline source/data audit required by `ai_advice/Step5/14_Astra.md` before
another Step5 hardware run.  This is not a control experiment and does not
authorize a new SOF or a parameter change.

## Questions

1. What do the valid F4K B/A2 windows actually support?
2. Is the Main integrator trace taken from the same producer iteration as the
   branch/error and DAC write?
3. What is the concrete Main PI -> `DAC_MAIN` -> RTL -> DCO target/applied
   path, including units and quantization?
4. What is the smallest next diagnostic change after the lane-0 link recovery
   and the invalid F4L smoke?

## Frozen boundaries

- no PI, gain, threshold, timeout, bootstrap, arbiter, mailbox, detector,
  PHY, reset, RTL, SDB, or control-branch changes;
- no hardware programming or WB/control writes;
- do not reinterpret the invalid A1 arm as a valid ABA result;
- do not infer Step5 from link-up, Helper update progress, or an invalid F4L
  frame.

## Evidence inputs

- F4K comparison: `analysis/comparison/comparison.json`;
- F4K valid producer tables: `analysis/B/main_producer_unique.csv` and
  `analysis/A2/main_producer_unique.csv`;
- F4K link/reset tables: `analysis/B/wr_core.csv` and
  `analysis/A2/wr_core.csv`;
- lane-0 recovery/F4L report:
  `EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260919/REPORT.md`;
- source paths and line references recorded in `SOURCE_AUDIT.md`.
