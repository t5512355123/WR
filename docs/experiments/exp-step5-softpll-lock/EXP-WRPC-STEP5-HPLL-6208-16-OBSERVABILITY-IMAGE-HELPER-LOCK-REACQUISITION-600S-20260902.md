# EXP-WRPC-STEP5-HPLL-6208-16-OBSERVABILITY-IMAGE-HELPER-LOCK-REACQUISITION-600S-20260902

## 目的與控制條件

本輪依分支 5 指定的唯一下一步，針對同一個已燒錄映像執行 Helper lock
reacquisition observer。沒有重新編譯、重新燒錄、改變控制器參數或改變
SoftPLL / DCO / PTP / PHY 功能；觀測使用先前已通過 Step4B preflight 的
Slave 映像。

```text
programmed source commit       = 7585a0619373c84a58431920a0985587c1b30cad
bootstrap                      = 6208
code_per_physical_step         = 16
helper kp / ki                 = -300 / -1
helper threshold / samples    = 200 / 10000
QSFPA lane                     = 2
normal tracker                 = ON
control-variable change        = NONE
observer samples / interval    = 6000 / 100 ms
observer window                = 599.900 s
board                          = DE5 [1-11.2]
```

## Step4B settled preflight

同一觀測前的 settled preflight 已確認 upstream gate 可以使用：

```text
Master Step1/Step2/Step4A       = PASS
Slave  Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED                  = YES
STEP4B_RESULT                   = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
JTAG_WB_DIAGNOSTIC_PATH        = TRUSTED
RXERR delta                     = 0
BOOT/CPU/WR-core/SI reset delta = 0
```

因此這次 600 秒觀測不是因為 Step2 或 Step4B upstream 未準備好而失效。

## 600 秒觀測結果

最後摘要為：

```text
SAMPLES                       = 6000
VALID_FRAMES                 = 5999
INVALID_FRAMES               = 1
HELPER_LOCK_COUNT_MAX        = 0
HELPER_LOCK_COUNT_FINAL      = 0
HELPER_LOCKED_SEEN           = 0
HELPER_LOCKED_FINAL          = 0
FIRST_HELPER_LOCK_SAMPLE     = NONE
LOCK_CHANGED_EVENTS          = 0
HELPER_ERROR_MEAN            = 150000.0
HELPER_ERROR_RMS             = 150000.0
HELPER_ERROR_MAX_ABS         = 150000
HELPER_ERROR_WITHIN_LIMIT    = 0.0
HELPER_OUTPUT_RAIL5_SAMPLES  = 5999
HELPER_OUTPUT_RAIL5_FRACTION = 100.0
MAIN_ENABLED_FINAL           = 0
MAIN_LOCKED_FINAL            = 0
MAIN_FREQ_LOCKED_FINAL       = 0
MAIN_PHASE_LOCKED_FINAL      = 0
PSTAT_LOCKED_FINAL           = 0
SPLL_DELOCK_COUNT_MAX        = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS
RESET_BOOT_GENERATION_DELTA  = 0
RESET_CPU_DELTA               = 0
RESET_WR_CORE_DELTA            = 0
RESET_SI_CONFIG_DELTA          = 0
```

所有 6000 個樣本的 Helper lock 欄位均維持 inactive；`MAIN_ENABLED=1`、
`HELPER_LOCKED=1` 與 `PSTAT_LOCKED=1` 沒有出現，因此可判定
`MAIN_ENABLED_EVER=0`。Helper error 長時間固定在 `+150000`，輸出固定在
下限 `5`；這是 upstream Helper lock gate 未成立的真實結果，不應解讀為
Main lock dynamics。

## 判定

```text
STEP4B_COMPLETE       = YES
STEP4B_REVALIDATED    = YES
STEP5_COMPLETE        = NO
STEP5_RESULT          = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED        = NO
```

本輪正式關閉「觀測窗口太短或未完成」這個疑點，但沒有達成 Step5。依
分支 5 的 gate，因 Helper 從未 lock，不能宣稱 Main frequency / phase lock，
也不能 merge 到 `main`。

## Raw evidence

- `raw/step5-main-prelock-20260902/preflight-reacquisition.log`
- `raw/step5-main-prelock-20260902/helper-reacquisition-600s-final.log`

