# EXP-WRPC-STEP5-STATIC-COARSE-FORWARD-4096-20260908

## 結論

本輪完成與上一輪 reverse 4096 的 polarity A/B：Slave 固定施加 opposite
polarity 4096 steps，normal HPLL tracker 維持關閉。兩板完整編譯與燒錄成功；
等待 startup recovery 後，可信 preflight 的 Step1、Step2、Step3、Step4B 全部
通過。

opposite polarity 確實被送出並完成，但 Helper 仍沒有 lock，error 仍主要位於
負向飽和端。因此目前不能宣告 Step5；下一步應停止只增加 bootstrap 步數，改做
absolute/applied position accounting 或 silicon readback，釐清 FPGA 端完成的
4096 筆 transaction 與實際 SI5340 DCO position 的關係。

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
- Source commit: `a9e0226638bf3ec1e203d4abaa107ac0e813f3ac`
- 唯一 functional 變因：`STEP5_BOOTSTRAP_REVERSE: 1 -> 0`
- `STEP5_BOOTSTRAP_STEPS=4096`
- `ENABLE_NORMAL_HPLL_TRACKER=0`
- `ENABLE_STEP5_ACTUATOR_IDENTIFICATION=1`
- DCO page/mask fix、probe 50/51、PI、lock detector、reset tree 與 upstream 未改

```text
BUILD_MASTER_RC = 0
BUILD_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
RECOVERY_PROGRAM_MASTER_RC = 0
RECOVERY_PROGRAM_SLAVE_RC = 0

MASTER_SOF_SHA256 = 4c02ebc3e860161a8b78884c10c06708bc41a741bc9c1be81112fd220c6e9809
SLAVE_SOF_SHA256 = ab7a6498a80f89096d96d3cff3a134c106ee9604b5129e2bdfa68758be3d520e
```

## Upstream preflight

燒錄後的前兩次讀值包含已知 startup/link transient。Master → 45 秒 → Slave
recovery 並等待校準後，preflight 3/4 得到可信 settled window：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

## 120 秒 Step5 observer

Observer 為 1200 samples、100 ms cadence，實際窗口 119.901 秒；所有 1200 個
frame 有效。完整 raw output 與 archive 校驗值保存在同資料夾 `raw/`。

```text
SAMPLES = 1200
VALID_FRAMES = 1200
INVALID_FRAMES = 0
WINDOW_SECONDS = 119.901
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_SAMPLES = 1200
HELPER_ERROR_MEAN = -145750.0
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
FORCED_FINC_FINAL = 0
FORCED_FDEC_FINAL = 4096
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

## Polarity A/B 判讀

同樣 4096 steps、normal tracker 關閉時：

```text
reverse=1: FORCED_FINC=4096, HELPER_ERROR_MEAN=-150000.0
reverse=0: FORCED_FDEC=4096, HELPER_ERROR_MEAN=-145750.0
```

兩方向均完成完整 page/mask/page/FINC-FDEC sequence 且 ACK error=0；opposite
polarity 使結果離開負向 rail 一小段，但仍遠離 Helper lock window。這排除
「只因方向位沒有送到」的簡單解釋，也顯示 4096 steps 不足以找到 operating
point，或 virtual position 尚未正確反映 physical applied position。

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
MERGE_APPROVED = NO
```

## Raw evidence

- Pain archive: `raw/EXP-WRPC-STEP5-STATIC-COARSE-FORWARD-4096-20260908.tar.gz`
- Archive SHA-256: `101ed0dd90ff43d0f75e46bdde5104c858395482aea0fa5540570690f31f42a4`
- Raw archive 本身保留於 Git，未清理 Pain 端其他既有未追蹤研究資料。
