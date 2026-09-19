# EXP-S5-TIMING-TOP20-PATH-EXPORT-20260920

## Result

This was an offline, read-only TimeQuest report-generation experiment.  It
used Quartus Prime 17.0.0 Build 595 and the existing fitted databases for
source/build identity `5d7d1a46784581dd1396daeb5a24624b62b1c440`.

```text
TIMING_DB_REPRODUCTION             = PASS
MASTER_CLK50_NEGATIVE_PATHS        = 1
SLAVE_CLK50_NEGATIVE_PATHS         = 1
MASTER_NEGATIVE_PATH_OWNERSHIP     = DIAGNOSTIC_OBSERVABILITY
SLAVE_NEGATIVE_PATH_OWNERSHIP      = DIAGNOSTIC_OBSERVABILITY
TOP20_PATH_OWNERSHIP                = RESOLVED_FOR_CLK50_100C_SLOW
FUNCTIONAL_MAIN_PHASE_LOCK_120S    = PASS (prior validated experiment)
FUNCTIONAL_STEP5_LOCK              = PASS (prior validated experiment)
TIMING_CLOSED                      = NO
STEP5                              = NO (overall milestone still awaits timing closure)
```

## Scope and method

The same completed-fitting project/revision database was opened separately
for Master and Slave.  TimeQuest rebuilt a read-only timing netlist at slow
900 mV, 100 C, read the existing SDC, and exported setup paths ending at
`clk_50m` with `-npaths 20 -nworst 20 -detail full_path -show_routing`.

No RTL, C, SDC, QSF, timing constraint, PI/gain/threshold/timeout, detector,
anti-windup, bootstrap, arbiter, mailbox, PHY, reset, compile, programming,
power cycle, or hardware observation was performed.

## WNS reproduction

| Revision | TimeQuest result |
| --- | --- |
| Master `DE5a_wr_master_jtag` | 20 setup paths, 1 violated, WNS `-0.289 ns` |
| Slave `DE5a_wr_slave_jtag` | 20 setup paths, 1 violated, WNS `-0.361 ns` |

Both values exactly match the previously archived `.sta.rpt` summaries, so
the Top-20 path data is from the correct build and timing database.

## Root-cause result for the requested paths

Each image has exactly one negative `clk_50m` setup path.  Both are the
receive-clock-to-observer crossing:

```text
u_wr_arria10_transceiver/.../rx_clkout
    → rx_activity_toggle
    → rx_activity_meta (clk_50m)
```

Master:

```text
From              = rx_activity_toggle
To                = rx_activity_meta
Data arrival      = 24.259 ns
Data required     = 23.970 ns
Clock skew        = -3.871 ns
Data delay        = 0.603 ns
Slack             = -0.289 ns
```

Slave:

```text
From              = rx_activity_toggle
To                = rx_activity_meta
Data arrival      = 24.185 ns
Data required     = 23.824 ns
Clock skew        = -3.835 ns
Data delay        = 0.528 ns
Slack             = -0.361 ns
```

The top-level source shows that these registers belong to the diagnostic
receive-activity observer.  The synchronized value and counter are exported
through `clock_activity_probe` and the `WR_CLOCK_ACTIVITY_*` JTAG
`altsource_probe`; they do not drive the WR core, SI5340 controller, CPU,
SoftPLL, reset, or control branch.  The negative path ownership is therefore
`DIAGNOSTIC_OBSERVABILITY` for this corner, not `PRODUCTION_PATH`.

The complete cell and routing path is preserved in:

- `raw/pain-sta-top20/master_clk50_setup_violations_full.rpt`
- `raw/pain-sta-top20/slave_clk50_setup_violations_full.rpt`

The complete Top-20 exports and TimeQuest logs are preserved beside them.
See `analysis/path_ownership.md` for the source-cone correlation and exact
endpoint details.

Raw artifact SHA256:

```text
6C38A1698518498E6FBACABBD94E4DC947A832CA9B7337E944C90C470616553D  master_clk50_setup_top20_full.rpt
713FAA31E3D0F7DE75066466BCE66BBF6780C399AA1C1D99A95E3E8DCA9D3447  master_clk50_setup_violations_full.rpt
AC016234F82777736B25D7A014901AD6E77C0763F8DD0AC3DF7844E2CC7D1A1E  master.quartus_sta.log
F9B014DCCE09EA0F3FA5D21134E62ABF0980F6FB62AE188827D2F36A5D088245  slave_clk50_setup_top20_full.rpt
D9067CFE3FC4299E766FE0027390F2C2238F7E04A26C6ABBEF856274467A733C  slave_clk50_setup_violations_full.rpt
1461295AB487C4A2F9A0518B8BB995FF2864473AC10E1C8864ABDE562A6CDF3D  slave.quartus_sta.log
```

## Remaining timing status

This result resolves ownership only for the negative `clk_50m` paths at the
100 C slow corner.  It does not close timing.  The earlier artifact audit
still shows negative paths at the 0 C slow corner, including `clk_50m` and
`qsfp_ref_125m`, as well as unconstrained clocks and TimeQuest clock
assignment warnings.  All PVT setup/hold/recovery/removal and unconstrained
path categories remain outside this export.

Accordingly, no timing fix is applied in this experiment.  The experiment
stops here as required after the actual Master/Slave Top-20 path export.
