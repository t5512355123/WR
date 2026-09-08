# EXP-WRPC-STEP5-I2C-PROVENANCE-128-FINC-20260908

## 結論

本輪依照 `Astra建議.md`，在不改變 PI、Helper lock detector、bootstrap
方向或 runtime admission 的前提下，加入獨立的唯讀 probe 50，觀察 DCO
runtime transaction provenance 與 I2C sticky ACK error。

結果排除了「runtime 完全沒有送出」以及「I2C ACK 全部失敗」這兩個候選
解釋，但沒有達成 Step5：

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (settled preflight 3/4)
STEP4B = PASS (settled preflight 3/4)
STEP5 = NOT_PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

本輪仍未證明每一筆 I2C write 在 SI5340 silicon 內命中正確的 page/register；
probe 50 是 FPGA-side admission/provenance 證據，不是 I2C wire capture 或
register readback。

## 版本與變更

- Branch：`exp/step5-softpll-lock`
- Source commit：`1d88738ecd98d2688709af76e06907d5e43a3627`
- 基準設定：Slave `STEP5_BOOTSTRAP_STEPS=128`
- `STEP5_BOOTSTRAP_REVERSE=1`（FINC）
- `ENABLE_NORMAL_HPLL_TRACKER=0`
- `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP=16`
- 新增 `oDCO_STEP5_I2C_DEBUG` 與 JTAG probe 50
- 接出既有 I2C controller 的 sticky `oACK_ERROR`
- 保存最後一次 runtime command，以及四個 runtime phase 是否曾被 admission
- 未修改 PI、lock threshold、reset tree、runtime state transition 或完成條件

probe 50 的欄位如下：

```text
[7:0]   last runtime address
[15:8]  last runtime data
[18:16] last runtime state
[19]    last final-write flag
[20]    last DPLL-select flag
[21]    last direction
[25:22] phase-seen mask: PAGE3 / MASK / PAGE0 / FINC-FDEC
[26]    sticky I2C ACK error
[27]    existing dco_error
[35:28] runtime_start_count (8-bit, modulo 256)
[43:36] bus_done_count (8-bit, modulo 256)
[59:44] total completed DCO steps
```

## Compile、program 與映像

Pain 以 commit `1d88738` pull 後執行完整 Master／Slave Quartus build，兩者
均成功；沒有使用舊 SOF 代替本輪 source。既有 firmware tree 未變更，故本輪
沿用已存在的 firmware image。

```text
BUILD_MASTER_RC = 0
BUILD_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
RECOVERY_MASTER_RC = 0
RECOVERY_SLAVE_RC = 0
```

SOF SHA-256：

```text
Master 2b2bed09353da4db40f1f12c8c7bde739412c0b9fb108eb5a97a5dbdca5260de
Slave  cbae4fda39779bd9ae5ff2ed4a9a8a419d3d67a1824f33abbdcb278e0eb2ab95
```

兩個 full Quartus build 都標示 `timing_closed=NO`；本輪先保留此
implementation caveat，沒有把它當成 Step5 失敗的唯一原因。

## Upstream preflight

初次 program 後的 preflight 1/2 均完成，但 Slave upstream 尚未 ready，
`STEP4B=BLOCKED_BY_STEP2`。依既定 recovery procedure 以相同 SOF 執行
Master → 等待 45 秒 → Slave 後，preflight 3/4 均成為可信 settled window：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

因此 Step5 判定只使用 preflight 3/4 與後續 observer，不使用前兩個 transient
窗口。

## 120 秒 Step5 observer

觀測使用 1200 samples、100 ms cadence，實際窗口 `119.901 s`，全部 mailbox
frame 有效：

```text
SAMPLES = 1200
VALID_FRAMES = 1200
INVALID_FRAMES = 0
WINDOW_SECONDS = 119.901
HELPER_LOCK_COUNT_MAX = 5610
HELPER_LOCK_COUNT_FINAL = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_SAMPLES = 1200
HELPER_ERROR_MEAN = -145890.0975
HELPER_ERROR_RMS = 155675.003566
HELPER_ERROR_MAX_ABS = 796896
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 0.0
HELPER_OUTPUT_FINAL_SIGNED = 65531
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
SPLL_DELOCK_COUNT_MAX = 56
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 128
BOOTSTRAP_DONE_FINAL = 1
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS
```

Helper 在整個有效窗口沒有進入 locked，error 仍大幅偏離 `±200` threshold，
因此 Step5 的第一個可靠失敗邊界仍為 `HELPER_LOCK`。Main 沒有啟用不是新的
失敗原因，而是既有 sequencer gate 的結果。

## Runtime provenance 結果

觀測第一筆與最後一筆的 probe 50 都一致：

```text
I2C_LAST_ADDR = 29 = 0x1D
I2C_LAST_DATA = 1  = 0x01
I2C_LAST_STATE = 5
I2C_LAST_FINAL_WRITE = 1
I2C_LAST_DPLL_SELECT = 0
I2C_LAST_DIR = 1
I2C_PHASE_SEEN = 15 = PAGE3 | MASK | PAGE0 | FINC-FDEC
I2C_ACK_ERROR = 0
I2C_DCO_ERROR = 0
I2C_DCO_STEPS = 128
```

依目前 source 定義，最後一筆代表 page 0 上的 FINC command；phase mask
顯示同一 reset generation 曾走過四個 runtime phase，且 128 個 bootstrap
physical completions 已完成。這足以排除「FSM 從未走到 runtime final command」
與「sticky ACK error 已被觀測到」；它不能單獨證明前面三筆的 wire data，也
不能證明 SI5340 的 N divider 實際改變。

`I2C_RUNTIME_STARTS_FINAL=0` 是 8-bit counter 在 128-step、每 step 四筆
transaction 後的 modulo-256 結果，不可解讀為零次 runtime start。現有
`I2C_BUS_COMPLETIONS_FINAL=117` 同樣不是本輪 Step5 判定依據；完整完成證據
採用既有 `BOOTSTRAP_COMPLETED=128`、`FORCED_COMPLETED=128` 與
`DCO_STEP=128`，避免把不同 clock-domain 的 `bus_done` edge counter 當成
I2C transaction wire count。

## 判斷與下一步

本輪的因果資訊是：

```text
runtime phase admission = observed
last final FINC command = observed
sticky ACK error = 0
Helper lock = never observed
```

所以目前最有力的結論不是再調 `kp`，而是把 provenance 從「最後一筆」補成
「四筆各自的 address/data/phase snapshot」，或加入受控 readback／外部 I2C
capture，確認 page 3 的 mask write 與 page 0 的 final command 在同一條實際
transaction sequence 中成立。完成這層證據前，不應宣稱 N0/N1 已物理隔離，
也不應把 Step5 標成 PASS。

若四筆 payload 與 ACK 均正確而 Helper 仍停在 rail，下一輪才進入 Astra 路線
的 A3：修正 Main absolute target/applied position contract，讓 code 差值
能轉成可追蹤的多個 physical steps；PI 增益維持不變，並以短窗口重新量測
operating-point bracket。

完整 raw archive：

```text
raw/EXP-WRPC-STEP5-I2C-PROVENANCE-128-FINC-20260908.tar.gz
SHA256 2c9191385e9fba27bb570463d48d30c9902519c41e2223302f7c1b6bf87f035f
```

## 正式狀態

```text
STEP4B = PASS (settled recovery window)
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```
