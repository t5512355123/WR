# EXP-WRPC-STEP5-HPLL-6208-16-KP-MINUS300-KI-MINUS1-LANE2-MAIN-FREQUENCY-PRELOCK-OBSERVABILITY-600S-20260902

## 執行狀態

本輪依分支 5 指定的控制條件執行，但未開始宣稱 600 秒 Step5 結果。燒錄後硬體重新進入 Step4B event-processing，然而 Helper lock gate 沒有在本次 fresh-program window 重新成立，因此 Main PLL 尚未啟動，無法取得可判讀的 Main frequency distribution。

```text
branch                         = exp/step5-softpll-lock
source HEAD                    = 7585a0619373c84a58431920a0985587c1b30cad
bootstrap                      = 6208
code_per_physical_step         = 16
helper kp / ki                 = -300 / -1
helper threshold / samples    = 200 / 10000
QSFPA lane                     = 2
normal tracker                 = ON
Main prelock gain boost        = 20
Main frequency threshold       = 50
Main frequency lock samples    = 50
control-variable change        = NONE
```

## Build / programming identity

Master 與 Slave 均由本輪 HEAD 重建，並依 Slave→Master 順序成功燒錄；兩個 Quartus build 都成功，但 timing 仍未 closed。

```text
Master SOF SHA256 = da9f67e6e167ea115ddfb24a3a03907553dab1efa39d1b51c8d89df74fbd7ed4
Slave  SOF SHA256 = 2ab90316fc7425e4ea30c62ae4bb01e49e19a93cfe0fb67fcd19a14bdaea18ac
TIMING_CLOSED     = NO
```

## Step4B settled preflight

初次燒錄後 Slave 曾短暫處於 `PTP=UNCALIBRATED`，等待後的兩次 retry 均通過 Step4B authorization：

```text
Master Step1/Step2/Step4A       = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED                  = YES
STEP4B_RESULT                   = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY  = ACTIVE
JTAG_WB_DIAGNOSTIC_PATH         = TRUSTED
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
RXERR delta                     = 0
BOOT/CPU/WR-core/SI reset delta = 0
```

因此本輪可以確認：`Step4B = PASS`。原始 preflight 與 retry raw output 保存在本目錄的 `raw/`。

## Main observer smoke

新加入的 Main overlay 使用 seqlock；因 JTAG 讀完整 22-word frame 約需 1.1 秒，Main overlay 只降低診斷發布頻率至約 2 秒一次，沒有改變 SoftPLL/controller cadence 或控制參數。3-sample smoke 的 raw epoch/magic 已可回讀，但 Main 尚未 enable：

```text
MAIN_TRACE_VALID       = 0/3
FRAME_VALID             = 3/3
MAIN_ENABLED            = 0
MAIN_FREQ_LOCKED       = 0
MAIN_PHASE_LOCKED      = 0
MAIN_LOCKED             = 0
PSTAT_LOCKED            = 0
BOOT_GENERATION         = 1 -> 1
CPU/WR-core/SI reset    = stable
```

invalid frame 的 payload raw 值為合法的零值與固定 PI 設定；這個 window 的 Main frame 仍在 disabled state，且 strict seqlock 讀取期間 epoch 有變化，因此沒有把不一致 frame 當成有效頻率資料。這不是 WB timeout 或亂碼。

## Helper boundary smoke

20 秒的唯讀 Helper convergence smoke 顯示：

```text
HELPER_LOCKED            = 0
HELPER_LOCK_COUNT        = 0 / 10000
HELPER_ERROR             = +150000
HELPER_OUTPUT            = 5 (下限)
MAIN_ENABLED             = 0
NORMAL_REQ delta         = 0
NORMAL_COMPLETED delta   = 0
DCO_STEP delta           = 0
SPLL_DELOCK delta        = 0
RESET deltas             = 0
```

這表示本次 window 的第一個 inactive boundary 是 `HELPER_LOCK`，所以沒有將它誤報為 `MAIN_FREQUENCY_LOCK`，也沒有把 smoke 當成正式 600 秒 Step5 結果。

## 本輪判定 / handoff

```text
STEP4B_COMPLETE       = YES
STEP4B_REVALIDATED    = YES
STEP5_COMPLETE        = NO
MERGE_APPROVED        = NO
NEXT_REQUIRED_ACTION  = 請分支 5 重新判定本次 fresh-program window，並指定唯一下一步
```

## Raw evidence

- `raw/step5-main-prelock-20260902/preflight-initial.log`
- `raw/step5-main-prelock-20260902/preflight-retry1.log`
- `raw/step5-main-prelock-20260902/preflight-retry2.log`
- `raw/step5-main-prelock-20260902/main-smoke.log`
- `raw/step5-main-prelock-20260902/helper-smoke.log`

原始遠端檔名使用完整 experiment ID；本機另以短檔名保存相同內容，以符合 Windows Git path limit。
