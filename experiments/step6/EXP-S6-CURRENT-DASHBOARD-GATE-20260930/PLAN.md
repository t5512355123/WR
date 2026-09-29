# EXP-S6-CURRENT-DASHBOARD-GATE-20260930

## Objective

Take one fresh read-only observation of the existing Step 1–6 dashboard on
Pain, confirming whether both Global-Time snapshots are valid/stable and
whether the Slave WR servo offset satisfies the strict `<60 ps` gate.

## Procedure and safety

- Branch/source checkout: `feat/file_cleanup`, commit `8df3dfcc97a6524b0e4c369fc91a03f2f7bd8f48`.
- Before reading, verify no competing Quartus/JTAG dashboard reader is active.
- Run the existing dashboard once with `ONCE=1`, `OBS_GAP_MS=2000`,
  `WAIT_FOR_GLOBAL_TIME_SECONDS=0`, and `CLEAR_SCREEN=0`.
- Read-only dashboard only. No build, FPGA programming, Wishbone/target write,
  reset, PPS configuration change, or physical power-cycle.
- Preserve the complete console output as raw evidence.

## Gate

The observation is a Step 6 point PASS only if both boards have valid/stable
Global Time and the Slave reports an integer WR servo offset strictly between
−60 ps and +60 ps. This one-shot check does not establish 300-second
repeatability or physical SMA/output-edge skew.
