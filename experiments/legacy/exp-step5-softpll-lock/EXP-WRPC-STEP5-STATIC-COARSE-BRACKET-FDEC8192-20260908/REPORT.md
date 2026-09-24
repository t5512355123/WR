# EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC8192-20260908

## 結論

本輪依 `Astra建議.md` 執行受控 coarse operating-point bracket。保留 page/mask
修正與 16-code physical-step 設定，將 Slave normal HPLL tracker 關閉，只施加
8192 筆 FDEC bootstrap，量測固定工作點本身。

本輪成功證明 8192 筆 FDEC transaction 可完成且 Step1～4B 不受破壞，但 Helper
仍在 rail，沒有進入 lock；因此不是 Step5 pass。與 4096-step FDEC 的負向結果
相比，8192-step 已把結果推到正向 rail，形成可用的 coarse bracket。

```text
STEP1_TO_STEP3 = PASS
STEP4B = PASS
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
RESET_STABLE = PASS
STEP5 = NOT_PASS
STEP5_RESULT = NOT_COMPLETE
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 版本與唯一變因

```text
branch = exp/step5-softpll-lock
source_commit = e7ec45b608794a2da6ee695402299cc6b18d518c
bootstrap_steps = 8192
bootstrap_direction = FDEC (STEP5_BOOTSTRAP_REVERSE=0)
code_per_physical_step = 16
normal_hpll_tracker = 0
```

相對前一輪唯一的功能性實驗變因是：關閉 normal tracker，並把固定 FDEC coarse
bootstrap 從 4096 增加到 8192。沒有修改 PI、lock threshold、DMTD、PTP、PHY
或 reset policy。

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

Quartus timing 仍為既有 `TIMING_CLOSED=NO` caveat。SOF SHA-256：

```text
MASTER = 81b5e04a36225012574c592fff1d798fd02f8f6854e12237f76ee4f70e2e1a44
SLAVE  = 1d1c0e8e67a630bd4c252fdbd482d3fe90fcf47abded16c865e76c9a97b1add1
```

settled preflight 2：

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

1200 samples 的實際 elapsed window 為約 157.988 秒；observer 收到 1098 個
`FRAME_VALID=1`、102 個 `FRAME_VALID=0`，其中 1198 個 coherent measurement
snapshots。position、transaction、DCO accounting 均通過，觀測期間沒有新增
boot、CPU、WR-core 或 SI reset。

```text
SAMPLES = 1200
FRAME_VALID_1 = 1098
FRAME_VALID_0 = 102
COHERENT_MEASUREMENT_SNAPSHOTS = 1198
REJECTED_EPOCH_SNAPSHOTS = 2
POST_BOOTSTRAP_BASELINE_SAMPLE = 1
BOOTSTRAP_COMPLETED_FINAL = 8192
BOOTSTRAP_DONE_FINAL = 1
FORCED_COMPLETED_FINAL = 8192
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
FINC_DELTA = 0
FDEC_DELTA = 0
DCO_STEP_DELTA = 0
TARGET_FINAL = 5
APPLIED_FINAL = 5
EXPECTED_APPLIED_ABSOLUTE = 5
POSITION_ACCOUNTING = PASS
MEASUREMENT_COHERENCE = PASS
RESET_STABLE = PASS
```

## Helper 與 lock 結果

```text
FREQ_ERROR_MEAN = -2903.79465776
FREQ_ERROR_RMS = 2903.80361521
HELPER_ERROR_MEAN = 135976.627713
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.952420701169
HIGH_RAIL_FRACTION = 0.0467445742905
NO_RAIL_FRACTION = 0.000834724540902
HELPER_ERROR_FINAL = 150000
HELPER_OUTPUT_FINAL = 5
HELPER_LOCK_COUNT_MAX = 42
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0.000
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

`ERROR_BAND_EXIT_EVENTS=0`、`ACTUATOR_HUNT_OBSERVED=NO`，observer 分類為
`STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT`。8192-step FDEC 並未產生可鎖的中間區域；
它只把固定工作點推到正向 Helper rail。這與前一輪 4096-step FDEC 的
`HELPER_ERROR_MEAN=-145750`、負向 rail 結果互相印證：可鎖工作點若存在，應在
兩個工作點之間，而不是在兩個端點。

## 判讀與下一步

本輪不是 Step5，也不能用 `LOCK_COUNT_MAX=42` 宣稱 lock，因為 `HELPER_LOCKED_SEEN=0`
且所有有效樣本都沒有離開 `abs(error)<=200` 的 lock band。重要進展是建立了
4096～8192 FDEC 的符號 bracket，下一輪最有資訊價值的單一變因是中點附近的
固定 coarse 工作點，例如 6144 FDEC；仍先關閉 normal tracker，直接量測是否
接近 Helper lock band。若 6144 仍在 rail，再依誤差方向以二分方式縮小範圍，
不要同時改 PI 或 lock detector。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

- [raw archive](raw/EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC8192-20260908.tar.gz)
- [archive SHA-256](raw/EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC8192-20260908.tar.gz.sha256)
- [closed-loop observer log](raw/closed-loop-120s.log)
- [preflight 2](raw/preflight-2.log)
