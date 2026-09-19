# Static timing extraction

## Build identity

- Pain worktree: `EXP-S5-MAIN-PHASE-KI0-MECHANISM-20260919`
- Pain source HEAD: `5d7d1a46784581dd1396daeb5a24624b62b1c440`
- The relevant RTL/top-level paths are unchanged between this source commit
  and the report-only commit `c480b5b9413fb5750f42f78cc07b1ffea5717719`.
- Quartus Prime: `17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Device: `10AX115N2F45E1SG` (Arria 10)

## 100C slow setup corner used by the advisor's WNS values

| image | WNS (ns) | TNS (ns) | failing clock | failing endpoint-TNS indication |
|---|---:|---:|---|---:|
| Master | -0.289 | -0.289 | `clk_50m` | 1.000 clock-level violating sum |
| Slave | -0.361 | -0.361 | `clk_50m` | 1.000 clock-level violating sum |

The reports do not export a path-count field. Because the clock-level TNS
equals the clock-level WNS at this corner, one violating endpoint is indicated,
but an exact failing-path count is **not claimed**.

## 0C slow setup corner

| image | WNS (ns) | design-wide TNS (ns) | negative clock summaries |
|---|---:|---:|---|
| Master | -0.701 | -0.950 | `clk_50m=-0.701`, `qsfp_ref_125m=-0.249` |
| Slave | -0.771 | -1.075 | `clk_50m=-0.771`, `qsfp_ref_125m=-0.304` |

The 0C results are recorded for completeness. They are not substituted for the
100C values quoted in the current Step5 status.

## Constraint completeness

| image | unconstrained clocks | input ports / paths | output ports / paths |
|---|---:|---:|---:|
| Master | 6 | 13 / 1868 | 18 / 84 |
| Slave | 6 | 13 / 2600 | 18 / 80 |

Both STA databases also report that the generated `wr_core_dmtd_62m496`
constraint at SDC line 4 matched no register, and TimeQuest reports several
clock-like nodes without clock assignments. These findings are recorded as
constraint-quality caveats; they are not used to re-label the functional PLL
result.

## Static observer evidence

The fitter/map artifacts and top-level snapshots show a large JTAG observer
surface clocked from `CLK_50_B2J`:

| image | `altsource_probe` source assignments in map report | top-level processes using `CLK_50_B2J` | `source_clk => CLK_50_B2J` occurrences |
|---|---:|---:|---:|
| Master | 90 | 4 | 45 |
| Slave | 122 | 5 | 61 |

The map report also contains the `wr_jtag_wb_mailbox` source/probe instance and
the WR `wrc_diags_dpram:DIAGS` memory. This supports a diagnostic-observability
hypothesis for the negative `clk_50m` margin, but does not prove that the
worst path traverses those instances.

## Top-20 path availability

The archived `.sta.rpt`, `.sta.summary`, `.sta.qmsg`, and `.sta.rdb` exports
contain clock summaries, warnings, and database payloads, but no exported
Top-20 setup path records with all of:

- slack;
- launch/latch clock;
- from/to node;
- required/data-arrival time; and
- logic-level or cell-count detail.

Therefore:

```text
MASTER_TOP20_PATH_RECORDS = NOT_AVAILABLE_IN_ARCHIVED_EXPORT
SLAVE_TOP20_PATH_RECORDS  = NOT_AVAILABLE_IN_ARCHIVED_EXPORT
EXACT_PATH_OWNERSHIP      = UNRESOLVED
```

The older August DMTD timing logs were intentionally excluded: they are a
different dated experiment and query only DMTD edge-counter paths, not the
current failing `clk_50m` paths.
