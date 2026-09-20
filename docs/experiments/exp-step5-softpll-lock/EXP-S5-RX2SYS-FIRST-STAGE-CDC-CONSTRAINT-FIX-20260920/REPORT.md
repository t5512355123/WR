# EXP-S5-RX2SYS-FIRST-STAGE-CDC-CONSTRAINT-FIX-20260920

日期：2026-09-20  
分支：`exp/step5-softpll-lock`

## 實驗目的

依 adviser 指定，僅對 WR RX/PMA clock 到標準 synchronizer 第一級 `sync0` 加入窄範圍 asynchronous timing exception，確認：

1. `gc_sync` / `gc_sync_register` 的第一級負 hold path 是否消失。
2. `sync0 → sync1` 是否仍然被正常 timing。
3. protocolled multibit crossing 是否仍然被 timing。

本輪沒有修改 RTL、QSF、PI、gain、threshold、timeout、控制流程，也沒有 program FPGA、reset 或 power-cycle。

## 版本與變更邊界

clean compile 使用的 production design 內容為 `be7d196e510f122e2b8b1a8360a1f7820b8814e1`：

- 只新增兩份 SDC 的窄範圍 exception：
  - `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc`
  - `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc`
- launch clocks：`rx_clkout`、`rx_pma_clk`
- destination：`gc_sync:*|sync0*`、`gc_sync_register:*|sync0*`
- `sync1`、protocolled multibit、整個 RX/SYS domain、clock groups 均未加入 exception。
- 前一輪 RX_CAL_STAT RTL 修正 `e4c788bdc5e85964857d0504e91545b8cc15fd30` 保留。
- RTL、QSF 與 production control diff 均未變更。

後續 `14f4833d`、`0df79f5a`、`437e0d86`、`06fd9c15` 僅修正/增加離線觀測腳本，不改 design source；因此不重新編譯也不影響已完成的 build。

## Laptop gate 與 Pain preflight

Laptop source gate：`FIRST_STAGE_CDC_CONSTRAINT_IMPLEMENTATION=PASS`。

Master/Slave 的 SDC preflight 均通過：

```text
WR_RX_CLKOUT_COLLECTION=1
WR_RX_PMA_CLK_COLLECTION=1
WR_RX_SYNC0_COLLECTION=1019
FIRST_STAGE_SDC_PREFLIGHT=PASS
```

沒有發現 ignored `set_false_path` 或空 collection。

## Clean compile

| image | clean | compile | errors | warnings |
|---|---|---|---:|---:|
| Master | PASS | PASS | 0 | 299 |
| Slave | PASS | PASS | 0 | 300 |

## Fast 900 mV / 100 C RX→SYS 結果

Fresh fitted STA 的 negative hold paths 分類如下：

| image | total negative | WNS (ns) | first-stage timed-negative | protocolled multibit | other/unclassified |
|---|---:|---:|---:|---:|---:|
| Master | 35 | -0.427 | 3 | 32 | 0 |
| Slave | 35 | -0.456 | 1 | 34 | 0 |

本輪 exception 確實移除了大部分先前的第一級 path，但剩餘 `gc_sync_ffs` 第一級仍被 timing。剩餘 path 為：

### Master

```text
-0.285  xwb_clock_monitor ... gc_sync_ffs:\gen2:3:U_Edge_Detect|sync0
-0.178  ep_rx_path ... gc_sync_ffs:\gen_with_match_buff:U_Sync_Rst_match_buff|sync0
-0.096  ep_rx_pcs_8bit ... gc_sync_ffs:U_sync_an_rx_ready|sync0
```

### Slave

```text
-0.035  xwb_clock_monitor ... gc_sync_ffs:\gen2:3:U_Edge_Detect|sync0
```

這些 `gc_sync_ffs` wrapper 的 source implementation 內部仍使用兩級 `gc_sync`，因此依 CDC intent 應歸類為 first-stage synchronizer；本輪沒有把它們擴大納入 exception。

## Scope guard：後段 timing 保留

所有代表性 `sync0 → sync1` setup/hold path 都找到，且均為非負 slack：

| family | count (Master/Slave) | Master setup / hold (ns) | Slave setup / hold (ns) |
|---|---:|---:|---:|
| RX_CAL_STAT | 1 / 1 | +15.522 / +0.134 | +15.704 / +0.028 |
| DMTD native edge | 64 / 64 | +15.124 / +0.023 | +15.200 / +0.020 |
| async FIFO Gray | 15 / 15 | +7.074 / +0.150 | +7.347 / +0.132 |
| pulse synchronizer | 3 / 3 | +15.541 / +0.027 | +15.506 / +0.026 |
| bitslide | 4 / 4 | +15.385 / +0.022 | +15.342 / +0.021 |

因此：

```text
SYNC0_TO_SYNC1_TIMED = PASS
```

protocolled multibit guard 也仍然存在：

```text
Master lcr_final_val collection = 17
Master rx_config_reg collection = 15
Master LCR→RX_CONFIG setup / hold = +4.409 / -0.427 ns

Slave lcr_final_val collection = 19
Slave rx_config_reg collection = 15
Slave LCR→RX_CONFIG setup / hold = +4.668 / -0.453 ns
```

所以本輪沒有把 protocolled multibit crossing 遮掉。

## All-corner STA

以下是每個 corner 的 global worst setup/hold/recovery/removal report：

| image | corner | setup | hold | recovery | removal |
|---|---|---:|---:|---:|---:|
| Master | Slow 900 mV / 100 C | +0.111 | +0.035 | +0.639 | +0.311 |
| Master | Slow 900 mV / 0 C | -0.320 | +0.033 | +1.203 | -0.148 |
| Master | Fast 900 mV / 100 C | +0.386 | -0.427 | +1.263 | +0.212 |
| Master | Fast 900 mV / 0 C | +1.666 | +0.010 | +3.034 | +0.187 |
| Slave | Slow 900 mV / 100 C | +0.220 | +0.035 | +0.421 | +0.154 |
| Slave | Slow 900 mV / 0 C | -0.191 | +0.035 | +0.925 | -0.299 |
| Slave | Fast 900 mV / 100 C | +0.638 | -0.456 | +1.257 | +0.179 |
| Slave | Fast 900 mV / 0 C | +1.732 | +0.010 | +3.009 | +0.149 |

All four corners completed successfully for both images. Unconstrained summaries were identical across corners:

| image | clocks | input ports / paths | output ports / paths |
|---|---:|---:|---:|
| Master | 6 | 13 / 1828 | 18 / 83 |
| Slave | 6 | 13 / 2627 | 18 / 83 |

`wr_core_dmtd_62m496` generated-clock target collection remained `0` in all corners. The corresponding existing TimeQuest warning was preserved and not changed in this experiment.

## Verdict

```text
MASTER_SDC_PREFLIGHT                 = PASS
SLAVE_SDC_PREFLIGHT                  = PASS
MASTER_CLEAN_COMPILE                 = PASS
SLAVE_CLEAN_COMPILE                  = PASS
SYNC0_TO_SYNC1_TIMED                 = PASS
PROTOCOLLED_MULTIBIT_STILL_TIMED     = PASS
UNSAFE_OR_UNRESOLVED_CDC             = 0
UNCLASSIFIED_CDC                     = 0

MASTER_FIRST_STAGE_TIMED_NEGATIVE    = 3
SLAVE_FIRST_STAGE_TIMED_NEGATIVE     = 1
FIRST_STAGE_CDC_FALSE_PATH_EFFECT    = FAIL (acceptance requires zero)
RX2SYS_FIRST_STAGE_BOUNDARY          = OPEN
RX2SYS_PROTOCOLLED_MULTIBIT          = OPEN
FULL_TIMING_CLOSED                   = NO
STEP5                                = NO
FPGA_PROGRAMMING                    = NOT_PERFORMED
```

結論：本輪的 exception scope 是窄且有效的，並保留了後段 synchronizer 與 protocolled multibit timing；但因 `gc_sync_ffs` 第一級負 hold 仍存在，不能宣告 adviser 要求的 `CDC_FIRST_STAGE_TIMED_NEGATIVE=0`，因此本輪不算完整 PASS。

## 停止狀態

依停止條件，本輪到此停止：

- 不加入第二組 wildcard。
- 不修改 `gc_sync_ffs`、RTL、PI、gain 或 fitter。
- 不 program FPGA、不 reset、不 power-cycle。
- 等待下一個 adviser 回覆後再決定下一輪唯一 action。

Raw evidence 共 108 個檔案、約 27,153,594 bytes；本機 SHA-256 manifest 位於 `analysis/raw_sha256.txt`。
