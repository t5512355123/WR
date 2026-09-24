# EXP-S5-FAST100C-RX2SYS-CDC-INTENT-AUDIT-20260920

## Purpose

Reclassify every negative Fast 900mV/100C hold path terminating at
`u_sys_clk_625` by CDC intent. The previous Top-20 audit proved that the
hierarchy split was mixed, but it did not establish which paths are legitimate
first-stage CDC synchronizers and which paths require real timing closure.

The audit must classify all negative paths, not just the Top-20:

```text
Master = 113 negative paths
Slave  = 114 negative paths
```

## Frozen baseline

- Quartus Prime 17.0.0 Build 595.
- Existing fitted databases from build commit
  `54919aa7b9a4048228d6f121a205898c804e1aee`.
- Master revision: `DE5a_wr_master_jtag`.
- Slave revision: `DE5a_wr_slave_jtag`.
- Fast 900mV 100C timing model.
- Clock: `u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk`.

## Laptop action

Add only this plan and the read-only TimeQuest export Tcl. No RTL, C, SDC,
QSF, firmware, PI/gain, threshold, timeout, detector, anti-windup,
bootstrap, arbiter, mailbox, PHY, reset, control-branch, or fitter changes.

## Pain action

After pull, use the existing fitted databases. Do not clean-compile, program,
reset, power-cycle, or run hardware observation.

For each image the audit must:

1. Reconstruct Fast 900mV/100C timing.
2. Assert the system clock collection is exactly one.
3. Reproduce the previous WNS and negative-path counts.
4. Export the Top-20 full paths.
5. Export all negative paths with `-npaths 0 -detail full_path -show_routing`.
6. Preserve raw tool logs and checksums.

The hard reproduction gate is:

```text
Master WNS = -0.502 ns, negative paths = 113
Slave  WNS = -0.486 ns, negative paths = 114
```

Any mismatch stops the experiment and makes classification `NOT_EVALUATED`.

## Source classification rules

Every negative path must be assigned exactly one CDC intent:

1. `CDC_FIRST_STAGE`: source code proves an asynchronous source enters a
   destination-domain first metastability register, followed by a second
   synchronizer stage. Include `gc_sync_register`, `gc_sync`,
   `gc_sync_ffs`, `gc_pulse_synchronizer`, and async-FIFO Gray-pointer
   synchronizers only when the source evidence proves the pattern.
2. `CDC_PROTOCOLLED_MULTIBIT`: a multi-bit bus is held stable and sampled
   under a separately synchronized toggle/strobe/handshake protocol.
3. `TRUE_SYNCHRONOUS`: source evidence proves a deterministic synchronous
   relationship between launch and latch domains.
4. `UNSAFE_OR_UNRESOLVED_CDC`: a cross-domain path has no proven
   synchronizer, async FIFO, handshake, or stable-bus protocol. Do not hide it
   with a timing exception.

Do not infer intent only from hierarchy or from the endpoint name. Record the
source-code justification for every family.

## Stop condition

Stop only after Master and Slave each have:

- exact WNS and negative-path count reproduction;
- every negative path assigned exactly one intent;
- `UNCLASSIFIED_PATH_COUNT = 0`, or an explicit `CDC_INTENT_AUDIT = INCOMPLETE`
  if any path cannot be proven;
- per-family counts, worst slack, clocks, hierarchy, and source justification.

Do not add `set_false_path`, `set_clock_groups`, `set_min_delay`,
`set_max_delay`, multicycle constraints, RTL synchronizers, delay chains, or
fitter optimizations in this experiment.
