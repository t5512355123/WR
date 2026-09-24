# EXP-WRPC-STEP5-STATIC-COARSE-REVERSE-4096-20260908

## 結論

本輪依 `Astra建議.md` 做單一變因的 static coarse operating-point bracket：
Slave 固定施加 reverse bootstrap `4096` steps，normal HPLL tracker 維持關閉。
這樣可把固定 actuator position 與動態閉迴路分開觀測。

兩板完整編譯與燒錄成功；等待 startup calibration 後，可信 preflight 的
Step1、Step2、Step3、Step4B 全部通過。120 秒 Slave observer 中 Helper 完全
停在負向滿量程，沒有形成 lock，因此 Step5 仍未通過。

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (settled preflight 3/4)
STEP4B = PASS (settled preflight 3/4)
STEP5 = NOT_PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 版本與設定

- Branch: `exp/step5-softpll-lock`
- Source commit: `54cda065f07426274c4951e8a2121c36d0bafe72`
- 唯一 functional 變因：`STEP5_BOOTSTRAP_STEPS: 0 -> 4096`
- `STEP5_BOOTSTRAP_REVERSE=1`（telemetry 顯示為 `FORCED_FINC`）
- `ENABLE_NORMAL_HPLL_TRACKER=0`
- `ENABLE_STEP5_ACTUATOR_IDENTIFICATION=1`
- DCO page/mask fix、probe 50/51、PI、lock detector、reset tree 與 upstream 未改

Pain 端 Master/Slave full Quartus build 皆成功，兩份 SOF 均為本輪新產物，
但 fitter 顯示 `timing_closed=NO`；Programmer 兩板皆 RC=0。

```text
BUILD_MASTER_RC = 0
BUILD_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
RECOVERY_PROGRAM_MASTER_RC = 0
RECOVERY_PROGRAM_SLAVE_RC = 0

MASTER_SOF_SHA256 = d83693a8b7c88a2ed3fd48ab558881cadd8a5f3a12f7faa5341e90b1bf4e0695
SLAVE_SOF_SHA256 = cdca66d1f5e47d67e9958d252919b884748f1f550919498df5c98799b99e1478
```

## Upstream preflight

燒錄後的前兩次讀值包含已知 startup transient。Master → 45 秒 → Slave recovery
並等待校準後，preflight 3/4 得到可信 settled window：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

## 120 秒 Step5 observer

Observer 為 1200 samples、100 ms cadence，實際窗口 119.900 秒；1189 個 frame
有效、11 個無效。完整 raw output 與 archive 校驗值保存在同資料夾 `raw/`。

```text
SAMPLES = 1200
VALID_FRAMES = 1189
INVALID_FRAMES = 11
WINDOW_SECONDS = 119.900
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_SAMPLES = 1176
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
HELPER_OUTPUT_FINAL_SIGNED = 65531
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 4096
BOOTSTRAP_DONE_FINAL = 1
FORCED_FINC_FINAL = 4096
FORCED_FDEC_FINAL = 0
FORCED_COMPLETED_FINAL = 4096
I2C_PHASE_SEEN_FINAL = 15
I2C_ACK_ERROR_FINAL = 0
I2C_DCO_ERROR_FINAL = 0
I2C_BUS_COMPLETIONS_FINAL = 117
I2C_DCO_STEPS_FINAL = 4096
NORMAL_TRANSACTION_ACCOUNTING = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

## 判讀與下一步

和上一輪 `STEP5_BOOTSTRAP_STEPS=0` 的負向飽和 baseline 相比，固定 reverse
4096 仍得到完全相同的負向滿量程結果；但 probe 51 證明 4096 筆完整 page/mask/
page/FINC transaction 已完成且 ACK error=0。這代表單純增加同方向的 bootstrap
已不會把目前 operating point 帶入 lock window，下一輪不應繼續沿同方向加大步數。

下一輪應保持 normal tracker 關閉、使用相同 4096 steps 測 opposite polarity，
確認是否能把 Helper 從負向 rail 拉回可達區；若 opposite polarity 也只停在 rail，
就應停止盲掃步數，實作 absolute/applied position accounting 或 silicon readback
證據，釐清 FPGA 完成計數與 SI5340 實際 DCO position 的差異。

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
MERGE_APPROVED = NO
```

## Raw evidence

- Pain archive: `raw/EXP-WRPC-STEP5-STATIC-COARSE-REVERSE-4096-20260908.tar.gz`
- Archive SHA-256: `df0b49ae7143c44f29b31f3b69fd3f74314ee43c80cd34933ab92c7d6a1bd38d`
- Raw archive 本身保留於 Git，未清理 Pain 端其他既有未追蹤研究資料。
