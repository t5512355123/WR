# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V4-EXCLUSIVE-PI-BANK-OWNERSHIP-DOUBLE-READ-SMOKE-100SAMPLES-20260901-PREFLIGHT-FAIL

## 結論

本輪完成 V4 exclusive PI-bank ownership source change、fresh build 與指定
Master/Slave JTAG programming；但 programming 後的唯讀 runtime precondition
沒有成立，因此 V4 100-sample smoke **未執行**。

```text
SOURCE_CHANGE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
V4_RUNTIME_PREFLIGHT = FAIL
V4_SMOKE = NOT_RUN
STEP4B_REVALIDATED_BY_CURRENT_FRESH_PROGRAM = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

依分支5規則，本輪在 preflight boundary 停止；不能把這次結果當成
PI-bank ownership pass，也不能進行 1800 秒 Step5 dynamics。

## Source change

branch `exp/step5-softpll-lock`，source commit：

```text
6943afa30d728022f70c25d28308a38ee5ee78a8
```

唯一 functional source change 是 WDIAGS diagnostic ownership arbitration：

```text
snapshot request inactive:
    legacy persistent / lock-wait mirrors may publish

first PI snapshot request observed:
    0x158..0x1dc becomes PI frozen-bank exclusive
    legacy state remains in host RAM
    legacy mirror writes are suppressed
```

修改範圍只有 `vendor/wrpc-sw/dev/wdiags.c` 與對應 register-map ownership
註解；沒有修改 PI equation、`kp`、`ki`、bootstrap、DMTD、tracker、lane、
PHY、PTP role、sequencer、Main PLL 或 reset tree。

## Fixed conditions and build provenance

```text
QSFPA lane = 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

Fresh build scripts reported both Quartus builds successful:

```text
MASTER_QUARTUS_BUILD = PASS
SLAVE_QUARTUS_BUILD = PASS
timing_closed = NO
```

Fresh artifact hashes on pain：

```text
MASTER_MIF = fafcfed4b0cee770d0388dcf23e67bbd9b76cebaa9950a5b9a9ce6ee57b6f94e
SLAVE_MIF  = ad32895d119eec9a71fe1bd6e6ec0a7eb9a4c59fc9789708cbf4e6d4cc33916e
MASTER_SOF = 0c83bd82a505f64588c5f722f21db66ea2acbfc20b2067cf3c41b6df611ada84
SLAVE_SOF  = 822cd8eb26f6eb544572f65bc8db990ef44ad32f3971e4573e57a3042f2f7d37
```

Programming command results：

```text
Master cable = DE5 [1-11.1]
Master SOF   = DE5a_wr_master_jtag.sof
configuration succeeded

Slave cable = DE5 [1-11.2]
Slave SOF   = DE5a_wr_slave_jtag.sof
configuration succeeded
```

## Read-only precondition result

執行 fresh programming 後等待啟動，再執行
`read_wb_runtime.tcl --raw`。結果如下：

Master：

```text
core_tm_link_up = 0/1
core_link_ok = 0/1
WDIAGS_PTP = 6 MASTER
PTP_RX delta = 0
PTP_TX delta = 2
RXERR delta = 0
HELPER_UPDATE_COUNT delta = 26657
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
STEP4A_RESULT = PASS
```

Slave：

```text
core_tm_link_up = 0/1
core_link_ok = 0/1
WDIAGS_PTP = 4 LISTENING (expected 9 SLAVE)
PTP_RX delta = 0
PTP_TX delta = 3
RXERR delta = 0
parentIsWRnode = 0/1
parentCalibrated = 0/1
LOCK_ENABLE = 0/> 0
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP4B_FIRST_INACTIVE_BOUNDARY = UPSTREAM_PREREQUISITE
STEP5_RESULT = UPSTREAM_NOT_READY
```

因此本輪不是 V4 double-read 的有效 pass/fail 判定；是 fresh-program 後
startup/link/PTP precondition failure。雖然 RXERR 與 reset deltas 保持乾淨，
但沒有 core link、PTP RX、parent handshake 或 Step4B event gate，不能進入
snapshot ownership smoke。

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V4-PREFLIGHT-20260901.log
```

本輪沒有執行：

```text
V4 100-sample double-read
1800-second Step5 observer
PI parameter change
lane/PHY/PTP change
merge to main
```

目前正式狀態仍是：

```text
STEP4B_COMPLETE = YES (previous validated live run)
STEP4B_REVALIDATED_BY_CURRENT_FRESH_PROGRAM = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```
