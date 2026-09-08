# EXP-WRPC-STEP5-STATIC-NO-BOOTSTRAP-BASELINE-20260908

## 結論

本輪依 `Astra建議.md` 完成第一個乾淨的 static operating-point baseline：
Slave `STEP5_BOOTSTRAP_STEPS=0`、normal HPLL tracker 關閉，保留既有
DCO page/mask fix、telemetry、PI、lock detector、reset tree 與 upstream。

兩板完整編譯與燒錄成功；等待啟動校準後，可信 preflight 的 Step1、Step2、
Step3、Step4B 全部通過。120 秒 Slave observer 沒有 Helper lock，故 Step5
仍未通過，第一個可靠失敗邊界為 `HELPER_LOCK`。

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (settled preflight 5/6)
STEP4B = PASS (settled preflight 5/6)
STEP5 = NOT_PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 版本與設定

- Branch: `exp/step5-softpll-lock`
- Source commit: `72e7591c65957716f77dc93562d208668a9fc378`
- 唯一 functional 變因：`STEP5_BOOTSTRAP_STEPS: 128 -> 0`
- `STEP5_BOOTSTRAP_REVERSE=1`
- `ENABLE_NORMAL_HPLL_TRACKER=0`
- `ENABLE_STEP5_ACTUATOR_IDENTIFICATION=1`
- 既有 probe 50/51 與 page/mask path 未修改

Pain 端 Master/Slave full Quartus build 皆成功，兩份 SOF 均為本輪新產物，
但 fitter 顯示 `timing_closed=NO`。Programmer 兩板皆 RC=0。

```text
BUILD_MASTER_RC = 0
BUILD_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
RECOVERY_PROGRAM_MASTER_RC = 0
RECOVERY_PROGRAM_SLAVE_RC = 0

MASTER_SOF_SHA256 = 79084b971aa22e6f5c8170b32adaa6fc27fbe90cff496275c6ba3e9584b8039b
SLAVE_SOF_SHA256 = e661e5c2519c3b943d2a33656b18569d628d30ab0b889e5eff2987ae075d3145
```

## Upstream preflight

燒錄後的 preflight 3/4 仍處於已知 PTP startup transient；等待校準窗口後的
preflight 5/6 才作為可信結果：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

這證明本輪 no-bootstrap image 沒有破壞 PHY/link、Endpoint/PTP、WR handshake
或 Slave SoftPLL event chain。

## 120 秒 Step5 observer

Observer 為 1200 samples、100 ms cadence，實際窗口 119.900 秒；1191 個 frame
有效、9 個無效。完整輸出及校驗值保存在同資料夾 `raw/`。

```text
SAMPLES = 1200
VALID_FRAMES = 1191
INVALID_FRAMES = 9
WINDOW_SECONDS = 119.900
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_SAMPLES = 1189
HELPER_ERROR_MEAN = -148660.030278
HELPER_ERROR_RMS = 149711.841402
HELPER_ERROR_MAX_ABS = 196612
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 0.504625735913
HELPER_OUTPUT_FINAL_SIGNED = 65531
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
BOOTSTRAP_COMPLETED_DELTA = 0
I2C_RUNTIME_STARTS_FINAL = 0
I2C_BUS_COMPLETIONS_FINAL = 117
I2C_DCO_STEPS_FINAL = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 判讀

這是「不施加任何 bootstrap、也不啟動 normal tracker」的靜態基線，不是
對 actuator wiring 的完整否定。它顯示目前 power/program 起點的 Helper error
落在負向飽和端；在無 DCO request 的條件下，Helper 不會自行進入 lock。

與先前 `128 FINC` 及 `6208` 方向性實驗合併判讀後，單純繼續盲掃 PI 或 lock
threshold 沒有足夠依據。下一輪應在同一 telemetry 基礎上做單一變因的 coarse
operating-point bracket，優先用固定 bootstrap position、明確的 absolute/applied
position accounting，以及保持 normal tracker 關閉的短窗口，找出由飽和進入可達
error 區域的 operating point，再恢復閉迴路。

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
MERGE_APPROVED = NO
```

## Raw evidence

- Pain archive: `raw/EXP-WRPC-STEP5-STATIC-NO-BOOTSTRAP-BASELINE-20260908.tar.gz`
- Archive SHA-256: `6db5692b2e7b7592f395ad66a9115a2eed9acc6701e7d97f9d80b17789999bd5`
- Raw archive 本身保留於 Git，未清理 Pain 端其他既有未追蹤研究資料。
