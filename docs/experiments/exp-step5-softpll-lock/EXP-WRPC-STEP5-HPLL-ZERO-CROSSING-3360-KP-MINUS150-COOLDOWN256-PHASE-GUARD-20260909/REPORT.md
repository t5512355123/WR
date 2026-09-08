# EXP-WRPC-STEP5-HPLL-ZERO-CROSSING-3360-KP-MINUS150-COOLDOWN256-PHASE-GUARD-20260909

## 判定

本輪 source 已完成編譯與燒錄，但兩張 DE5a 在觀測期間沒有建立 WR
upstream/link，因此 Slave 的 Step4B 被 Step1 擋住，Step5 observer 沒有
啟動。這不是 Step5 pass，也不是 cooldown 動態的有效 A/B 結果；本輪結果為
`UPSTREAM_BLOCKED`，不能 merge。

```text
STEP5_RESULT = UPSTREAM_NOT_READY
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_CHAIN_RESULT = NOT_TESTED
MERGE_APPROVED = NO
```

## 實驗目的與 source 變更

本輪恢復最後一個已知可進入 fine loop、且 position accounting 通過的基線，並
加入最小的 normal-DCO rate-limit A/B：

```text
Helper PI: kp=-150, ki=-1
Slave HPLL_TRACKER_CODE_PER_PHYSICAL_STEP: 64
Slave STEP5_BOOTSTRAP_STEPS: 3360
Slave STEP5_BOOTSTRAP_REVERSE: 1
Slave STEP5_NORMAL_HPLL_COOLDOWN_LOADS: 256
Helper phase guard: 60 seconds
```

`STEP5_NORMAL_HPLL_COOLDOWN_LOADS=256` 的語意是：每次 normal HPLL physical
transaction 完成後，必須再收到 256 次 accepted Helper target load，才允許
下一個 normal transaction。Master 維持預設 `0`；lock threshold 與 lock
sample count 沒有修改。

Source commit:

```text
50f1f1db28a83cc22df8ff327659d7e46872c3ec
```

## Build / program

Pain 從上述 commit 的乾淨 detached worktree 完整編譯 Master 與 Slave，兩者
均成功；直接 JTAG programming 也均成功，0 errors、0 warnings。

```text
MASTER_COMPILE_RESULT = PASS
SLAVE_COMPILE_RESULT = PASS
MASTER_PROGRAM_RESULT = PASS
SLAVE_PROGRAM_RESULT = PASS
MASTER_SOF_SHA256 = 5a1397708f7622bd00e23bd02e5dbe2c3220fe13bf999d1555dff8a62d140340
SLAVE_SOF_SHA256 = 5cfb0622bce413b68fbef2905767b4da6a1959647a92c918ee15057f25589a92
TIMING_CLOSED = NO
```

## Preflight observation

燒錄後等待並執行第一次 preflight；再等待約一分鐘後執行第二次
`preflight-retry`。兩次結果一致：

```text
Master:
  si_config_done=1, wr_ready=1, wr_rx_ready=1, wr_tx_ready=1
  core_tm_link_up=0, core_link_ok=0
  STEP4A_MASTER_EVENT_CHAIN=PASS

Slave:
  si_config_done=1, wr_ready=1, wr_rx_ready=1, wr_tx_ready=1
  core_tm_link_up=0, core_link_ok=0
  WDIAGS_PTP=LISTENING (first window)
  parentIsWRnode=0
  STEP4B_ALLOWED=NO
  STEP4B_RESULT=BLOCKED_BY_STEP1
  STEP4B_FIRST_INACTIVE_BOUNDARY=UPSTREAM_PREREQUISITE
  STEP5_RESULT=UPSTREAM_NOT_READY
```

第二次 preflight 的 Slave PTP 狀態仍未達到可用 upstream；Master 仍可產生
Step4A event chain，但 `core_link_ok` 沒有變成 1。因此本輪沒有執行
3600-sample closed-loop trajectory audit，也沒有任何 `HELPER_LOCKED`、
`MAIN_FREQ_LOCKED` 或 `PSTAT_LOCKED` 的 Step5 證據。

## Power-cycle safety result

因為 link 在重試後仍未建立，依已授權的 Pain power-cycle 流程進行安全檢查。
Edge taskbar icon 辨識成功，但 Pain 的「開啟」控制項信心分數只有
`0.4244053359`，低於必要的 `0.820`；流程在任何 power-control click
之前停止，沒有猜座標、沒有重試、沒有操作其他控制。詳細原始記錄見
`raw/pain-power-cycle-safety-stop.txt`。

因此本輪無法安全完成必要的 cold/warm recovery A/B；這是硬體 upstream
狀態的 blocking condition，不應被解讀成 cooldown 失效。

## 下一步

先讓 Pain 控制頁重新顯示可辨識的「開啟」控制，完成一次安全實體
power-cycle，確認 SSH 恢復後再從相同 commit 重新燒錄並重跑 preflight。
只有當 `core_link_ok=1`、Slave Step4B gate 通過後，才執行 3600-sample
observer 來評估 cooldown256 是否改善 actuator hunting；不改用 blocked
窗口宣稱 Step5。

## Raw evidence

本輪 Pain 原始檔案位於 `raw/`。原始封存檔 SHA-256：

```text
34229126b880bf5fdbfa847e287a718074804a6a46fdec8d86fd04737af3defc
```
