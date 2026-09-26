# EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC6144-20260908

## 結論

本輪依 `Astra建議.md` 測量 4096 與 8192 FDEC endpoint 之間的 coarse midpoint。
normal HPLL tracker 維持關閉，只施加 6144 筆 FDEC bootstrap，因此觀測到的是
固定 physical operating point，而不是閉迴路暫態。

6144-step 比 4096/8192 更接近零，但仍沒有進入 Helper lock band；Step5 仍未
完成，不能宣稱 pass。

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
source_commit = ef646161f0e7ed1c88432739498b89687c142204
bootstrap_steps = 6144
bootstrap_direction = FDEC (STEP5_BOOTSTRAP_REVERSE=0)
code_per_physical_step = 16
normal_hpll_tracker = 0
```

相對上一輪只將固定 FDEC bootstrap 從 8192 改為 6144；沒有修改 PI、lock
threshold、DMTD、PTP、PHY 或 reset policy。

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
MASTER = 73ee528d5b758b8d9a8961ccbb21c85f55d74588b6412b6a6cb4a7f71f8dda19
SLAVE  = dad6db61b994bc955049cfb0138c97456cda2e312a8e717f46fe8bafa5a3149
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

1200 samples 的實際 elapsed window 為 135.044 秒；1200 個 coherent measurement
snapshots，沒有 rejected epoch snapshot 或 accounting failure。觀測期間沒有新增
boot、CPU、WR-core 或 SI reset。

```text
SAMPLES = 1200
FRAME_VALID_1 = 1200
FRAME_VALID_0 = 0
COHERENT_MEASUREMENT_SNAPSHOTS = 1200
REJECTED_EPOCH_SNAPSHOTS = 0
POST_BOOTSTRAP_BASELINE_SAMPLE = 1
BOOTSTRAP_COMPLETED_FINAL = 6144
BOOTSTRAP_DONE_FINAL = 1
FORCED_COMPLETED_FINAL = 6144
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
FREQ_ERROR_MEAN = -2505.535
FREQ_ERROR_RMS = 2505.553976
HELPER_ERROR_MEAN = 70250.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.7325
HIGH_RAIL_FRACTION = 0.265833333333
NO_RAIL_FRACTION = 0.00166666666667
HELPER_ERROR_FINAL = 150000
HELPER_OUTPUT_FINAL = 5
HELPER_LOCK_COUNT_MAX = 3
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
FULL_CHAIN_MAX_SECONDS = 0.000
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

`ERROR_BAND_EXIT_EVENTS=0`、`ACTUATOR_HUNT_OBSERVED=NO`，observer 分類為
`STEADY_BIAS_OR_ACTUATOR_RANGE_LIMIT`。6144-step 沒有產生可鎖窗口；但與先前
4096 的負向 rail、8192 的正向 rail 結合後，已確認可鎖工作點若存在，位於
4096～6144 之間，或至少更靠近 6144 的低側。

## 判讀與下一步

本輪不是 Step5，也不能用短暫 lock-count 增加宣稱 lock。三點結果顯示誤差由
4096 的負向飽和朝 6144 的正向飽和移動，但 6144 仍有 73.25% 低 rail、26.58%
高 rail，表示可用區可能很窄或 physical step 增益過大。下一輪應測 5120-step
固定 coarse point；若仍未進入 lock band，再測 5632 或 5376，以二分/局部搜尋
縮小工作點，不同時修改 PI 或 lock detector。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

- [raw archive](raw/EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC6144-20260908.tar.gz)
- [archive SHA-256](raw/EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC6144-20260908.tar.gz.sha256)
- [closed-loop observer log](raw/closed-loop-120s.log)
- [preflight 2](raw/preflight-2.log)
