# EXP-WRPC-STEP5-ISOLATED-REVERSE-PERSISTENT-1024-20260908

## 結論

本輪修正 bootstrap polarity 狀態傳遞，並將 Slave bootstrap 設為受控的
`1024` steps、reverse polarity。修正前只有第一筆 bootstrap request 使用
`STEP5_BOOTSTRAP_REVERSE`，後續 request 會被清成正向；因此前一輪的
6208-step reverse 結果不能視為真正 reverse sweep。

本輪完成真正一致方向的 1024-step reverse bootstrap。可信 settled preflight
2–3 的 Step1–3 與 Step4B 全部 PASS；Helper error 在觀測期間確實穿越正負端，
證明 actuator 的方向與 operating-point bracket 可被掃到，但 normal tracker
同時持續追蹤，最後把輸出推回 rail，仍沒有形成 Helper lock。

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (settled preflight 2–3)
STEP4B = PASS (settled preflight 2–3)
STEP5 = NOT_PASS
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

## 版本、變更與編譯燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`b4af1b63328064fe644dcf11e8c9e5dac8df7536`
- Source change 1：bootstrap 後續 queued request 持續使用
  `STEP5_BOOTSTRAP_REVERSE`
- Source change 2：Slave `STEP5_BOOTSTRAP_STEPS = 1024`
- Slave `STEP5_BOOTSTRAP_REVERSE = 1`
- Slave `HPLL_TRACKER_CODE_PER_PHYSICAL_STEP = 16`
- 編譯：pain，Quartus Prime Standard 17.0.0 Build 595；firmware 與 full
  Quartus 均成功。第一次以 sudo 執行被 pain license 環境擋下，改用 pain
  登入帳號後完整 compile 成功，未使用舊 SOF 代替。
- 燒錄順序：Master `DE5 [1-11.1]` → 等待 46 秒 → Slave `DE5 [1-11.2]`
- 兩板 Programmer：JTAG ID `0x02E660DD`，configuration succeeded，0 errors、
  0 warnings

SOF SHA-256：

```text
Master 7e5fab791c52403b88e92c5f0322a54886273d58a78f46c5f20b657fa444c2fc
Slave  578da7f970deb59c0d882bfe5db921634b8ece27311539b5373d8c213fce0b22
```

Timing 尚未 closed：Master worst setup slack `-0.246 ns`、Slave `-0.221 ns`。

## Settled preflight

燒錄後第一個窗口是已知 startup transient；preflight 1 的 Slave Step2 尚未
穩定。等待後 preflight 2 與 3 均通過：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
```

## 120 秒 Helper 觀測

Slave 執行 1200 samples、100 ms gap；完整 raw output 在 `raw/`：

```text
SAMPLES = 1200
VALID_FRAMES = 1200
INVALID_FRAMES = 0
WINDOW_SECONDS = 119.901
HELPER_LOCK_COUNT_MAX = 100
HELPER_LOCK_COUNT_FINAL = 100
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_MEAN = -39132.3266667
HELPER_ERROR_RMS = 140865.862331
HELPER_ERROR_MAX_ABS = 150000
HELPER_ERROR_FRACTION_ABS_LE_THRESHOLD = 0.0
HELPER_OUTPUT_RAIL5_FRACTION = 23.75
HELPER_ERROR_PLUS150000_FRACTION = 27.5
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
NORMAL_REQ_DELTA = 22525
NORMAL_COMPLETED_DELTA = 22525
DCO_STEP_DELTA = 22525
FORCED_ACTIVITY_DELTA = 0
BOOTSTRAP_COMPLETED_DELTA = 0
BOOTSTRAP_DONE_FINAL = 1
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS
```

Bootstrap telemetry reached `BOOTSTRAP_COMPLETED=1024` and `BOOTSTRAP_DONE=1`.
During the late observation window, representative samples were:

```text
HELPER_ERROR = +150000, HELPER_OUTPUT = 5
HELPER_ERROR =  +80524, HELPER_OUTPUT = 8
HELPER_ERROR =  +10422, HELPER_OUTPUT = 1345
HELPER_ERROR =  -68029, HELPER_OUTPUT = 9754
HELPER_ERROR = -150000, HELPER_OUTPUT = 65531
```

這個正負穿越是本輪最重要的進展：它支持「真正 reverse polarity 已生效，
且 1024 steps 進入可達 bracket 附近」；但因為 normal tracker 沒有被隔離，
它在同一觀測窗又完成 22525 次 normal steps，故不能把短暫穿越誤判為 lock。
`HELPER_LOCK_COUNT_MAX=100` 也低於 threshold `200`，且 `HELPER_LOCKED=0`，
所以不存在短暫 Step5 PASS。

## Step5 判定與下一步

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

下一輪應只把 `ENABLE_NORMAL_HPLL_TRACKER` 暫時設為 `0`，保留目前 page/mask
fix、真正 persistent reverse polarity 與 `1024` bootstrap，做 isolated static
operating-point 觀測。若 error 在無 normal tracker 時停在 lock window，便可把
該 position 當成 Step5 startup seed；若仍飽和，則沿 `0/512/1024/1536` 做受控
coarse bracket。這一步能分離「actuator 工作點」與「absolute target/applied
tracker 語意」，再決定是否修正 applied-position accounting 或重新啟用細步
閉迴路。

完整 build、program、preflight、Helper 120 秒觀測與 raw evidence 均保留在
`raw/`（遠端封存 tar SHA-256：
`eb1551e8a7a004cd728424e178e4f95d5acfbd94c694ce87e65051d3bb60ab80`）。
