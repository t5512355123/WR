# RX-to-SYS CDC intent classification

## Input and method

The classification input is the complete TimeQuest `-hold` report for the
Fast 900 mV/100 C corner, terminating at:

```text
u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk
```

Each summary row beginning with a negative slack was counted once.  Rows were
grouped only after counting by exact source/destination family; the raw full
path reports remain the authoritative per-bit evidence.

The common latch clock for every row is the clock above.  The launch clock is
`u_wr_arria10_transceiver|...|xcvr_native_a10_0|rx_clkout`, except for the
bitslide family, which launches from `...|xcvr_native_a10_0|rx_pma_clk`.

## Classification totals

| CDC intent | Master | Slave | Master worst slack | Slave worst slack |
| --- | ---: | ---: | ---: | ---: |
| `CDC_FIRST_STAGE` | 78 | 79 | -0.502 ns | -0.486 ns |
| `CDC_PROTOCOLLED_MULTIBIT` | 35 | 34 | -0.457 ns | -0.480 ns |
| `TRUE_SYNCHRONOUS` | 0 | 0 | n/a | n/a |
| `UNSAFE_OR_UNRESOLVED_CDC` | 0 | 1 | n/a | -0.081 ns |
| **Total negative paths** | **113** | **114** | **-0.502 ns** | **-0.486 ns** |

```text
MASTER_UNCLASSIFIED_PATH_COUNT = 0
SLAVE_UNCLASSIFIED_PATH_COUNT  = 0
CDC_INTENT_AUDIT               = COMPLETE_WITH_ONE_UNSAFE_SLAVE_CDC
```

## `CDC_FIRST_STAGE` families

| From family | To family | Master count / worst | Slave count / worst | Source justification |
| --- | --- | ---: | ---: | --- |
| DMTD `dbg_native_edge_count_gray[*]` | `gc_sync_register:U_sync_dbg_native_edge_count|sync0[*]` | 63 / -0.502 ns | 61 / -0.486 ns | `dmtd_with_deglitcher.vhd:329-349` registers a Gray counter in the DMTD clock domain and feeds a `gc_sync_register`; `gc_sync_register.vhd:60-74` has `async_reg` `sync0/sync1` and the two-stage assignment. Diagnostic ownership does not change the CDC intent. |
| Async FIFO `wcb.gray[*]` | `gc_sync_register:U_Sync2|sync0[*]` | 7 / -0.416 ns | 8 / -0.463 ns | `inferred_async_fifo_dual_rst.vhd:166-214` updates the write/read Gray pointers in separate clocks and sends the opposite pointer through `U_Sync1/U_Sync2` `gc_sync_register` instances. |
| `gc_pulse_synchronizer2:U_Sync_Done|in_ext` | `gc_sync:cmp_in2out_sync|sync0` | 1 / -0.388 ns | 1 / -0.376 ns | `ep_packet_filter.vhd:346-392` generates the RX-domain completion event and crosses it through `U_Sync_Done`; `gc_pulse_synchronizer2.vhd` implements the input-to-output and feedback synchronizer chains with `gc_sync`. |
| Timestamp RX calibration result | `gc_sync:inst_sync_rx_cal_result|sync0` | 1 / -0.369 ns | 1 / -0.214 ns | `ep_timestamping_unit.vhd:226-246` produces the result in the RX clock domain, and the receiving `gc_sync` instance is the destination first stage. |
| PHY bitslide `pld_8g_wa_boundary_reg.reg` | `gc_sync_register:U_sync_bslide|sync0[*]` | 4 / -0.226 ns | 3 / -0.239 ns | `ep_1000basex_pcs.vhd:640-648` explicitly crosses the recovered-PMA bitslide bus with a 5-bit `gc_sync_register`. |
| Clock monitor `clks[3].clk_presc` | `gc_sync_ffs:U_Edge_Detect|sync0` | 1 / -0.282 ns | 1 / -0.145 ns | `wrc_core.vhd:1155-1173` assigns `freqmon_in(3)` to `phy_rx_clk`; `xwb_clock_monitor.vhd:171-194` creates the source prescaler and uses `gc_sync_ffs` in `clk_sys_i`. |
| RX reset status | `ep_rx_path:U_Sync_Rst_match_buff|sync0` | 1 / -0.161 ns | 1 / -0.217 ns | `wrc_core.vhd:614-620` creates the RX-clock reset status, and `ep_rx_path.vhd:227-232` synchronizes it into `clk_sys_i` with `gc_sync_ffs`. |
| PHY ready status | `U_Sync_phy_rdy_sysclk|sync0` | 0 | 2 / -0.338 ns | `wr_endpoint.vhd:488-496` uses a `gc_sync_ffs` in the system-clock domain; its source is the PHY ready status, itself synchronized in the PHY RX clock by `wr_arria10_phy.vhd:805-813`. |
| PCS `synced_o` / loss-of-sync status | `U_sync_los|sync0` | 0 | 1 / -0.034 ns | `ep_rx_pcs_8bit.vhd:286-294` feeds the RX-domain PCS synchronization result into a system-clock `gc_sync_ffs`. |
| PCS `an_idle_match_int` | `U_sync_an_idle_match|sync0` | 0 | 1 / -0.029 ns | `ep_rx_pcs_8bit.vhd:824-832` explicitly synchronizes the RX-domain idle-match status into `clk_sys_i`. |

These 78 Master and 79 Slave rows all terminate at a proven first
metastability register (`sync0`) with a second stage in the same source
primitive.  They are not ordinary same-clock hold paths.

## `CDC_PROTOCOLLED_MULTIBIT` families

| From family | To family | Master count / worst | Slave count / worst | Source justification |
| --- | --- | ---: | ---: | --- |
| `lcr_final_val[*]` | `ep_autonegotiation.rx_config_reg[*]` | 15 / -0.457 ns | 15 / -0.452 ns | `ep_rx_pcs_8bit.vhd:637-645` updates `lcr_final_val` only after repeated identical configuration words and holds it; `:796-822` synchronizes `lcr_ready` as `an_rx_valid_o`. `ep_autonegotiation.vhd:159-227` samples the bus under the synchronized valid/ability protocol. |
| `lcr_final_val[*]` | `mdio_lpa_*` outputs | 8 / -0.368 ns | 8 / -0.443 ns | Same stable `lcr_final_val` plus synchronized `an_rx_valid`; `ep_autonegotiation.vhd:243-248` captures the fields only in the system-clock FSM after the protocol has qualified the value. |
| `lcr_final_val[*]` | autonegotiation state / `link_timer_restart` | 3 / -0.174 ns | 2 / -0.152 ns | These are additional cones of `an_rx_val_i` in the same FSM.  The source contract is the same stable LCR bus plus `an_rx_valid_i`; they are not independent unsynchronized data transfers. |
| Packet-filter `pclass_int[*]` | `pclass_o[*]` | 8 / -0.401 ns | 8 / -0.480 ns | `ep_packet_filter.vhd:346-365` latches the RX result and holds it; `:367-379` samples it in `clk_sys_i` only when `done_int_sys` is asserted. `:384-392` transfers that completion event with `gc_pulse_synchronizer2`. |
| Packet-filter `drop_int` | `drop_o` | 1 / -0.324 ns | 1 / -0.405 ns | Same stable-result-plus-synchronized-completion protocol as `pclass_int`. |

These 35 Master and 34 Slave rows have a source-level data-stability and
event-qualification protocol.  They are not automatically eligible for a
timing exception; their CDC protocol must be handled separately from a
first-stage synchronizer.

## `UNSAFE_OR_UNRESOLVED_CDC`

| Image | From | To | Count / worst | Evidence |
| --- | --- | ---: | ---: | --- |
| Slave | `ep_rx_pcs_8bit:mdio_wr_spec_rx_cal_stat_o` | `ep_mdio_regs:wb_o.dat[1]` | 1 / -0.081 ns | `ep_rx_pcs_8bit.vhd:309-337` drives the status bit in `phy_rx_clk_i`; `ep_1000basex_pcs.vhd:393-410` wires it directly into `mdio_regs_in`; `ep_mdio_regs.vhd:361-478` places it directly in the system-clock Wishbone read data. No synchronizer, async FIFO, handshake, or stable-bus capture is present on this path. |

This is a real CDC correctness candidate, not a reason to add a timing
exception.  It is recorded only; this experiment makes no RTL change.

## `TRUE_SYNCHRONOUS`

No negative path was classified as `TRUE_SYNCHRONOUS`.  The launch domains are
the recovered RX/PMA clocks and the latch domain is the local system PLL clock;
the timing report shows a zero clock relationship for this RX-to-SYS query,
and the source evidence provides CDC primitives or a protocol for every path
except the one unresolved Slave status bit above.

## Audit conclusion

All 227 negative paths are accounted for with source evidence.  The audit is
complete, but timing closure is not:

```text
CDC_FIRST_STAGE              = 157 paths
CDC_PROTOCOLLED_MULTIBIT     = 69 paths
UNSAFE_OR_UNRESOLVED_CDC     = 1 path
TRUE_SYNCHRONOUS              = 0 paths
UNCLASSIFIED                  = 0 paths
```

No `set_false_path`, `set_clock_groups`, min/max-delay, multicycle,
synchronizer, delay-chain, RTL, QSF, SDC, or fitter change was made.
