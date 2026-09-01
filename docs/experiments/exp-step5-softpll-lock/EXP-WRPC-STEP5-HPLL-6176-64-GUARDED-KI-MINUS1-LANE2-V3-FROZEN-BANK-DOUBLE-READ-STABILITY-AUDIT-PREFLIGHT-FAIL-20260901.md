# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V3-FROZEN-BANK-DOUBLE-READ-STABILITY-AUDIT-PREFLIGHT-FAIL-20260901

## 實驗目的

依分支5-WR 最新建議，執行 frozen-bank double-read stability audit 前的 runtime preflight，確認兩張 DE5a 是否已通過 Step1–3 gate。只有在 Slave 上游鏈路 ready、Step4B 被允許後，才可執行 100-sample V3 double-read 實驗。

## 固定控制條件

```text
QSFPA data path = lane 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

本輪只新增 diagnostic observer：同一個 serialized snapshot request 之下，對同一個 frozen bank 連續讀取 Pass A 與 Pass B 並逐 word 比對。未修改 firmware、PI equation、DMTD、tracker、P_ADDER/P_SETPOINT、FINC/FDEC、Main PLL、sequencer、reset tree、PHY 或參數。

## Source / build / program provenance

```text
BRANCH = exp/step5-softpll-lock
SOURCE_HEAD = ac6b389626666cca97e731299880c85dee681d9f
SOURCE_COMMIT = diag: add frozen bank double read audit
```

Master 與 Slave 均完成 clean full compile，並完成 programming；兩張 DE5a 均回報 1 device configured、0 errors。timing 仍保留既有 `TIMING_CLOSED=NO` caveat。

```text
MASTER_SOF_SHA256 = ce400592f498efe98a8a45aa6630ca2379c17ef637c3e6be44376c24c3db16aa
SLAVE_SOF_SHA256 = 292bc51a9ad08fa5575126a42ba11e67771aaa1faaca47b74ebb681984abd016
MASTER_WORST_SETUP_SLACK_NS = -0.050
MASTER_WORST_HOLD_SLACK_NS = 0.039
SLAVE_WORST_SETUP_SLACK_NS = -0.211
SLAVE_WORST_HOLD_SLACK_NS = 0.036
```

## Fresh-program preflight 結果

重新 programming 後，先等待，再以 `read_wb_runtime.tcl --raw` 進行多個間隔觀測；結果沒有恢復成 clean Step1–3 gate。

Master `DE5 [1-11.1]`：

```text
si_config_done = 1
wr_ready = 1
wr_rx_ready = 1
wr_tx_ready = 1
wr_rx_locked_to_data = 1
wr_rx_enc_err = 0
wr_tx_enc_err = 0
core_tm_link_up = 0/1
core_link_ok = 0/1
WDIAGS_PTP = MASTER
WDIAGS_PTP_RX delta = 0
WDIAGS_PTP_TX delta > 0
STEP4A_MASTER_EVENT_CHAIN = PASS
```

Slave `DE5 [1-11.2]`：

```text
si_config_done = 1
wr_ready = 1
wr_rx_ready = 1
wr_tx_ready = 1
wr_rx_locked_to_data = 1
wr_rx_enc_err = 0
wr_tx_enc_err = 0
core_tm_link_up = 0/1
core_link_ok = 0/1
WDIAGS_MODE = SLAVE
WDIAGS_PTP = LISTENING (raw=00004104)
WDIAGS_PTP_RX delta = 0
WDIAGS_PTP_TX delta > 0
WDIAGS_FOREIGN_META = 0
LOCK_ENABLE = 0
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
```

兩端的 PHY data lock 已存在且沒有 encoding error 或 reset 增量，但 WR core timing/link gate 沒有成立；Slave 沒有收到 PTP，因此沒有進入 `locking_enable()`、SoftPLL startup 或 Step5 observer。間隔重測仍得到相同 boundary，故不能把這一輪解讀成 frozen-bank read mismatch 或 PI math failure。

## 本輪實驗判定

```text
FROZEN_BANK_DOUBLE_READ = NOT_RUN
FROZEN_BANK_READ_STABILITY = NOT_APPLICABLE
EXPERIMENT_VALID_FOR_STEP5 = NO
STEP4B_REVALIDATED_BY_CURRENT_FRESH_PROGRAM = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 下一步請分支5-WR 判斷

目前應先處理或驗證 `core_tm_link_up/core_link_ok` 及 Slave PTP RX/parent handshake 的上游 gate；在此 gate 恢復前，不執行 double-read、PI 修改、1800 秒 lock run，也不 merge 到 `main`。請分支5依本紀錄判斷下一個最小實驗。
