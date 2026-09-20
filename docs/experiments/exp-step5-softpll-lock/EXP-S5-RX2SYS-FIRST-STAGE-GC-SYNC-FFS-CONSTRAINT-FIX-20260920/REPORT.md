# EXP-S5-RX2SYS-FIRST-STAGE-GC-SYNC-FFS-CONSTRAINT-FIX-20260920

## 結論

本輪指定的 RX/PMA → WR synchronizer `sync0` constraint scope 已完成驗證。

```text
GC_SYNC_FFS_SDC_PREFLIGHT             = PASS
RX2SYS_FIRST_STAGE_CDC_CONSTRAINT     = PASS
RX2SYS_FIRST_STAGE_BOUNDARY           = CLOSED
GC_SYNC_FFS_SYNC0_TO_SYNC1_TIMED      = PASS
PROTOCOLLED_MULTIBIT_STILL_TIMED      = PASS
UNSAFE_OR_UNRESOLVED_CDC              = 0
UNCLASSIFIED_CDC                      = 0

FAST100C_SYSCLK625_HOLD_BOUNDARY      = OPEN
FULL_TIMING_CLOSED                    = NO
STEP5                                 = NO
```

這不是 Step5 functional lock 或整體 timing closure。它只證明：新增的
`gc_sync_ffs:*|sync0*` first-stage exception 補到了上一輪遺漏的 wrapper hierarchy，且沒有把 `sync0 → sync1` 或 protocolled multibit path 一起切掉。

## 實驗身份

| 欄位 | 值 |
|---|---|
| Date | 2026-09-20 |
| Branch | `exp/step5-softpll-lock` |
| Laptop source commit | `a2c2c8058e90778c7b504c3b9ca7d9098be026e6` |
| Commit message | `exp: add gc_sync_ffs first-stage CDC scope` |
| Quartus | Prime 17.0 Build 595 |
| Pain worktree | `/home/b10504072/pain-worktrees/EXP-S5-MAIN-PHASE-KI0-MECHANISM-20260919` |
| Hardware action | No FPGA programming, reset, or power-cycle |
| Raw archive | 86 files; SHA-256 `10d0e77cab1df880e528428a36642a3c7afc82df181735511e9d8b3cfa5b5731` |

## 唯一 production 變更

Master 與 Slave 的 SDC 都只把既有 first-stage destination collection 從：

```tcl
{*|gc_sync:*|sync0*}
{*|gc_sync_register:*|sync0*}
```

補成：

```tcl
{*|gc_sync:*|sync0*}
{*|gc_sync_register:*|sync0*}
{*|gc_sync_ffs:*|sync0*}
```

修改檔案：

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc`

本輪沒有修改 RTL、QSF、SoftPLL、PI、Kp/Ki、threshold、timeout、控制分支或硬體映像內容；沒有新增 clock group、sync1 exception、protocolled multibit exception、min/max delay 或 multicycle constraint。

## Laptop source gate

離線 source test 結果：

```text
MASTER_GC_SYNC_FFS_COLLECTION=1
SLAVE_GC_SYNC_FFS_COLLECTION=1
MASTER_FALSE_PATH_COUNT=1
SLAVE_FALSE_PATH_COUNT=1
MASTER_NO_SYNC1_DESTINATION=1
SLAVE_NO_SYNC1_DESTINATION=1
MASTER_NO_PROTOCOLLED_DESTINATION=1
SLAVE_NO_PROTOCOLLED_DESTINATION=1
MASTER_NO_CLOCK_GROUP=1
SLAVE_NO_CLOCK_GROUP=1
RTL_UNCHANGED=1
QSF_UNCHANGED=1
GC_SYNC_FFS_FIRST_STAGE_CONSTRAINT_IMPLEMENTATION=PASS
```

`MASTER_FALSE_PATH_COUNT=1` / `SLAVE_FALSE_PATH_COUNT=1` 表示各自保留一個 first-stage constraint block；每個 block 內只有既有兩個 launch-clock-to-sync0 `set_false_path` 命令。

## Pain preflight：既有 fitted DB

在 clean compile 前，先用既有 fitted database 解析新 SDC 並重新查詢 Fast 900 mV / 100 C RX→SYS hold。

| 項目 | Master | Slave |
|---|---:|---:|
| `WR_RX_CLKOUT_COLLECTION` | 1 | 1 |
| `WR_RX_PMA_CLK_COLLECTION` | 1 | 1 |
| `WR_RX_SYNC0_COLLECTION` | 1051 | 1051 |
| `GC_SYNC_FFS_SYNC0_COLLECTION` | 32 | 32 |
| `SYSCLK625_COLLECTION` | 1 | 1 |
| Existing-DB negative WNS | -0.427 ns | -0.456 ns |
| New GC sync0 residual negative paths | 0 | 0 |
| Preflight verdict | PASS | PASS |

Preflight negative reports 中沒有剩餘 `gc_sync_ffs` first-stage path。log 同時保留一個已存在且本輪明確不處理的 `clk_dmtd_62m496` empty generated-clock target warning；這不屬於本輪新增的 GC sync0 constraint，沒有被隱藏或重新分類。

## Clean compile

Master 與 Slave 都先 clean，再以同一 source commit 重新 compile：

| Image | Result | Errors | Warnings |
|---|---|---:|---:|
| Master | Full Compilation successful | 0 | 299 |
| Slave | Full Compilation successful | 0 | 300 |

## Fresh Fast100C RX→SYS negative-path classification

這是 clean compile 後的 Fast 900 mV / 100 C hold audit，不是舊 database 的數字重用。

| 類別 | Master | Slave |
|---|---:|---:|
| Total negative paths | 32 | 34 |
| WNS | -0.414 ns | -0.481 ns |
| First-stage synchronizer negative paths | 0 | 0 |
| Protocolled multibit negative paths | 32 | 34 |
| True synchronous negative paths | 0 | 0 |
| Unsafe or unresolved CDC | 0 | 0 |
| Unclassified paths | 0 | 0 |

Master 的 32/32、Slave 的 34/34 negative rows 都符合已知 protocolled multibit source families（`lcr_final_val`、`pclass_int`、`drop_int`）；fresh full reports 沒有 `gc_sync_ffs`、`gc_sync_register`、`gc_sync:*` 或 `sync0` first-stage destination。

因此，本輪把 first-stage boundary 關閉，但把 protocolled multibit boundary 保持為 OPEN，沒有以 exception 掩蓋它。

## Scope guard：`gc_sync_ffs` 後段仍被 timing

三個 representative wrapper family 都找到 `sync0 → sync1` setup 與 hold path，且 scope audit PASS。

| Role / family | sync0 | sync1 | setup worst slack | hold worst slack |
|---|---:|---:|---:|---:|
| Master / `U_Edge_Detect` | 5 | 5 | +15.367 ns | +0.170 ns |
| Master / `U_Sync_Rst_match_buff` | 1 | 1 | +15.543 ns | +0.166 ns |
| Master / `U_sync_an_rx_ready` | 1 | 1 | +15.694 ns | +0.028 ns |
| Slave / `U_Edge_Detect` | 5 | 5 | +14.464 ns | +0.027 ns |
| Slave / `U_Sync_Rst_match_buff` | 1 | 1 | +15.318 ns | +0.382 ns |
| Slave / `U_sync_an_rx_ready` | 1 | 1 | +15.705 ns | +0.026 ns |

這證明新增 exception 的 destination 停在 first metastability stage；後段 synchronizer timing 仍存在。

## Protocolled multibit scope guard

`lcr_final_val[*] → rx_config_reg[*]` 仍然被 TimeQuest timing：

| Role | LCR collection | RX_CONFIG collection | setup | hold |
|---|---:|---:|---:|---:|
| Master | 19 | 15 | +4.295 ns | -0.414 ns |
| Slave | 20 | 15 | +4.358 ns | -0.431 ns |

因此 `PROTOCOLLED_MULTIBIT_STILL_TIMED=PASS`；其負 hold 沒有被本輪 SDC 修改遮掉。

## All-corner STA summary

每個 corner 都確認 `SYSCLK625_COLLECTION=1`，setup、hold、recovery、removal 與 unconstrained report 均輸出成功；`DMTD_62M496_TARGET=0` 在所有 corner 保持為已知未解決項目。

數值為每個 corner 該 analysis 的 worst slack；括號內是 violated path count。

### Master

| Corner | Setup | Hold | Recovery | Removal |
|---|---:|---:|---:|---:|
| Slow 900 mV / 100 C | +0.292 (0) | +0.041 (0) | +0.372 (0) | +0.286 (0) |
| Slow 900 mV / 0 C | +0.307 (0) | +0.039 (0) | +0.998 (0) | -0.051 (1) |
| Fast 900 mV / 100 C | +0.660 (0) | -0.414 (1) | +1.316 (0) | +0.180 (0) |
| Fast 900 mV / 0 C | +1.718 (0) | +0.014 (0) | +3.046 (0) | +0.159 (0) |

### Slave

| Corner | Setup | Hold | Recovery | Removal |
|---|---:|---:|---:|---:|
| Slow 900 mV / 100 C | -0.323 (1) | +0.037 (0) | +0.402 (0) | +0.287 (0) |
| Slow 900 mV / 0 C | +0.238 (0) | +0.037 (0) | +0.968 (0) | -0.148 (1) |
| Fast 900 mV / 100 C | +0.111 (0) | -0.481 (1) | +1.399 (0) | +0.180 (0) |
| Fast 900 mV / 0 C | +1.732 (0) | +0.011 (0) | +3.036 (0) | +0.154 (0) |

這些仍然開啟的 protocolled multibit、Slow 0 C removal、Slave Slow 100 C setup、Fast 100 C hold、unconstrained clocks 與空的 DMTD generated-clock target，都不是本輪 scope；依 adviser 指示沒有順手修改。

## Raw evidence

本資料夾的 `raw/` 保存：

- Master/Slave clean 與 compile logs
- Existing-DB preflight logs/reports
- Fresh RX→SYS top-20 與 all-negative full reports
- 三組 `gc_sync_ffs` scope guard reports
- `lcr_final_val → rx_config_reg` protocolled guard reports
- 四個 PVT corner 的 setup/hold/recovery/removal/unconstrained reports
- all-corner summary logs

原始資料在 Pain 先封存後以 tar 傳回 Laptop；archive SHA-256 已列於本報告「實驗身份」。

## 停止與後續

本輪已在 all-corner summary 完成後停止，沒有 program FPGA，也沒有進入硬體 Step5 觀測。正式回報 adviser 的狀態應為：

```text
RX2SYS_FIRST_STAGE_BOUNDARY = CLOSED
RX2SYS_PROTOCOLLED_MULTIBIT = OPEN
FAST100C_SYSCLK625_HOLD_BOUNDARY = OPEN
FULL_TIMING_CLOSED = NO
STEP5 = NO
```

下一步不在本輪自行決定；先把本報告與 raw evidence push，請 adviser 依這份新證據指定下一個唯一 timing boundary。
