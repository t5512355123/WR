# EXP-WRPC-STEP5-ISOLATED-REVERSE-BOOTSTRAP-20260908

## 結論

本輪在已修正 page/mask 的版本上，只測試 Slave forced/bootstrap polarity：
`ENABLE_STEP5_ACTUATOR_IDENTIFICATION=1`、`STEP5_BOOTSTRAP_REVERSE=1`，
bootstrap 仍為 6208 steps。PI、Main、lock detector、static-FSM gate、reset
tree 與 tracker 比例均未改。

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (可信 preflight 2–5)
STEP4B = PASS (可信 preflight 2–5)
STEP5 = NOT_PASS
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

反向 bootstrap 使 Helper error 方向由前一輪的 `+150000` 變成
`-150000`，證明 polarity 確實作用於硬體；但 6208 steps 仍沒有把 isolated
Helper 帶入 lock，不能宣布 Step5 完成，也沒有 merge。

## 版本、編譯與燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`74643971f52176af055a2b32e07b969994ed4758`
- 編譯：pain，Quartus 17.0.0 Build 595
- 燒錄：Master `DE5 [1-11.1]` → 等待 46 秒 → Slave `DE5 [1-11.2]`
- Programmer：兩板皆 1 device configured、0 errors、0 warnings

SOF SHA-256：

```text
Master f645d04d48b64c0da70afefb83dc5b81666989b31ed9c6b60a394fcc25c24af0
Slave  352227d156723d18b9390affe835ca72ef8c541d7309aa487d03b875d7dc3480
```

Fitter 成功，但 timing 仍未 closed：Master worst setup slack `-0.246 ns`、
Slave `-0.260 ns`。

## Preflight 結果

燒錄後第一個窗口仍是啟動 transient（Slave Step2 invalid/Step4B blocked）。
等待後的 preflight 2–5 皆得到：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_RESULT = PASS
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

這表示反向 bootstrap 設定沒有破壞 upstream 或 Step4B；但 Step4B PASS 仍只是
SoftPLL event chain 活動性，不是 Helper/Main/PSTAT lock。

## 120 秒 Helper 觀測

Slave 執行 1200 samples、100 ms gap：

```text
SAMPLES = 1200
VALID_FRAMES = 1196
INVALID_FRAMES = 4
WINDOW_SECONDS = 119.901
HELPER_LOCK_COUNT_MAX = 8630
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_MEAN = 82793.8867
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
HELPER_OUTPUT_RAIL5_FRACTION = 77.5919732441
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
NORMAL_REQ_DELTA = 4095
NORMAL_COMPLETED_DELTA = 4095
DCO_STEP_DELTA = 4095
BOOTSTRAP_COMPLETED_FINAL = 6208
BOOTSTRAP_DONE_FINAL = 1
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

`LOCK_COUNT_MAX=8630` 只代表曾經累積過部分合格計數，最後沒有形成有效 lock；
它不能被當成 Step5 的短暫 PASS。正常 tracker 仍在排步，但實際 error 仍大幅
飽和，說明問題是 isolated actuator 的絕對 operating point／可達範圍，尚不是
單純 polarity 結論。

## 判定與下一步

`STEP5_COMPLETE=NO`。本輪得到的資訊是：

1. page/mask 修正後，forced HPLL polarity 可以反轉實體響應方向。
2. 6208-step reverse bootstrap 仍不足以取得 Helper lock。
3. 下一輪應測試 isolated baseline 的 `bootstrap=0`（或明確可控的小範圍
   coarse sweep），觀察正常 tracker 能否從靜態起點找到可達工作區。
4. 若仍飽和，應先加入 ACK／physical position／獨立頻率量測，不能再盲掃 PI。

完整 build、program、preflight 與 Helper raw evidence 均保留在同資料夾 `raw/`。
