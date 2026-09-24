# EXP-S5-MAIN-START-AUTHORITY-READ-20260919

## Purpose

Confirm the direct Helper/Main SoftPLL state after the preceding read-only
Helper-to-DCO correlation, without reprogramming the already link-up QSFP-A
lane-0 session.

## Frozen controls

- No source, RTL, PI, gain, threshold, timeout, bootstrap, PHY, reset, or
  control-branch change.
- No FPGA programming or power cycle.
- Use the existing read-only `read_wb_runtime.tcl --raw` dashboard.
- Wishbone mailbox operations are read requests only.

## Stop condition

Run exactly one direct runtime read. Stop after the raw result is saved. If
Helper is locked and Main is enabled with stable link/reset counters, the next
permitted action is a short F4L schema smoke on the same session; otherwise
stop at the reported boundary.
