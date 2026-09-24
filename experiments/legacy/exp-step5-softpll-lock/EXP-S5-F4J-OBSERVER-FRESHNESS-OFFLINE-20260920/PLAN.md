# EXP-S5-F4J-OBSERVER-FRESHNESS-OFFLINE-20260920

## Purpose

Repair only the host-side F4J observer freshness semantics exposed by the direct runtime confirmation. The FPGA image and all production control remain unchanged.

## Allowed change

In `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`, include `f4j` in the existing `SESSION_EDGE` role branch used by passive F4L/F4S observation:

```tcl
if {$::f4g_run_role eq "f4l" ||
    $::f4g_run_role eq "f4s" ||
    $::f4g_run_role eq "f4j"} {
```

Do not change the terminal-candidate inputs, streak threshold, WR register decoding, or any production firmware/control code. Update the offline test expectation that previously hard-coded the F4L diagnostic owner to `1`; the current F4J image intentionally has that owner at `0`.

## Offline cases

Run the manual Python test functions without FPGA/JTAG:

1. F4J first candidate `1` is a baseline: `SESSION_EDGE`, fresh edge `0`, terminal `0`.
2. F4J `1→1` stays nonterminal.
3. F4J `1→0` clears without terminal.
4. F4J `0→1` creates a fresh edge and terminal.
5. Persistent fresh `0→1` reaches streak 2 and stops.
6. F4L and F4S retain session-edge behavior.
7. F4G and F4M retain legacy behavior.

## Stop rule

After the offline tests pass, stop. Do not rebuild/program the FPGA, do not run hardware F4J, and do not change production controls.
