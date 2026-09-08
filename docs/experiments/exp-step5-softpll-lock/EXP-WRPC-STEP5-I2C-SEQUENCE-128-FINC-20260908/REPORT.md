# EXP-WRPC-STEP5-I2C-SEQUENCE-128-FINC-20260908

## 結論

本輪在前一輪 probe 50 的基礎上新增 probe 51，逐一保存四筆 runtime
transaction 實際送入 FPGA I2C controller 的 address/data。Slave 維持
`STEP5_BOOTSTRAP_STEPS=128`、FINC、normal HPLL tracker 關閉。

四筆 payload 與目前 runtime FSM 預期完全一致：

```text
phase 0: 0x01 = 0x03   PAGE 3
phase 1: 0x39 = 0x0D   N_FSTEP_MSK on page 3, HPLL/N1 selected
phase 2: 0x01 = 0x00   PAGE 0
phase 3: 0x1D = 0x01   FINC
```

同時 `I2C_ACK_ERROR=0`、`DCO_ERROR=0`、`BOOTSTRAP_COMPLETED=128`。這已
排除 FPGA-side runtime sequence 送錯 phase/data，以及 sticky ACK error 的
候選問題；仍不是 SI5340 wire analyzer 或 register readback，故不能單靠此
輪宣稱 silicon N0/N1 isolation 或 Step5 完成。

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

## 版本、編譯與燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`26d4054a60814bb623463c087a3ef915d8450dc6`
- `STEP5_BOOTSTRAP_STEPS=128`
- `STEP5_BOOTSTRAP_REVERSE=1`（FINC）
- `ENABLE_NORMAL_HPLL_TRACKER=0`
- 新增 probe 51，保留 probe 49/50 layout
- 未修改 PI、lock threshold、reset tree、runtime admission 或 completion rule
- 先以 Pain pull 後完整編譯；期間完成一次 Pain 實體斷電重開，再以同一來源
 重新 build/program
- Full Master／Slave Quartus build 均成功，沒有使用舊 SOF 替代本輪 source

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
Master 9972e81af28e8ed318de70b80712c7a4b7047cec85d5cb980682c9f3bc41522c9
Slave  4e246dece931f1e00e7a4b53e0f2107b14fa15a2ea4a7791dd9fb096b4817dbb8
```

兩個 full build 都標示 `timing_closed=NO`；此 implementation caveat 仍保留，
但不把它單獨當成本輪 Step5 failure cause。

## Upstream preflight

初次 program 後 preflight 1/2 重現已知 startup transient，Slave upstream
尚未 ready，Step4B blocked。依既定 recovery procedure 重新以 Master → 45 秒
→ Slave 配置後，preflight 3/4 均通過：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

Step5 判定只使用 settled preflight 3/4 與後續 observer。

## 120 秒 observer

observer 使用 1200 samples、100 ms cadence，實際窗口 `119.900 s`。
本輪 mailbox frame quality 明顯低於上一輪，只有 194 個 valid frames；
因此 error 統計只能作為有效樣本的診斷，不能當成長時間穩定證據。

```text
SAMPLES = 1200
VALID_FRAMES = 194
INVALID_FRAMES = 1006
WINDOW_SECONDS = 119.900
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_SAMPLES = 193
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 0.0
HELPER_OUTPUT_FINAL_SIGNED = 65531
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
SPLL_DELOCK_COUNT_MAX = 0
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

Helper 未在任何 valid sample 進入 locked，且 valid error samples 全部在
負向飽和端；Step5 的第一個可靠失敗邊界仍是 `HELPER_LOCK`。觀測的 invalid
frame 比例本身另列為 diagnostics transport-quality caveat，不把它誤認為
Helper lock failure 的唯一根因。

## Probe 50/51 provenance

probe 50 在第一筆與最後一筆均為：

```text
I2C_LAST_ADDR = 0x1D
I2C_LAST_DATA = 0x01
I2C_LAST_STATE = 5
I2C_LAST_FINAL_WRITE = 1
I2C_LAST_DPLL_SELECT = 0
I2C_LAST_DIR = 1
I2C_PHASE_SEEN = 0xF
I2C_ACK_ERROR = 0
I2C_DCO_ERROR = 0
I2C_DCO_STEPS = 128
```

probe 51 最後 snapshot 的四個 address/data pair：

```text
I2C_SEQ0_ADDR = 0x01    I2C_SEQ0_DATA = 0x03
I2C_SEQ1_ADDR = 0x39    I2C_SEQ1_DATA = 0x0D
I2C_SEQ2_ADDR = 0x01    I2C_SEQ2_DATA = 0x00
I2C_SEQ3_ADDR = 0x1D    I2C_SEQ3_DATA = 0x01
```

這表示 source-defined page/mask/final command sequence 確實被 admission，
且 controller sticky ACK 沒有觀測到 NACK。它仍然是 FPGA-side evidence：
沒有逐筆 SDA/SCL capture、SI5340 silicon readback 或兩路輸出頻率的獨立物理
量測，所以「實際 register 被正確作用」仍保留為未證明。

`I2C_RUNTIME_STARTS_FINAL=0` 是 8-bit counter modulo 256；128 steps ×
4 writes 正好 wrap，不能解讀為沒有 runtime start。`I2C_BUS_COMPLETIONS=117`
是另一個既有 8-bit bus_done edge counter，不用來取代 per-step completion；
完成量採用 `BOOTSTRAP_COMPLETED=128`、`FORCED_COMPLETED=128`、`DCO_STEP=128`。

## Step5 判定與下一步

本輪正式判定：

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

目前已經有相當完整的 FPGA-side transaction 證據，但 Helper 仍停在
`-150000`／output `65531`，因此下一輪不再增加相同類型的 provenance，也不
調 PI。依 `Astra建議.md`，下一步改成 coarse operating-point baseline：

1. 保留四筆 sequence telemetry、ACK telemetry、normal tracker 關閉；
2. 將 `STEP5_BOOTSTRAP_STEPS` 設為 `0`，取得無 bootstrap 的靜態工作點；
3. 比較 Helper error/output 是否仍在同一 rail；
4. 再依單一變因逐步掃描安全的 coarse position，找出進入 lock window 的
   bracket；
5. 只有找到可達工作點後，才進入 Main absolute target/applied contract。

完整 raw archive：

```text
raw/EXP-WRPC-STEP5-I2C-SEQUENCE-128-FINC-20260908.tar.gz
SHA256 53b74ebdad54915f52923dc8621ea1e27ca6819e3b2600d212b97ed2a33822ef
```
