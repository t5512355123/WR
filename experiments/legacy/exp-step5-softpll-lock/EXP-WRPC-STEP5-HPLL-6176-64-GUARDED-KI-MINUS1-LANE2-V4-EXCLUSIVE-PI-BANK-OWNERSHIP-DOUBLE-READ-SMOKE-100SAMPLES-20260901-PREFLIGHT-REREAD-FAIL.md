# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V4-EXCLUSIVE-PI-BANK-OWNERSHIP-DOUBLE-READ-SMOKE-100SAMPLES-20260901-PREFLIGHT-REREAD-FAIL

## 結論

本輪依分支5要求只做一次 read-only preflight reread，沒有 rebuild、沒有
reprogram，也沒有執行 V4 100-sample double-read。Step 1/2/3 在這次保存的
reread 中可成立，但 Step 4B 的 DMTD accepted-event gate 被讀值倒退判定為
JTAG/WB read inconsistency，因此不能把目前狀態當成 V4 smoke 的合法入口。

```text
V4_PREFLIGHT_REREAD = FAIL
STEP1 = PASS
STEP2 = PASS
STEP3 = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = STARTUP_PROVEN_EVENT_PROCESSING_NOT_PROVEN
STEP4B_FIRST_INACTIVE_BOUNDARY = DMTD_ACCEPT
V4_SMOKE = NOT_RUN
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Fixed conditions

```text
QSFPA lane = 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

本輪繼續使用已驗證的 V4 image，沒有修改 source 或控制參數。

## Read-only reread result

命令：

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

Master：

```text
Step 1 = pass
Step 2 = pass
Step 4A = PASS
WRC_MODE = MASTER
WDIAGS_PTP = MASTER
WDIAGS_PTP_RX delta = 10
WDIAGS_PTP_TX delta = 23
WDIAGS_RXERR delta = 0
```

Slave：

```text
Step 1 = pass
Step 2 = pass
Step 3 = pass
WRC_MODE = SLAVE
WDIAGS_PTP = SLAVE
parentIsWRnode = 1
parentCalibrated = 1
LOCK_ENABLE_COUNT = 4
SPLL_MODE = 3 (SLAVE)
SPLL_SEQ_STATE = 4 (SEQ_WAIT_HELPER)
SPLL_INIT_COUNT = 1
TAG_VALID delta = 43352
TRR_WRITE delta = 43353
TRR_POP delta = 42973
IRQ delta = 42109
HELPER_UPDATE delta = 21361
RXERR delta = 0
BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0
```

但 DMTD counter evidence 不一致：

```text
DMTD_REF before = 0x027060A0
DMTD_REF after  = 0x0270B34A
DMTD_REF delta  = 21162

DMTD_FB before  = 0x02A2D033
DMTD_FB after   = 0x0270B360
DMTD_FB result  = counter decreased/reset

DMTD_ACCEPT = JTAG read inconsistent
```

由於 Step 4B 入口要求 accepted-event evidence，這次不能繼續執行
double-read；也不能把這次結果解讀成 V4 ownership fix 的 pass 或 fail。

## Why the user-facing dashboard can still show an error

緊接前一次 read-only invocation 曾出現另一種判定：Slave 的 Step 1/2
仍為 pass，但診斷器因最後 TX signaling 訊息為 `LOCK`、而現行單次檢查硬性
期待 `SLAVE_PRESENT`，把 Step 3 顯示成 error，進而連鎖顯示 Step 4B blocked。

兩次沒有任何 rebuild/reprogram，中間只做了 read-only sampling，卻分別得到：

```text
read 1: Step3 error, Step4B blocked by Step3
read 2: Step3 pass, Step4B allowed, DMTD_ACCEPT inconsistent
```

因此目前的證據支持「JTAG/WB diagnostic sampling 或單次 dashboard
判定不穩定」，不支持宣稱 PHY/link 或 V4 source fix 已經確定失效。這也
解釋了為何畫面可能重複顯示 error；但由於本次 preflight 並未完整通過，
仍不能開始 Step5 smoke。

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-LANE2-V4-EXCLUSIVE-PI-BANK-OWNERSHIP-DOUBLE-READ-SMOKE-100SAMPLES-20260901-PREFLIGHT-REREAD.log
```

本輪未執行：

```text
V4 100-sample double-read
1800-second Step5 observer
rebuild/reprogram
PI/lane/PHY/PTP/firmware change
merge to main
```

正式狀態：

```text
STEP4B_COMPLETE = YES (previous three clean V4 recovery trials)
STEP4B_REVALIDATED_BY_CURRENT_PREFLIGHT = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```
