# EXP-WRPC-STEP5-STATIC-POLARITY-TELEMETRY-CLEAN-FINC-20260908

## 結論

本輪在 fresh power-cycle 後，將 Slave 的 `STEP5_BOOTSTRAP_REVERSE` 設為
`1`，以 `1024` 次 bootstrap 測試 FINC 方向；保留 normal HPLL tracker off、
既有 page/mask runtime path 與 actuator telemetry。這是前一輪 fresh-power
FDEC (`REVERSE=0`) 的乾淨反向 A/B。

FINC 方向確實執行完成，但 Helper 仍在負向飽和，沒有 Step5 lock：

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (settled preflight 4)
STEP4B = PASS (settled preflight 4)
STEP5 = NOT_PASS
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

最重要的 A/B 證據是：

```text
fresh FDEC run: FORCED_FINC=0,    FORCED_FDEC=1024
fresh FINC run: FORCED_FINC=1024, FORCED_FDEC=0
```

因此 polarity control 與完成交易方向已被證明；但兩種乾淨方向都把 Helper
留在約 `-150000`，已排除「只要把 FINC/FDEC 反相就會鎖住」的假設。

## 版本、編譯與燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`f07599d9d00c20e76af48019cbaf7b6d06688a9d`
- 唯一 functional 變因：Slave `STEP5_BOOTSTRAP_REVERSE = 1`
- `STEP5_BOOTSTRAP_STEPS = 1024`
- `ENABLE_NORMAL_HPLL_TRACKER = 0`
- Telemetry：probe 49 的 `FORCED_FINC`、`FORCED_FDEC`、`FORCED_COMPLETED`
- Firmware rebuild scripts：回傳 `1`，原因是 Pain 上既有 root-owned cache
  無法移除；firmware tree 沒有變更，因此沿用相同 MIF。這個限制已保留在
  raw log，沒有把韌體重建誤報成成功
- Master/Slave full Quartus compile：成功，Quartus Prime Standard 17.0
  Build 595
- fresh power-cycle 後燒錄順序：Master `DE5 [1-11.1]` → 45 秒 → Slave
  `DE5 [1-11.2]`
- recovery reprogram：Master → 45 秒 → Slave，用於恢復 settled upstream
- 四次 programming 均 `Configuration succeeded`、JTAG ID `0x02E660DD`、
  `0 errors, 0 warnings`

SOF SHA-256：

```text
Master 4006b6d2344c4fbedc0663b756ad0d60e2163b2ac3fde27744c40cdf2c7ec678
Slave  f247c799dffd721ea9d53b12f7862886a81002dd775780097c46d344be5c0eb8
```

Timing 尚未 closed：Master worst setup slack `-0.246 ns`、Slave
`-2.335 ns`。

## Upstream preflight

fresh power-cycle 後的 preflight 1、2 重現已知 cold-start blocker：JTAG/WB
transport health 為 PASS，但 Step4B 被 Step1 擋住。recovery 後 preflight 3
先看到 Slave `PTP=8 UNCALIBRATED`，因此該窗口的 Step2 為 INVALID；再等待
settle 後 preflight 4 成為有效窗口：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
```

本輪 Step5 判定使用 preflight 4，而不是 cold-start 或未完成校準的窗口。

## 120 秒 static Helper 觀測

觀測設定為 `1200` samples、`100 ms` cadence，完整 raw output 位於本目錄
`raw/helper-smoke-120s.log`。第一筆有效 telemetry 已顯示完整 FINC bootstrap：

```text
BOOTSTRAP_COMPLETED = 1024
BOOTSTRAP_DONE = 1
FORCED_FINC = 1024
FORCED_FDEC = 0
FORCED_COMPLETED = 1024
```

summary：

```text
SAMPLES = 1200
VALID_FRAMES = 1194
INVALID_FRAMES = 6
WINDOW_SECONDS = 119.900
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_SAMPLES = 1193
HELPER_ERROR_MEAN = -147485.331098
HELPER_ERROR_RMS = 148737.351276
HELPER_ERROR_MAX_ABS = 150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 1.67644593462
HELPER_OUTPUT_FINAL_SIGNED = 65531
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
SPLL_DELOCK_COUNT_MAX = 239
CURRENT_TICS_DELTA = 119899
NORMAL_REQ_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
DCO_STEP_DELTA = 0
FORCED_ACTIVITY_DELTA = 0
FORCED_FINC_DELTA = 0
FORCED_FDEC_DELTA = 0
FORCED_COMPLETED_16_DELTA = 0
BOOTSTRAP_DONE_FINAL = 1
NORMAL_TRANSACTION_ACCOUNTING = PASS
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

`FORCED_*_DELTA=0` 是因為 bootstrap 在正式 observer 的 before snapshot 之前
已完成；第一筆樣本與 sticky counters 已補足方向與完成證據。觀測期間沒有
normal tracker，故沒有任何新 DCO transaction 可以把 Helper 從該 operating
point 拉回 lock window。

## 解讀與下一步

前一輪 fresh FDEC 與本輪 fresh FINC 的共同結果是負向飽和，而數位完成方向
互相相反。這表示下一步不應再重複 polarity A/B，也不應先盲調 PI。較可能的
問題是：

1. bootstrap 1024 對目前的實體 operating point 太大，兩個方向都直接離開可
   用的 Helper window；或
2. runtime 寫入雖完成了 I2C transaction，仍未證明它命中了預期的 SI5340
   page/mask/N divider；或
3. Helper 的負向 rail 是啟動後的共同 baseline，需用小步數建立可觀察的
   `steps → Helper error` 曲線。

下一輪應回到 laptop source 修改，保留本輪 telemetry 與其他設定，將
`STEP5_BOOTSTRAP_STEPS` 降到受控的小範圍（優先 `128`），並以 fresh
power-cycle 觀察 bootstrap 前後的 Helper trajectory；若仍無響應，再新增
唯讀 page/mask/last-command 與 ACK/readback evidence，而不是繼續調 PI。

## 正式狀態

```text
STEP4B = PASS
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

完整 compile、program、preflight、120 秒 observer 與 raw evidence 均保留於
本目錄；遠端原始資料封存於 `raw/EXP-WRPC-STEP5-STATIC-POLARITY-TELEMETRY-CLEAN-FINC-20260908.tar.gz`。
