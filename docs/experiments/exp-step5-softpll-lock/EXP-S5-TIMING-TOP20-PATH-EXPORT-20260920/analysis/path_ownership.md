# Full-path ownership analysis

## Reproduction

The exact fitted databases reproduced the expected slow 900 mV, 100 C
`clk_50m` setup WNS before any ownership conclusion was made:

| Revision | Reported paths | Violated paths | WNS |
| --- | ---: | ---: | ---: |
| Master | 20 | 1 | -0.289 ns |
| Slave | 20 | 1 | -0.361 ns |

`TIMING_DB_REPRODUCTION = PASS`.

## The negative paths

The violation report contains exactly one negative path for each revision.
The path is the same logical crossing in both images:

| Revision | From | To | Launch clock | Latch clock | Data arrival | Data required | Clock skew | Data delay | Slack |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| Master | `rx_activity_toggle` | `rx_activity_meta` | `...xcvr_native_a10_0|rx_clkout` | `clk_50m` | 24.259 ns | 23.970 ns | -3.871 ns | 0.603 ns | -0.289 ns |
| Slave | `rx_activity_toggle` | `rx_activity_meta` | `...xcvr_native_a10_0|rx_clkout` | `clk_50m` | 24.185 ns | 23.824 ns | -3.835 ns | 0.528 ns | -0.361 ns |

The full routing/cell detail is retained in the raw reports.  The endpoint
evidence is also explicit in the report:

- Master: launch `FF_X112_Y9_N7`, data routing through
  `rx_activity_toggle~la_lab/laboutt[4]`, latch `FF_X112_Y9_N50`.
- Slave: launch `FF_X113_Y11_N26`, data through
  `rx_activity_toggle~la_mlab/laboutt[17]` and
  `MLABCELL_X113_Y11_N54`, latch `FF_X113_Y11_N56`.

## Source-cone correlation

The exact fitted source has the following structure in both top levels:

1. `p_rx_activity : process(wr_rx_clk)` toggles `rx_activity_toggle` as a
   receive-clock activity divider.
2. `p_activity_observer : process(CLK_50_B2J)` assigns
   `rx_activity_meta <= rx_activity_toggle`, performs the synchronizer stages,
   and updates the receive-activity counter.
3. The counter is published only through
   `clock_activity_probe(47 downto 32)` and the synchronized status through
   the same diagnostic probe word.
4. `u_clock_activity_probe : altsource_probe` exposes that word through the
   JTAG diagnostic interface; it is not a WR core, SI5340, CPU, or SoftPLL
   control datapath.

Relevant source locations:

| Image | Activity process / assignment | Diagnostic publication |
| --- | --- | --- |
| Master | `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd:539`, `:554`, `:577` | `:595`, `:1028` |
| Slave | `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:577`, `:592`, `:615` | `:759`, `:1172` |

The violating endpoint is therefore a diagnostic observer CDC path.  The
Top-20 reports do contain positive-slack production paths (for example paths
to `si5340a_controller_dco|dpll_pending`), but those are not negative paths
in this requested corner and are not the cause of the reported WNS.

```text
NEGATIVE_CLK50_PATH_OWNERSHIP = DIAGNOSTIC_OBSERVABILITY
```

This classification is limited to the reproduced 100 C slow `clk_50m`
violations.  It does not by itself establish full-chip timing closure.
