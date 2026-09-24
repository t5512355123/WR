# EXP-WRPC-STEP5-STATIC-BOOTSTRAP-128-FINC-20260908

## 結論

本輪在 fresh power-cycle 後，將 Slave 的 `STEP5_BOOTSTRAP_STEPS` 從 `1024`
降至 `128`，保留 `STEP5_BOOTSTRAP_REVERSE=1`（FINC）、normal HPLL tracker
off、既有 page/mask runtime path 與 actuator telemetry。目的為確認 1024
是否只是一次把 operating point 推過 Helper 可用窗口。

結果仍然沒有 Step5 lock，而且 Helper 從觀測開始到結束都在負向 rail：

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

這輪排除了「1024 steps 太大」作為主要解釋：128-step FINC 仍完整執行，
但 Helper 沒有任何可觀察的持續位移。結合前一輪 fresh FDEC/FINC 1024 的
共同負向飽和，目前最可能的問題已是 I2C transaction provenance、預期的
SI5340 page/mask/N divider 命中情況，或 Helper 輸出與實際 actuator response
之間的介面，而不是單純 polarity 或 bootstrap 步數。

## 版本、編譯與燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`febbd515c0605676acfed5be6ddbcab7634121a7`
- 唯一 functional 變因：Slave `STEP5_BOOTSTRAP_STEPS = 128`
- `STEP5_BOOTSTRAP_REVERSE = 1`（FINC）
- `ENABLE_NORMAL_HPLL_TRACKER = 0`
- Telemetry：probe 49 的 `FORCED_FINC`、`FORCED_FDEC`、`FORCED_COMPLETED`
- Firmware rebuild scripts：回傳 `1`，原因是 Pain 上既有 root-owned cache
  無法移除；firmware tree 沒有變更，因此沿用相同 MIF。完整錯誤留在
  `raw/firmware-*.log`，沒有將 firmware rebuild 誤報為成功
- Master/Slave full Quartus compile：成功，Quartus Prime Standard 17.0
  Build 595
- fresh power-cycle 後燒錄順序：Master `DE5 [1-11.1]` → 45 秒 → Slave
  `DE5 [1-11.2]`
- recovery reprogram：Master → 45 秒 → Slave，用於恢復 settled upstream
- 四次 programming 均 `Configuration succeeded`、JTAG ID `0x02E660DD`、
  `0 errors, 0 warnings`

SOF SHA-256：

```text
Master 0bad8943f4fed1a4200648ab3ceab3af53cad2fdd99ed65fac5ab3a4962a6297
Slave  cb5abfddf60d9b791025c52cfe45ff9e559b0c5cd7751d056d0a682f48a7fcb5
```

Timing 尚未 closed：Master worst setup slack `-0.246 ns`、Slave
`-0.002 ns`。

## Upstream preflight

fresh power-cycle 後 preflight 1、2 重現 cold-start upstream blocker；JTAG/WB
transport 本身仍為 trusted。recovery 後 preflight 3 的 Slave 先處於
`PTP=8 UNCALIBRATED`，所以該窗口的 Step2 為 INVALID；再等待 settle 後
preflight 4 成為有效的 Step4B 窗口：

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

Step5 判定只使用 preflight 4 與其後的 observer，不使用 cold-start 或未完成
校準的窗口。

## 120 秒 static Helper 觀測

觀測設定為 `1200` samples、`100 ms` cadence。第一筆有效樣本已證明 128 次
FINC transaction 完成：

```text
BOOTSTRAP_COMPLETED = 128
BOOTSTRAP_DONE = 1
FORCED_FINC = 128
FORCED_FDEC = 0
FORCED_COMPLETED = 128
```

summary：

```text
SAMPLES = 1200
VALID_FRAMES = 1200
INVALID_FRAMES = 0
WINDOW_SECONDS = 119.900
HELPER_LOCK_COUNT_MAX = 0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_SAMPLES = 1200
HELPER_ERROR_MEAN = -150000.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 0.0
HELPER_OUTPUT_FINAL_SIGNED = 65531
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
SPLL_DELOCK_COUNT_MAX = 0
CURRENT_TICS_DELTA = 119900
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

`FORCED_*_DELTA=0` 是因為 bootstrap 在 observer 的 before snapshot 之前已經
完成；第一筆 sample 的 sticky counters 已補足完成方向與步數證據。觀測期間
沒有 normal tracker，因此沒有其他 transaction 把 Helper 從該 operating point
拉回 lock window。

## 解讀與下一步

目前三種 isolated static 結果（無 bootstrap、fresh FDEC 1024、fresh FINC
1024）以及本輪 fresh FINC 128 都沒有形成 Helper lock。方向 counter 都正確，
但小步數與大步數的 Helper 結果都落在相同負向 rail，故下一輪不應再盲掃
`128/1024` 或調 PI。

下一輪回到 laptop source 修改，加入唯讀的 transaction provenance telemetry，
至少要能在 probe 中保存並由報告核對：

1. 最後一次 runtime page write 的 page value；
2. mask write 的完整 page/offset/data（預期完整位址 `0x0339`）；
3. FINC/FDEC final command 的 page/offset/data（預期 `0x001D`）；
4. I2C controller 的 ACK/error 狀態與完成計數；
5. page restore 與 final command 的順序，且不能把 NACK/timeout 計為完成。

這是為了區分「FPGA FSM 完成四筆 transaction」與「SI5340 實際接受正確
寄存器命令」。在該證據完成前，不應再宣稱物理 actuator 已被改變，也不應
把任何新結果標成 Step5 PASS。

## 正式狀態

```text
STEP4B = PASS
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

完整 compile、program、preflight、120 秒 observer 與 raw evidence 均保留於
本目錄；遠端原始資料封存於
`raw/EXP-WRPC-STEP5-STATIC-BOOTSTRAP-128-FINC-20260908.tar.gz`。
