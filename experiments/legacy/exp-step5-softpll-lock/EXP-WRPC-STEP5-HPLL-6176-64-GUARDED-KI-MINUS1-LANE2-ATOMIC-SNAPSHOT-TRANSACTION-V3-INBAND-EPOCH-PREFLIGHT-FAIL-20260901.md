# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-ATOMIC-SNAPSHOT-TRANSACTION-V3-INBAND-EPOCH-PREFLIGHT-FAIL-20260901

## 實驗目的

依分支5-WR 最新建議，驗證 V3 in-band PI snapshot epoch transport 是否能在進入 Step5 smoke 前提供乾淨的 runtime preflight。V3 只改 diagnostic transport：以 `PI_TRACE_EPOCH = 2*N`（發布中為 odd、完成後為 even）攜帶 request generation；不再以 `BANK_SEQ` 判斷 frame validity。

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

本輪未修改 PI equation、DMTD、tracker、P_ADDER/P_SETPOINT、FINC/FDEC、Main PLL、sequencer、reset tree 或任何 PHY 設定。

## Source / build / program provenance

```text
BRANCH = exp/step5-softpll-lock
SOURCE_HEAD = 493b54b757cb0473e1c0e070f6db3ee7ad9852fa
SOURCE_COMMIT = exp: use in-band PI snapshot epoch v3

MASTER_MIF_SHA256 = 113964ac258776c3ba1cef0792302b2eb144c7e3592c3f2bc8b90472426cc648
SLAVE_MIF_SHA256 = ed33c95cb9ab869837e7bb1170570263ac7229c81a8a022ccd4bdabd564d0440
MASTER_SOF_SHA256 = 20aa11ea54ae90fe1910cde93616569823f660e89a4c26d36b8d62c100cfb381
SLAVE_SOF_SHA256 = 22b89090c20a50c2148256ef9178b12ed98aed4951f6b53741beee776880b852
```

Master/Slave firmware MIF 均重新產生，兩個 Quartus JTAG project 均 clean full compile 成功；timing 仍保留既有 `TIMING_CLOSED=NO` caveat。兩張 DE5a 也都完成 programming，Quartus Programmer 回報 0 errors、0 warnings、1 device configured。

## Fresh-program preflight 結果

重新燒錄後等待 30 秒，連續執行兩次 `read_wb_runtime.tcl --raw`。兩次 Slave 結果一致：

```text
core_tm_link_up = 0/1
core_link_ok = 0/1
wr_rx_ready = 1
wr_tx_ready = 1
wr_rx_locked_to_data = 1
wr_rx_enc_err = 0
WDIAGS_PTP = 6 MASTER / expected 9 SLAVE
WDIAGS_PTP_RX delta = 0
WDIAGS_PTP_TX delta = 0
WDIAGS_RXERR delta = 0
STEP1_REGRESSION = FAIL
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
FAILURE_CLASSIFICATION = JTAG/DASHBOARD_MEASUREMENT_FAILURE
```

因此這不是 V3 snapshot validity 結果；上游 optical/PHY link 尚未 ready，V3 100-sample smoke 沒有正式執行，亦沒有執行 1800 秒 Step5 observer。

此前在較早一次已穩定同步的觀測窗曾取得 `Step1/2/3/Step4B=PASS`，但本次 fresh-program 後的兩次 revalidation 無法重現，故不得把 Step4B 宣稱為本次 fresh-program PASS。

## 正式判定

```text
V3_FRESH_PROGRAM = PASS
V3_PREFLIGHT = FAIL
STEP4B_BASELINE_STATUS = YES
STEP4B_REVALIDATED_BY_CURRENT_FRESH_PROGRAM = NO
V3_ATOMIC_SNAPSHOT_SMOKE = NOT_RUN
EXPERIMENT_VALID_FOR_STEP5 = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 下一步

先只更換 Master↔Slave optical fiber 為已知良品，確認 `PHYSICAL_CHANGE_CONFIRMED=YES` 且 SFP、板卡、firmware 不變；再做 300 秒 JTAG-quiet 與 300 秒 dashboard attribution。兩段都必須 `MINIC_RXERR`、PHY encoding/disparity/errdetect/sync-loss/lock-loss 與 link-drop delta 全為 0，且 PTP 維持 SLAVE，才可重新取得三次 clean preflight，之後再重跑 V3 100-sample smoke。

在實體鏈路恢復前，不調 PI，不改 bootstrap，不跑 1800 秒，不 merge `main`。
