# EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB-20260830

## 判定

```text
STEP4B_SLAVE_SOFTPLL_STARTUP       = PASS
JTAG_TRIGGERED_ONE_STEP_CAUSAL_PATH = PASS
ACTUATOR_TO_MEASUREMENT_COUPLING   = NOT RESOLVED
STEP5_CLOSED_LOOP_LOCK             = NOT PASS
MERGE_APPROVED                      = NO
```

本輪依分支5的建議，將前一輪會在 startup 自動觸發的 same-code test 改為 JTAG-controlled trigger。先取得 baseline，再送出一次 `FORCE_HPLL_ONE_STEP: 0→1→0`，並用 sticky counters 保留不會被 1 秒 reader 漏掉的事件。

## 實驗設定

```text
branch       = exp/step5-softpll-lock
image_commit = 423717cee14a7e6ad6b9b0f932cc9015ad7be8aa
experiment   = EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB
programming  = paired fresh-program, Master then Slave
A window     = source low, 10 seconds
B window     = trigger baseline, one pulse, 20 seconds
```

新的 Slave image 使用 dedicated `altsource_probe` source bit；Master 沒有該 probe 且將 force input 綁定為 0。Slave 的 automatic same-code trigger 已停用。JTAG source rising edge 在 ready/idle boundary 只允許一次 HPLL pending admission，方向沿用既有 `hpll_dir`。

## Build / flash identity

兩個 image 都以 `423717c` 完整編譯並成功燒錄：

```text
Master SOF SHA256 = 56c4a8b137aaeb77965774a6f0e800b352a59b045f1d1f7881732fbf5c2262a3
Slave  SOF SHA256 = e4118dcfd728f65dc27bd9632f924c7ed4e7f209a85e7c4d60a425adaf949f29

Master TIMING_CLOSED = NO, WNS = -0.195 ns
Slave  TIMING_CLOSED = NO, WNS = -0.463 ns
```

Timing 尚未 closed 是 implementation caveat，不影響本輪對 JTAG event path 的功能判定。

## A 組：source=0 baseline

`FORCE_TRIGGER_COUNT` 全程為 0，`FORCED_PENDING_COUNT` 全程為 0。A0 snapshot：

```text
STEP                 = 236
HELPER_ERROR_SIGNED  = -150000
RT_STATE_ENTER_COUNT = 236
RUNTIME_START_COUNT  = 196
BUS_DONE_COUNT       = 57
```

A10 snapshot：

```text
STEP                 = 476
HELPER_ERROR_SIGNED  = -150000
FORCE_TRIGGER_COUNT  = 0
FORCED_PENDING_COUNT = 0
```

因此 A 長窗口發生了 240 個背景 DCO steps；它不能被當成「整個 image 在未 trigger 時完全 quiescent」的證據。這些背景活動發生時 force counter 仍為 0，故不屬於 JTAG trigger event。B 的因果判定只採用 trigger 前後的 immediate pair，不把後續背景活動混入。

## B 組：JTAG single pulse

### Trigger 前 baseline

```text
tag                  = B_BEFORE
STEP                 = 476
HELPER_ERROR_SIGNED  = -150000
FORCE_TRIGGER_COUNT  = 0
FORCED_PENDING_COUNT = 0
RT_STATE_ENTER_COUNT = 220
RUNTIME_START_COUNT  = 148
BUS_DONE_COUNT       = 9
FORCE_SEEN           = 0
HPLL_PENDING         = 0
HPLL_PREV_VALID      = 1
STATIC_READY         = 1
```

### Trigger 後第一個 observer sample

```text
tag                  = B01
STEP                 = 477
HELPER_ERROR_SIGNED  = -150000
FORCE_TRIGGER_COUNT  = 1
FORCED_PENDING_COUNT = 1
RT_STATE_ENTER_COUNT = 221
RUNTIME_START_COUNT  = 151
BUS_DONE_COUNT       = 12
FORCE_SEEN           = 1
HPLL_PENDING         = 0
HPLL_PREV_VALID      = 1
STATIC_READY         = 1
```

直接 before/after delta：

| Signal | B_BEFORE | B01 | Delta |
|---|---:|---:|---:|
| `FORCE_TRIGGER_COUNT` | 0 | 1 | **+1** |
| `FORCED_PENDING_COUNT` | 0 | 1 | **+1** |
| `RT_STATE_ENTER_COUNT` | 220 | 221 | **+1** |
| `RUNTIME_START_COUNT` | 148 | 151 | **+3** |
| `BUS_DONE_COUNT` | 9 | 12 | **+3** |
| `STEP` | 476 | 477 | **+1** |
| `HELPER_ERROR_SIGNED` | -150000 | -150000 | 0 |

這符合分支5定義的 acceptance criterion：

```text
JTAG trigger       → +1 force trigger
                   → +1 forced pending
                   → +1 runtime state entry
                   → +3 runtime starts
                   → +3 bus completions
                   → exactly +1 completed DCO step
```

所以可以正式判定：

```text
JTAG_TRIGGERED_ONE_STEP_CAUSAL_PATH = PASS
```

單一 FINC/FDEC step 沒有讓 helper error 在此觀測尺度改變，符合 branch5 預先允許的 Case 2；這代表 actuator-to-measurement coupling 尚未解析，不代表 pending-to-step path 失敗。

## Step5 lock 結果

同一 paired image 的 `dashboard-after` 顯示：

```text
Master: Step1 PASS, Step2 PASS, Step4A PASS
Slave : Step1 PASS, Step2 PASS, Step3 PASS, Step4B PASS
Slave : HELPER locked=0, cnt=1/10000, threshold=200
        MAIN enabled=0, locked=0
        PSTAT_locked=0
        STEP5_RESULT=NEVER_LOCKED
        STEP5_FIRST_INACTIVE_BOUNDARY=HELPER_LOCK
```

helper error/output 仍為：

```text
spll_helper_error  = 0xFFFDB610 = -150000
spll_helper_output = 0xFFFB     = absolute DAC code
```

因此本輪只完成「手動 trigger 到一次 DCO step」的 causal sub-milestone，沒有完成 Helper lock，更沒有完成 Main frequency/phase lock 或 `PSTAT.locked=1`。Step5 仍是 `NOT PASS`，不得 merge。

## Raw data

- `raw/EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB-20260830/jtag-triggered-one-step-ab.log`
- `raw/EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB-20260830/dashboard-after.log`
- `raw/EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB-20260830/build_info_jtag_master.txt`
- `raw/EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB-20260830/build_info_jtag_slave.txt`
- `raw/EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB-20260830/quartus_jtag_master_compile.log`
- `raw/EXP-WRPC-STEP5-JTAG-TRIGGERED-HPLL-ONE-STEP-AB-20260830/quartus_jtag_slave_compile.log`

主要 reader 已更新為在 trigger 後第一筆 sample 直接輸出 `B_BEFORE → B01` delta；8-bit sticky event counters 以 modulo-256 計算，immediate pair 未發生 wrap。
