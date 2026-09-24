# EXP-WRPC-STEP5-WIDE-APPLIED-POSITION-CONTRACT-FDEC4096-RERUN-20260908

## 結論

本輪依 `Astra建議.md` 驗證 HPLL 的 absolute target/applied position contract。
將 applied position 改為 32-bit signed accumulator，並把 bootstrap/forced
FINC/FDEC completion 納入同一個物理位置；normal tracker 以此位置決定方向。

這個 contract 在硬體上通過 accounting，但沒有使 Helper 進入 lock：bootstrap
完成後 tracker 先執行 8191 個 FINC，最後仍停在 target 附近，而 Helper 仍為
負向飽和。這排除「單純 16-bit wrap 造成 tracker 不動」這個解釋，但證明目前
target-code 與實體 operating point 的方向/座標仍不一致。

```text
STEP1_TO_STEP3 = PASS
STEP4B = PASS
ABSOLUTE_POSITION_ACCOUNTING = PASS
STEP5 = NOT_PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 版本與唯一變因

```text
branch = exp/step5-softpll-lock
source_commit = bc658f15eb20830a93bdab16dad8927c639c1678
functional_parent = 38526af5abbe4c789d5b4176c271d22f63e035d5
bootstrap_steps = 4096
bootstrap_direction = FDEC (STEP5_BOOTSTRAP_REVERSE=0)
code_per_physical_step = 16
normal_hpll_tracker = 1
```

本輪沒有修改 PI、lock threshold、DMTD、PTP、PHY 或 reset policy。observer
只更新了 bootstrap baseline guard，使其與 4096-step image 一致。

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

SOF SHA-256：

```text
MASTER = 011c853dd20705d2050f1772db8a4cbd285a9b497b62d5f240b40d6f5d271cae
SLAVE  = 1d5572a2ee93547994b14f62d855baca60f8295b767a8ba31ed0f4ee23e8cff8
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

因 JTAG snapshot 讀取本身有額外時間，1200 samples 的實際 elapsed window 為
138.738 秒；1107 frame valid、93 frame invalid。accepted samples 的 coherent
measurement、position、transaction、DCO 與 reset accounting 全部通過。

```text
SAMPLES = 1200
VALID_FRAMES = 1107
INVALID_FRAMES = 93
WINDOW_SECONDS = 138.738
POST_BOOTSTRAP_BASELINE_SAMPLE = 1
BOOTSTRAP_COMPLETED_FINAL = 4096
BOOTSTRAP_DONE_FINAL = 1
FORCED_COMPLETED_FINAL = 4096
NORMAL_REQ_FINAL = 8191
NORMAL_COMPLETED_FINAL = 8191
FINC_COMPLETED_FINAL = 8191
FDEC_COMPLETED_FINAL = 0
DCO_STEP_FINAL = 12287
TARGET_FINAL = 65531
APPLIED_FINAL = 65525
EXPECTED_APPLIED_ABSOLUTE = 65525
POSITION_ACCOUNTING = PASS
MEASUREMENT_COHERENCE = PASS
RESET_STABLE = PASS
```

The position values are consistent with:

```text
5 + 16 * ((8191 - 0) + (0 - 4096)) = 65525
```

つまり hardware path 實際完成了 4096 個 bootstrap FDEC，再完成 8191 個
normal FINC；applied accumulator 沒有在 16-bit 邊界折返。

Helper/lock 結果：

```text
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_OUTPUT_FINAL = 65531
HIGH_RAIL_FRACTION = 1.0
HELPER_LOCK_COUNT_MAX = 4608
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
MAIN_ENABLED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
```

## 判讀與下一步

修正後的 absolute tracker 不是「沒有動」：它在 bootstrap 後把 applied 從
`-65531` 追到 `65525`，但此時 Helper 仍鎖在 `error=-150000/output=65531`。
因此下一輪不應繼續增加同一個 bootstrap，也不應只延長觀測時間。更有價值的
下一個 A/B 是保留 page/mask fix 與 absolute telemetry，將 normal HPLL 的
target-to-FINC/FDEC polarity 與已辨識的 Helper actuator 方向分離驗證；若方向
正確仍停在 rail，再把 bootstrap 當成獨立 physical origin，而非直接加到
helper-code target 座標。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

- [raw archive](raw/EXP-WRPC-STEP5-WIDE-APPLIED-POSITION-CONTRACT-FDEC4096-RERUN-20260908.tar.gz)
- [archive SHA-256](raw/EXP-WRPC-STEP5-WIDE-APPLIED-POSITION-CONTRACT-FDEC4096-RERUN-20260908.tar.gz.sha256)
- [closed-loop observer log](raw/closed-loop-120s.log)
- [preflight 2](raw/preflight-2.log)
