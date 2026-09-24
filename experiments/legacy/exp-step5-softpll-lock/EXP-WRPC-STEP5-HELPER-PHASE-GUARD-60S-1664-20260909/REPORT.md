# EXP-WRPC-STEP5-HELPER-PHASE-GUARD-60S-1664-20260909

## 判定

本輪在 Slave 啟動時加入 60 秒 Helper phase guard：coarse HPLL bootstrap
期間不呼叫 Helper fine-loop，guard 結束後清除 phase accumulator、PI
integrator 與 lock detector，並以第一個新 accepted tag 重新建立 baseline。
Master 行為不變，Slave coarse operating point 維持 1664 reverse/FINC。

硬體編譯、燒錄、上游 recovery 與觀測流程均完成，但 Step5 沒有鎖定，
不能 merge。

```text
SOURCE_COMMIT = 32c98afb9322e6e954579b611ab8562a5d0f5edf
PREFLIGHT_1 = UPSTREAM_INVALID (Slave Step2 dashboard boundary)
PREFLIGHT_2 = VALID
STEP1_TO_STEP3 = PASS (valid preflight-2 window)
STEP4A = PASS
STEP4B = PASS
STEP5_VALID_MEASUREMENT = YES
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 變更

```text
Slave-only Helper phase guard = 60 seconds
Guarded path: SEQ_START_HELPER -> suppress helper_update() -> helper_reseed()
helper_reseed(): phase history=clear, PI integrator=clear, LD=clear,
                 first accepted tag becomes the new baseline
Slave STEP5_BOOTSTRAP_STEPS = 1664 (unchanged from previous run)
```

這輪沒有修改 PI gains、DCO page/mask sequence、HPLL step size、Main、DMTD、
PTP、PHY 或 reset policy。observer 仍只讀取 coherent WDIAGS 與 DCO
completion/accounting probes。

## Build / program provenance

Pain 從上述 commit 的乾淨 build worktree 完整編譯 Master/Slave；兩個
Quartus full compilation 與兩次 JTAG programming 都成功：

```text
MASTER_SOF_SHA256 = faf6ce63687f48d09ac0ec4facefdc3d0ed48f0ccc8737780db3fd738202d481
SLAVE_SOF_SHA256  = 5c0d7f44dd9a63674c64a96b268642c3de9c8d7b54aced95dd2b09fb9228cefe
MASTER_COMPILE = Full Compilation was successful
SLAVE_COMPILE = Full Compilation was successful
MASTER_PROGRAM = configuration succeeded, 0 errors, 0 warnings
SLAVE_PROGRAM = configuration succeeded, 0 errors, 0 warnings
TIMING_CLOSED = NO
MASTER_WORST_SETUP_SLACK_NS = -0.178
SLAVE_WORST_SETUP_SLACK_NS = -0.192
```

## Valid upstream window

第一次 preflight 的 Slave Step2 讀值被 dashboard 判為 INVALID；沒有用它
做控制結論。30 秒後的 preflight-2 通過：

```text
Master Step1/Step2/Step4A = PASS
Slave Step1/Step2/Step3/Step4B = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

preflight-1 顯示 Slave `helper_update=0xD1`，表示 60 秒 guard 已解除且
Helper 已重新開始更新；preflight-2 則確認 Step4B 上游資格成立。

## Coherent closed-loop observation

在有效 upstream window 後執行 3600 samples、約 396.7 秒的 coherent
trajectory audit。Slave 的 measurement、position、transaction、DCO 與
reset accounting 全部通過：

```text
SAMPLES = 3600
POST_BOOTSTRAP_BASELINE_SAMPLE = 1
POST_BOOTSTRAP_BASELINE_SET = 1
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 結果與解讀

Guard 確實讓 coarse bootstrap 期間不累積 Helper phase，並在解除後重新
開始 accepted-tag 更新；但重新建立 baseline 後仍立即進入同一個飽和狀態：

```text
FREQ_ERROR_MEAN = -460.605833333
FREQ_ERROR_RMS = 460.736516352
FREQ_ERROR_MIN = -507
FREQ_ERROR_MAX = -423
FREQ_ERROR_FIRST = -460
FREQ_ERROR_LAST = -470
PRECLAMP_FIRST = -1097404206
PRECLAMP_FINAL = -1814506916
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.0
HIGH_RAIL_FRACTION = 1.0
HELPER_LOCK_COUNT_MAX = 15
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
TARGET_FINAL = 65531
APPLIED_FINAL = 65541
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 1664
BOOTSTRAP_DONE_FINAL = 1
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

因此本輪排除了「只要把 coarse bootstrap 期間的 phase history 清掉，1664
就能進入 fine lock」的假設。實際瓶頸仍在 Helper error/actuator 的穩態
方向或 operating-point coupling：phase guard 後 `PRECLAMP_ERROR` 仍持續
變負，Helper output 100% 位於高 rail，且沒有任何 normal tracker request
或 Main enable。

## 下一輪

保留 phase guard，將唯一 coarse 變因由 1664 改回上一輪 frequency error
較接近零的 3072 reverse/FINC operating point，重新做相同的 valid-preflight
與 300 秒以上 coherent audit。這能區分「guard 已足夠但 1664 不在可鎖頻率
區域」與「Helper/DCO 極性或 target semantics 仍錯」；不先改 PI gains。

## Raw evidence

本資料夾 `raw/` 保存 build、program、preflight 與 3600-sample observer。
遠端 raw archive SHA-256：

```text
2fc1556ad3f355386148827b118c2628b2c5b6f3d2cbc72032ed3cce9cb27a68
```
