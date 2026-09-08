# EXP-WRPC-DCO-PAGE-ISOLATION-20260907

## 結論

本輪只修正 SI5340 runtime DCO 的 page/mask 交易，並保留原有 PI、bootstrap、
tracker、Step4 static-FSM completion gate 與 reset policy。結果如下：

```text
PAGE_MASK_SIMULATION = PASS
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (5/5 preflight)
STEP4B = PASS (5/5 preflight)
STEP5 = NOT_PASS
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

因此這是一次有價值的介面修正與硬體回歸，但不是 Step5 完成，也沒有 merge。

## 版本、映像與流程

- Branch：`exp/step5-softpll-lock`
- Source commit：`a2abe910e82b510d7178f37d4b5d1673d4a7c784`
- 編譯主機：pain，Quartus 17.0.0 Build 595
- 燒錄工具：pain，Quartus Prime Programmer 21.3
- 程式順序：Master（DE5 [1-11.1]）→ 等待 46 秒 → Slave（DE5 [1-11.2]）
- 編譯與燒錄均依 laptop push → pain pull/build/program 流程完成

SOF SHA-256：

```text
Master d8f2afc7adc8d1635b15146c72be13fb9b56712258199270a2e920c886e63903
Slave  a9c00df60451bca51c3227f9a4b8123a4470c6ed6b614e61a5552128fd394e35
```

兩份 Fitter 都成功；timing 仍不是 closed：Master worst setup slack `-0.246 ns`、
Slave `-0.023 ns`。這是本輪 caveat，不能宣稱 timing PASS。

## 先做的 pin-level 合約測試

原始版本的三筆 runtime transaction 被解碼為：

```text
page=00, offset=39, data=0e/0d
```

因此兩個 mask 都落在 page 0。模型在靜態 mask `0x0c` 下重現 Main 一個 step 同時
移動 N0、N1；Main code `100 → 10000` 也只完成一個 step，後續重送相同 code 沒有
繼續排出 residual steps。

修正後的 production serializer 在 pin-level page-aware model 中產生：

```text
page=00, offset=01, data=03
page=03, offset=39, data=0e/0d
page=03, offset=01, data=00
page=00, offset=1d, data=01/02

PAGE_CONTRACT_TEST=PASS expected_fixed=1 writes=8 wrong_page=0
```

這證明交易順序與 N0/N1 mask 隔離在模型中成立；它不是實體輸出頻率隔離的替代
證據。Main 的 absolute-target 問題仍未修正，模擬也明確保留為 `KNOWN_FAIL`。

## 實體燒錄與五次 preflight

Master 與 Slave 都回報 1 device configured、0 errors、0 warnings。燒錄後等待啟動
穩定，執行五次唯讀 `read_wb_runtime.tcl --raw`，每次的共同判定為：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_RESULT = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

五次均未發現 RXERR、CPU reset、WR-core reset 或 SI-config drop 的觀測增量；PTP
RX/TX 仍在增加。這說明 page 修正沒有破壞 upstream link、Step4B event chain 或
transport，但它也沒有讓 Helper 進入 Step5 的 lock 狀態。

## 120 秒 Helper 收斂觀測

在 Slave 上執行 1200 samples、100 ms gap 的唯讀觀測：

```text
SAMPLES = 1200
VALID_FRAMES = 1200
WINDOW_SECONDS = 119.900
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_MEAN = 150000.0
HELPER_ERROR_MAX_ABS = 150000
HELPER_OUTPUT_RAIL5_FRACTION = 100.0
MAIN_ENABLED_FINAL = 0
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
BOOTSTRAP_COMPLETED_DELTA = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

所以隔離後原本的 `bootstrap=6208` 不可直接視為仍在正確 operating point；硬體
呈現 Helper output 卡在 5、error 卡在 +150000。這更支持下一輪先做獨立 actuator
辨識／operating-point search，而不是立刻掃相鄰 PI gain。不能只從這一輪斷言唯一
根因是 mask 修正；還需要實體頻率量測與正負受控 burst 交叉驗證。

## 判定與下一步

本輪 `STEP5_COMPLETE=NO`。下一輪只做一個清楚的變因：在 page/mask 已正確且不再
變動的版本上，加入受控的 Helper N1 正負 bounded burst 與外部／獨立頻率量測，
找出 isolated operating point、方向、增益與可達範圍。不要同時改 Main PI 或 lock
detector；Main absolute target 另開下一個實驗，避免兩個控制介面問題混在同一輪。

若沒有獨立頻率量測，至少要先把 burst request、ACK、completed、applied position
與輸出響應分開記錄；只看 `bus_done` 或 JTAG counter 不足以宣告 actuator 作用。

完整 raw evidence 在同資料夾 `raw/`；其中 `simulation.log`、兩份 build info、
program logs、五份 preflight 與 `helper-smoke-120s.log` 均保留。
