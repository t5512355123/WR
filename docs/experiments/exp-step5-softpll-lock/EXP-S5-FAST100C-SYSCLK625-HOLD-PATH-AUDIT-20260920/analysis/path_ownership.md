# Fast 900mV/100C `u_sys_clk_625` hold path ownership

## Reproduction

The audit reconstructed the existing fitted Master and Slave timing
databases with Quartus Prime 17.0.0 Build 595. The clock collection resolved
exactly once in both images:

```text
SYSCLK625_COLLECTION_COUNT(master) = 1
SYSCLK625_COLLECTION_COUNT(slave)  = 1
```

The requested WNS values were reproduced exactly:

| Image | Worst hold slack | All-negative paths |
| --- | ---: | ---: |
| Master | -0.502 ns | 113 |
| Slave | -0.486 ns | 114 |

Therefore:

```text
FAST100C_SYSCLK625_HOLD_DB_REPRODUCTION = PASS
```

## Worst path fields

| Image | From | To | Launch clock | Latch clock | Arrival | Required | Slack | Clock skew | Data delay | Uncertainty |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Master | `...DMTD_REF|dbg_native_edge_count_gray[7]` | `...gc_sync_register:U_sync_dbg_native_edge_count|sync0[7]` | `...xcvr_native_a10_0|rx_clkout` | `u_sys_clk_625...wire_generic_pll1_outclk` | 3.050 ns | 3.552 ns | -0.502 ns | 0.237 ns | 0.223 ns | 0.260 ns |
| Slave | `...DMTD_REF|dbg_native_edge_count_gray[55]` | `...gc_sync_register:U_sync_dbg_native_edge_count|sync0[55]` | `...xcvr_native_a10_0|rx_clkout` | `u_sys_clk_625...wire_generic_pll1_outclk` | 3.035 ns | 3.521 ns | -0.486 ns | 0.231 ns | 0.229 ns | 0.260 ns |

The worst Master launch/capture registers are `FF_X190_Y31_N28` to
`FF_X191_Y31_N29`. The worst Slave launch/capture registers are
`FF_X195_Y25_N56` to `FF_X195_Y25_N50`. Both worst paths have zero logic
levels; the violation is dominated by the short data path and the
launch/capture timing relationship, not by a long combinational cone.

The full routing and cell details are retained in the raw violation reports.

## Top-20 ownership

Each image has 20 negative paths in the requested Top-20 report. The family
split is identical:

| Image | DMTD debug/synchronizer family | WR endpoint/packet/timestamp production family | Other |
| --- | ---: | ---: | ---: |
| Master | 10 | 10 | 0 |
| Slave | 10 | 10 | 0 |

The DMTD family is identified by the `dbg_native_edge_count_gray` to
`U_sync_dbg_native_edge_count` cone. It is an internal diagnostic/debug
publication path in the WR SoftPLL/DMTD structure, not the F4L/JTAG
observer added by the Step5 experiment.

The production family contains actual WR endpoint logic, including:

- `ep_1000basex_pcs` / autonegotiation;
- `ep_rx_path` clock-alignment FIFO synchronizers;
- packet-filter data paths;
- the endpoint timestamping unit.

The first production-family slack is `-0.457 ns` in Master and `-0.480 ns`
in Slave. Therefore the requested boundary is not observer-only:

```text
MASTER_HOLD_ROOT_CAUSE = MIXED
SLAVE_HOLD_ROOT_CAUSE  = MIXED
FAST100C_SYSCLK625_HOLD_ROOT_CAUSE = MIXED
```

The worst individual path is in the DMTD debug/synchronizer family, but
production WR endpoint paths also occupy the same negative Top-20 set. No
RTL or timing fix is selected from this audit.

## Complete Top-20 slack listing

The exact From/To names and full path details are in the raw reports. The
following compact listing records the complete Top-20 slack sequence and
family classification.

### Master

```text
-0.502 DMTD_DEBUG    -0.486 DMTD_DEBUG    -0.462 DMTD_DEBUG
-0.457 PRODUCTION    -0.444 DMTD_DEBUG    -0.427 DMTD_DEBUG
-0.420 DMTD_DEBUG    -0.420 DMTD_DEBUG    -0.418 DMTD_DEBUG
-0.417 DMTD_DEBUG    -0.416 PRODUCTION    -0.411 PRODUCTION
-0.411 PRODUCTION    -0.407 PRODUCTION    -0.405 PRODUCTION
-0.401 PRODUCTION    -0.388 PRODUCTION    -0.369 PRODUCTION
-0.368 PRODUCTION    -0.364 DMTD_DEBUG
```

### Slave

```text
-0.486 DMTD_DEBUG    -0.480 PRODUCTION    -0.480 DMTD_DEBUG
-0.476 DMTD_DEBUG    -0.473 DMTD_DEBUG    -0.473 DMTD_DEBUG
-0.472 PRODUCTION    -0.471 DMTD_DEBUG    -0.463 PRODUCTION
-0.457 DMTD_DEBUG    -0.455 DMTD_DEBUG    -0.454 PRODUCTION
-0.452 PRODUCTION    -0.449 PRODUCTION    -0.448 DMTD_DEBUG
-0.448 DMTD_DEBUG    -0.447 PRODUCTION    -0.447 PRODUCTION
-0.443 PRODUCTION    -0.440 PRODUCTION
```

