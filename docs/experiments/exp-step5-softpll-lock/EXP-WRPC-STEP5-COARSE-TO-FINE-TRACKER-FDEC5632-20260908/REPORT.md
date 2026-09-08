# EXP-WRPC-STEP5-COARSE-TO-FINE-TRACKER-FDEC5632-20260908

## 結論

本輪在 FDEC5632 coarse 起點開啟正常 HPLL tracker。兩次 preflight 的 settled
結果確認 Step1～4B PASS，observer 也完成 1200 個 coherent snapshots；但正常
tracker 在觀測開始前已經完成對稱的 FINC/FDEC 來回動作，Helper 全窗仍飽和在
rail，Step5 未完成。

```text
STEP1_TO_STEP3 = PASS (settled preflight 2)
STEP4B = PASS
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
STEP5 = NOT_PASS
STEP5_RESULT = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 版本與變因

```text
branch = exp/step5-softpll-lock
source_commit = 3e987e2
bootstrap_steps = 5632
bootstrap_direction = FDEC (STEP5_BOOTSTRAP_REVERSE=0)
code_per_physical_step = 16
normal_hpll_tracker = 1
```

相對 static FDEC5632 版本只開啟 `ENABLE_NORMAL_HPLL_TRACKER`；沒有修改 PI、
lock threshold、DMTD、PTP、PHY 或 reset policy。

## Build、program 與 preflight

```text
SIMULATION_RC = 0
FIRMWARE_MASTER_RC = 0
FIRMWARE_SLAVE_RC = 0
COMPILE_MASTER_RC = 0
COMPILE_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
```

兩個 SOF 都是本輪由同一 source commit 產出；Quartus timing 仍為既有
`TIMING_CLOSED=NO` caveat。

```text
MASTER_SOF_SHA256 = ae03d9daeaca1a9420a21b5b3ab99e18b97ead7408039523b6f547e96d6cdcad
SLAVE_SOF_SHA256 = 2c3e3dbc402f3cef6f57828a47189492e213f66b2f3888495554dacbc261764b
```

第一次 preflight 顯示 tracker 啟動期間 `STEP4B=BLOCKED_BY_STEP3`；等待後的
第二次 settled preflight 是：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

## 120-second coherent observer

observer 輸出 1200 個 coherent snapshots，最後 sample 的實際 elapsed window 為
134.541 秒；沒有 accounting、coherence 或 reset 穩定性失敗。

```text
SAMPLES = 1200
COHERENT_MEASUREMENT_SNAPSHOTS = 1200
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 0
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 1200
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
BOOTSTRAP_COMPLETED_FINAL = 5632
BOOTSTRAP_DONE_FINAL = 1
FORCED_COMPLETED_FINAL = 5632
TARGET_FINAL = 5
APPLIED_FINAL = 5
EXPECTED_APPLIED_ABSOLUTE = 5
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
DCO_STEP_DELTA = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

觀測第一個 sample 時，細迴路計數器已經是：

```text
NORMAL_REQ_COUNTER = 8190
NORMAL_COMPLETED_COUNTER = 8190
FINC_COMPLETED_COUNTER = 4095
FDEC_COMPLETED_COUNTER = 4095
DCO_STEP_COUNTER = 13822
```

也就是 tracker 實際執行了 4095 次 FINC 與 4095 次 FDEC，但淨 applied position
仍回到 5；observer 的 delta 為 0 是因為動作在 observer baseline 建立前已完成，
不是因為 tracker 沒有執行。

## Helper 與 lock 結果

```text
FREQ_ERROR_MEAN = -2397.255
FREQ_ERROR_RMS = 2397.27198151
HELPER_ERROR_MEAN = 150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 1.0
HIGH_RAIL_FRACTION = 0.0
NO_RAIL_FRACTION = 0.0
LOCK_COUNT_MAX = 0
LOCK_COUNT_FINAL = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0.000
STEP5_CHAIN_RESULT = NOT_COMPLETE
PRECLAMP_FIRST = 1826215786
PRECLAMP_FINAL = 386537655
HELPER_ERROR_FINAL = 150000
HELPER_OUTPUT_FINAL = 5
```

## Interpretation and next action

`0xFFFB` is the observed raw HPLL value used by the upstream path. The current
tracker stores `iHPLL_DATA` with zero-extension, so `0xFFFB` is interpreted as
65531 instead of signed -5. The measured 4095/4095 symmetric transaction pattern
is consistent with the tracker chasing the false `65531 ↔ 5` distance. This round
therefore identifies a signed target-position contract defect; the next round
should sign-extend `iHPLL_DATA` into `hpll_target_position`, keep bootstrap FDEC5632,
and rerun the same observer. Step5 must remain `NO` and no merge is allowed.

## 原始證據

所有原始輸出、preflight、observer、SOF 雜湊及完整 archive 位於本資料夾的
`raw/` 目錄。
