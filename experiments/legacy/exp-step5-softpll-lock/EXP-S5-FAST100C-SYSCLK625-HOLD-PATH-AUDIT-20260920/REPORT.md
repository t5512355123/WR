# EXP-S5-FAST100C-SYSCLK625-HOLD-PATH-AUDIT-20260920

## Verdict

```text
LAPTOP_AUDIT_SOURCE_TEST                  = PASS
PAIN_PULL                                  = PASS
QUARTUS_VERSION                            = 17.0.0 Build 595
FAST100C_SYSCLK625_HOLD_DB_REPRODUCTION   = PASS
MASTER_SYSCLK625_WNS                       = -0.502 ns
SLAVE_SYSCLK625_WNS                        = -0.486 ns
MASTER_NEGATIVE_PATHS                      = 113
SLAVE_NEGATIVE_PATHS                       = 114
MASTER_HOLD_ROOT_CAUSE                     = MIXED
SLAVE_HOLD_ROOT_CAUSE                      = MIXED
FAST100C_SYSCLK625_HOLD_BOUNDARY           = OPEN
FULL_TIMING_CLOSED                         = NO
FUNCTIONAL_MAIN_PHASE_LOCK_120S            = PASS (prior validated experiment)
FUNCTIONAL_STEP5_LOCK                      = PASS (prior validated experiment)
STEP5                                      = NO
RECOMPILE                                  = NOT_PERFORMED
FPGA_PROGRAMMING                           = NOT_PERFORMED
POWER_CYCLE                                = NOT_PERFORMED
HARDWARE_OBSERVATION                       = NOT_PERFORMED
```

## Scope

This was a read-only TimeQuest path-level audit of the first remaining
timing boundary from the previous fresh build:

```text
Fast 900mV 100C hold
u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk
```

It used the existing fitted databases generated from build commit
`54919aa7b9a4048228d6f121a205898c804e1aee`. The audit source and report
commit is `ac6aa8fd` / `ac6aa8fdae93cdeba63d6e11d73076d58bbd90d2`.

No RTL, C, SDC, QSF, firmware, PI/gain, threshold, timeout, detector,
anti-windup, bootstrap, arbiter, mailbox, PHY, reset, control branch, fitter
setting, FPGA image, or hardware state was changed.

## Reproduction and capture

The audit Tcl reconstructed each existing fitted timing netlist with:

```text
create_timing_netlist -model fast -temperature 100 -voltage 900
read_sdc
update_timing_netlist
```

The exact clock collection resolved once for both images. TimeQuest then
captured, for Master and Slave separately:

- 20 worst hold paths with `-detail full_path -show_routing`;
- up to 20 negative hold paths with the same full-path detail;
- all negative hold paths with `-npaths 0 -detail summary`;
- raw stdout/stderr and the tool version.

The requested baseline values were reproduced exactly:

```text
Master: Found 20 hold paths (20 violated), WNS = -0.502 ns
        all-negative summary: 113 violated paths
Slave:  Found 20 hold paths (20 violated), WNS = -0.486 ns
        all-negative summary: 114 violated paths
```

This satisfies the adviser’s hard reproduction gate. The local checksum
verification of every downloaded raw file also passed:

```text
RAW_CHECKSUM_VERIFY = PASS
```

## Path-level result

The worst paths are both receive-clock to `u_sys_clk_625` hold paths inside
the WR core:

| Image | From family | To family | Slack | Data arrival | Data required | Clock skew | Data delay | Clock uncertainty |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Master | DMTD `dbg_native_edge_count_gray[7]` | DMTD debug synchronizer `sync0[7]` | -0.502 ns | 3.050 ns | 3.552 ns | 0.237 ns | 0.223 ns | 0.260 ns |
| Slave | DMTD `dbg_native_edge_count_gray[55]` | DMTD debug synchronizer `sync0[55]` | -0.486 ns | 3.035 ns | 3.521 ns | 0.231 ns | 0.229 ns | 0.260 ns |

Both worst paths have zero logic levels. The raw full-path report preserves
the exact launch/capture register locations, cell/routing path, and clock
tree details.

The complete Top-20 set is mixed rather than observer-only. Each image has
10 DMTD debug/synchronizer paths and 10 real WR endpoint/packet/timestamp
paths. The first production endpoint path is `-0.457 ns` in Master and
`-0.480 ns` in Slave. See
`analysis/path_ownership.md` for the complete compact slack listing and
family classification; see the raw `*_top20_full.rpt` files for exact node
names and full routing.

## Interpretation

The earlier slow-corner `clk_50m` diagnostic CDC violation was successfully
isolated in the preceding experiment. This new hold boundary is different:
the negative paths are dominated by the receive-clock to system-PLL-clock
relationship and include both internal DMTD debug synchronizers and actual
WR endpoint datapaths. It is therefore not valid to close this boundary by
adding an observer-only exception.

This experiment does not select a fix. In particular, it does not authorize
false paths, minimum-delay constraints, multicycle constraints, delay
insertion, RTL edits, or fitter changes. The hold boundary remains open.

## Evidence

```text
raw/master/master_sysclk625_hold_top20_full.rpt
raw/master/master_sysclk625_hold_violations_full.rpt
raw/master/master_sysclk625_hold_all_violations_summary.rpt
raw/slave/slave_sysclk625_hold_top20_full.rpt
raw/slave/slave_sysclk625_hold_violations_full.rpt
raw/slave/slave_sysclk625_hold_all_violations_summary.rpt
raw/master_quartus_sta.log
raw/slave_quartus_sta.log
raw/pain-context.txt
raw/artifact-sha256.txt
```

## Final stop

The adviser’s stop condition is satisfied for both Master and Slave:

```text
WNS reproduction PASS
Top-20 full-path captured
all-negative summary captured
ownership classified
```

Stop this experiment here. Overall Step5 remains `NO` because complete
timing closure is not achieved; the next action must be selected from this
mixed production/DMTD hold evidence, not improvised in this experiment.

## Supplemental pre-pull archive

The Pain home-directory archive audit recovered an additional historical
`raw/pre-pull-raw-20260920/file-sha256.txt`. It is retained separately from
this audit's canonical `raw/artifact-sha256.txt`; it does not replace any
captured evidence, change the path classification, or alter this report's
verdict.
