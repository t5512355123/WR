# EXP-WRPC-STEP5-HPLL-PLANT-ID-5632-20260909

## 結論

本輪依 Astra A4 建議建立隔離的 HPLL plant-test image：Slave 完成 coarse
bootstrap=5632 後，停用 normal Helper→HPLL tracker，只接受外部受控 FINC/FDEC
階躍。有效 preflight 在重新安排 programming order 後通過，雙向 actuator
accounting 也通過；4096-step 階躍直接量到兩個方向對 `FREQ_ERROR` 的相反即時
響應。Step5 本輪不是 lock 實驗，但已找出 normal tracker 的方向映射錯誤。

```text
SOURCE_COMMIT = e5578a06bc50833167fe620b911b642f35a5f740
STEP1_TO_STEP3 = PASS (preflight 3)
STEP4B = PASS (preflight 3)
A4_PLANT_IDENTIFICATION = PASS
STEP5 = NOT_APPLICABLE_FOR_PLANT_TEST
NORMAL_TRACKER_DIRECTION_MAPPING = PROVEN_WRONG
MERGE_APPROVED = NO
```

## 本輪設定

```text
ENABLE_STEP5_HPLL_PLANT_TEST = 1 (Slave)
ENABLE_STEP5_BOOTSTRAP = 1 (Slave)
STEP5_BOOTSTRAP_STEPS = 5632
ENABLE_NORMAL_HPLL_TRACKER = 1, but normal admission held by plant-test mode
HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 64
DPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 16
```

plant-test mode 的目的，是讓 coarse bootstrap 先建立同樣的 physical origin，
再禁止 normal HPLL request；因此之後的 FINC/FDEC burst 可以獨立量測，不會被
Helper PI 的 target stream 混入。

## 編譯、燒錄與 upstream gate

Pain 已從 GitHub 拉取 `e5578a0`。Master/Slave firmware 與完整 Quartus fit 均
成功，timing 仍未 closed。第一次使用 Slave→Master programming 時，preflight
1、2 顯示兩端尚未建立 link，且 Slave 暫時停在 MASTER/LISTENING；重新以
Master→Slave 載入同一組 SOF 後，preflight 3 成為有效窗口：

```text
MASTER_SOF_SHA256 = 8fa94b336b7e33841fafdea69d420578cda8ae2e39d35a28daf8f159ad8e4a08
SLAVE_SOF_SHA256  = b34041dde355a951521f8469a0c163cf99cc0beba82c3dde30d65dac00660e35
TIMING_CLOSED = NO
PROGRAM_ORDER_VALID_WINDOW = MASTER_THEN_SLAVE

Master core_tm_link_up/core_link_ok = 1/1
Slave  core_tm_link_up/core_link_ok = 1/1
Master PTP = MASTER, PTP_RX/PTP_TX delta > 0
Slave  PTP = SLAVE, PTP_RX/PTP_TX delta > 0
Slave  WR_RX_SIGNAL = LOCK
Slave  LOCK_ENABLE_COUNT = 4
Slave  SPLL_INIT_COUNT = 1
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_RESULT = PASS
STEP5_RESULT = NEVER_LOCKED
```

前兩次 preflight 的失敗是 startup/order evidence，不能當成 A4 plant result；
有效量測使用 preflight 3 的 recovered window。

## 雙向 actuator response

### 128-step sanity run

兩個方向各完成 128 個 forced transaction，且 normal tracker request 為零、
reset 與 RX error 均穩定。小階躍受 phase drift 影響，不能單獨判斷方向：

```text
FINC_COUNT = 128
FDEC_COUNT = 128
ACTUATOR_ACCOUNTING = PASS
NORMAL_REQUEST_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
RESET_*_DELTA = 0
FINC_FREQUENCY_ERROR_IMMEDIATE_DELTA = -1
FDEC_FREQUENCY_ERROR_IMMEDIATE_DELTA = -26
```

### 4096-step decisive run

同一個已燒錄 image 上，各方向施加 4096 個 physical transactions。burst
completion 與方向 counter 完整吻合：

```text
FINC_COUNT = 4096
FDEC_COUNT = 4096
ACTUATOR_ACCOUNTING = PASS
NORMAL_REQUEST_DELTA = 0
NORMAL_COMPLETED_DELTA = 0
RXERR_DELTA = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

最有用的是 burst 完成後的即時 frequency response：

```text
FINC: FREQ_ERROR -2391 -> -1505, delta = +886
FDEC: FREQ_ERROR -1515 -> -2405, delta = -890
```

因此在目前方向編碼下：

```text
FINC = increases FREQ_ERROR
FDEC = decreases FREQ_ERROR
```

腳本的 5 秒 settled delta 受到「plant-test 不回授」時的 phase drift 污染，
所以 `DIRECTION_RESPONSE=SAME_SIGN` 不能覆蓋上述 immediate response；真正的
方向證據是 burst completion 後立即讀到的 `+886/-890`。

## PI trace 限制

`read_step5_helper_pi_state_rail_audit.tcl` 的 200-sample run 成功完成 request、
ack、雙讀與 frozen-bank word matching，但它把每筆 frame 判為 invalid：

```text
SNAPSHOT_REQ_COUNT = 200
SNAPSHOT_ACK_COUNT = 200
FROZEN_BANK_READ_STABILITY = PASS
PI_TRACE_PRESENT = 0
VALID_FRAMES = 0
INVALID_FRAMES = 200
```

因此本輪不把該腳本輸出的 PI summary 當成正式 lock/PI 數值證據；這是下一輪
應修正的 observability semantic mismatch。A4 的 plant 方向結論不依賴 PI trace，
而依賴獨立的 forced completion accounting 與 4096-step immediate response。

## 判定與下一步

本輪不能宣稱 Step5 PASS，也不能 merge。已取得足以進行下一個最小功能修正的
證據：目前 normal HPLL tracker 使用「target 增加→FDEC、target 減少→FINC」；
但 plant 實測顯示負的 frequency error 必須用 FINC 才能往零移動。因此下一輪：

1. 將 normal HPLL target/applied residual 的方向映射改為：target 增加→FINC，
   target 減少→FDEC；
2. 同步修正 virtual applied-position 的完成記帳，使 FINC 對應 applied code
   增加、FDEC 對應 applied code 減少；
3. 保留 page/mask sequence、Main absolute tracker、bootstrap=5632 與
   HPLL step=64；
4. 重新完整編譯、燒錄，先驗證 Step1–4B，再以 coherent observer 檢查 Helper
   是否離開 rail 並進入 `|helper_error| <= 200` 的 lock window。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

本資料夾 `raw/` 保存：

- `preflight-1.log`、`preflight-2.log`、`preflight-3.log`
- `bidir-128.log`、`bidir-4096.log`
- `pi-audit-200.log`
- `program-master.log`、`program-slave.log`
- `program-master-recovery.log`、`program-slave-recovery.log`
- `compile-master.log`、`compile-slave.log`
- `firmware-master.log`、`firmware-slave.log`
- `sof-sha256.txt`
