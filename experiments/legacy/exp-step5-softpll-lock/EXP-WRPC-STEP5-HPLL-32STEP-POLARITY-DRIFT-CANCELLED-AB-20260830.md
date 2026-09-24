# EXP-WRPC-STEP5-HPLL-32STEP-POLARITY-DRIFT-CANCELLED-AB-20260830

## 結論

本輪依分支5指定的方法，在 A/B 兩次 fresh-program 的相同 Slave SOF 上，把 forced diagnostic burst 從 8 steps 放大到 32 steps；A/B 仍只切換 forced HPLL polarity，並以各自 no-force local baseline 做 drift correction。

```text
STEP4B = PASS
32STEP_TRANSACTION_A = PASS
32STEP_TRANSACTION_B = PASS
POLARITY_CAUSALITY = PASS
CORRECT_FORCED_DIRECTION = A (forced_rt_dir = hpll_dir)
FORCED_ACTUATOR_TO_MEASUREMENT_CAUSALITY = PASS
STEP5_CLOSED_LOOP_LOCK = NOT PASS
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

A/B 的 drift-corrected actuator effect 明確異號；A 的 effect 為正，能相對自然 drift 把目前負的 pre-clamp error 拉回 0，B 則為負。這正式證明 forced HPLL polarity 的因果方向，但還沒有證明正常 closed-loop SoftPLL 已取得 Helper/Main/PSTAT lock。

## 固定版本與產物

```text
branch = exp/step5-softpll-lock
source/SOF/reader commit = 4ebae7ac095d74f62583d4307501afe64ace71e7
experiment = EXP-WRPC-STEP5-HPLL-32STEP-POLARITY-DRIFT-CANCELLED-AB-20260830
forced burst size = 32
```

本輪兩次執行都使用同一個 Slave SOF，且各自 fresh-program 後等待 Step1–4B 穩定再開始 reader：

```text
Master SOF SHA256 = 6c8124b35bc2f6496b12c704891615ff63be305bdbb68c490041366c4589e018
Slave SOF SHA256  = 2cca4e699fd8d99b39631d680f008bd335e0f19cb304bc9276d8532a0db9cd53
programmer = success, 0 errors
TIMING_CLOSED = NO
```

第一次 fresh-program 後立即執行的 A window 曾處於 upstream 尚未 ready 狀態，所有 diagnostic shadow 為 0 且 burst 未完成；該 invalid startup capture 已保留在 raw，但不納入本輪判定。以下只使用 `jtag-32step-a-valid.log` 與 `jtag-32step-b-valid.log`。

## 32-step transaction acceptance

A、B 的 `B_BEFORE -> B001` 都完整符合分支5指定的 acceptance：

```text
                                      A       B
DELTA_BURST_TRIGGER_COUNT            1       1
DELTA_FORCED_HPLL_PENDING_COUNT     32      32
DELTA_FORCED_HPLL_COMPLETED_COUNT   32      32
DELTA_STEP                          32      32
DELTA_RT_STATE_ENTER_COUNT          32      32
DELTA_RUNTIME_START_COUNT           96      96
DELTA_BUS_DONE_COUNT                96      96
```

`POLARITY_ACTIVE` 也確認 A/B selector 已在 burst completion 後分別為 `0` 與 `1`。

## Drift-corrected calculation

對每個 polarity，先使用 no-force A0→A05 window 計算自然 drift slope：

```text
baseline_slope = DELTA_PRECLAMP_ERROR / DELTA_HELPER_UPDATE_COUNT
EXPECTED_DRIFT = baseline_slope * burst_window_helper_updates
ACTUATOR_EFFECT = observed_burst_delta - EXPECTED_DRIFT
```

### A：`forced_rt_dir = hpll_dir`

No-force baseline：

```text
PRECLAMP_ERROR: -447323025 -> -467515848
DELTA_PRECLAMP_ERROR = -20192823
DELTA_HELPER_UPDATE_COUNT = 20305
baseline_slope = -994.475400 per helper update
```

Burst window：

```text
PRECLAMP_ERROR: -467515848 -> -471547459
DELTA_PRECLAMP_ERROR = -4031611
DELTA_HELPER_UPDATE_COUNT = 4060
EXPECTED_DRIFT = -4037570.125
ACTUATOR_EFFECT = +5959.125
```

Burst completion 後第一個 helper-update observation window 為 `B001 -> H006`：

```text
DELTA_PRECLAMP_ERROR = -4007781
DELTA_HELPER_UPDATE_COUNT = 4060
```

### B：`forced_rt_dir = ~hpll_dir`

No-force baseline：

```text
PRECLAMP_ERROR: -728328758 -> -747477591
DELTA_PRECLAMP_ERROR = -19148833
DELTA_HELPER_UPDATE_COUNT = 20242
baseline_slope = -945.995109 per helper update
```

Burst window：

```text
PRECLAMP_ERROR: -747477591 -> -751314697
DELTA_PRECLAMP_ERROR = -3837106
DELTA_HELPER_UPDATE_COUNT = 4048
EXPECTED_DRIFT = -3829388.202
ACTUATOR_EFFECT = -7717.798
```

Burst completion 後第一個 helper-update observation window 為 `B001 -> H007`：

```text
DELTA_PRECLAMP_ERROR = -3859217
DELTA_HELPER_UPDATE_COUNT = 4050
```

## Polarity判定

```text
ACTUATOR_EFFECT_A = +5959.125
ACTUATOR_EFFECT_B = -7717.798
```

兩者明確異號，且目前 error 為負值：

```text
A：相對自然 drift 把 error 拉回 0
B：相對自然 drift 把 error 推向更負
```

因此本輪可選定：

```text
CURRENT_FORCED_POLARITY = CORRECT
CURRENT_FORCED_DIRECTION = hpll_dir
REVERSED_FORCED_POLARITY = WRONG
POLARITY_CAUSALITY = PASS
```

`TAG_DELTA` 在 burst 與後續 helper sample 也有更新；`EXPECTED_DELTA` 的單筆取樣大致維持 source-defined 的 `16384`。少數 burst delta line 出現 WB shadow 讀取不同步，raw individual sample 仍保留，且不影響上述 pre-clamp drift-corrected 判定。

## 穩定 runtime dashboard

B fresh-program、32-step burst、等待後的穩定 dashboard 為：

```text
Step 1 PHY / Link             pass
Step 2 Endpoint / PTP         pass
Step 3 WR Handshake           pass
Step 4B Slave SoftPLL Startup pass
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE

HELPER locked=0 cnt=0/10000 threshold=200
MAIN enabled=0 locked=0
PSTAT_locked=0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

所以 Step4B 已 closure；Step5 仍停在 Helper lock，不能把 polarity causality PASS 誤當成 closed-loop lock PASS。

## 下一步與 merge gate

本輪已完成分支5指定的 32-step polarity/drift-cancelled experiment，但目前沒有 Helper lock、Main lock 或 `PSTAT.locked=1`。因此：

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

在分支5明確回覆 `STEP5_COMPLETE=YES` 且另外明確回覆 `MERGE_APPROVED=YES` 前，不合併到 `main`。

## 原始證據

- [valid 32-step A raw log](raw/EXP-WRPC-STEP5-HPLL-32STEP-POLARITY-DRIFT-CANCELLED-AB-20260830/polarity-a/jtag-32step-a-valid.log)
- [valid 32-step B raw log](raw/EXP-WRPC-STEP5-HPLL-32STEP-POLARITY-DRIFT-CANCELLED-AB-20260830/polarity-b/jtag-32step-b-valid.log)
- [stable dashboard before B](raw/EXP-WRPC-STEP5-HPLL-32STEP-POLARITY-DRIFT-CANCELLED-AB-20260830/polarity-b/dashboard-before-32step-b-ready.log)
- [stable dashboard after B](raw/EXP-WRPC-STEP5-HPLL-32STEP-POLARITY-DRIFT-CANCELLED-AB-20260830/polarity-b/dashboard-after-32step-b.log)
- [build and timing logs](raw/EXP-WRPC-STEP5-HPLL-32STEP-POLARITY-DRIFT-CANCELLED-AB-20260830/)
- [32-step bounded-burst reader](../../../scripts/jtag/read_step5_jtag_hpll_bounded_burst_ab.tcl)

