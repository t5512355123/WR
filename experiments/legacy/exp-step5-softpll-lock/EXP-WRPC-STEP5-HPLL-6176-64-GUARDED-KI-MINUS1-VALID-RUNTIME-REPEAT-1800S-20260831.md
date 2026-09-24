# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-VALID-RUNTIME-REPEAT-1800S-20260831

## 判定

```text
RUNTIME_OBSERVER_PREFLIGHT = FAIL
EXPERIMENT_VALID = NO
OBSERVATION_CLASS = JTAG/DASHBOARD_MEASUREMENT_FAILURE
KI_REDUCTION_DIRECTION_EFFECTIVE = NOT_ADJUDICATED
STEP4B_COMPLETE = NOT_REVALIDATED_BY_THIS_RUN
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

本輪依分支5的要求，在 runtime preflight 失敗後停止；沒有執行 100-sample
smoke，也沒有執行 1800-second observer。因此本輪沒有任何可用的 ki=-1
closed-loop dynamics evidence。

## 分支與唯一 functional image

Branch：`exp/step5-softpll-lock`

Record commit：`a035b819b37fda162d6b430fd44af52f6ee889e7`

Functional image baseline：`1c638094e71e33f7a3540353225f654da0bb42b7`

本輪完全保持：

```text
bootstrap = 6176
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
code_per_step = 64
idempotent guard unchanged
anti_windup unchanged
DMTD unchanged
P_ADDER unchanged
P_SETPOINT unchanged
phase setpoint unchanged
Main PLL unchanged
sequencer unchanged
reset tree unchanged
```

沒有修改 `ki`、`kp`、bootstrap、64-code mapping、polarity、threshold、
lock_samples，也沒有 forced FINC/FDEC 或 manual DCO adjustment。

## Build 與 fresh-program

在 pain 端先 pull 到 `a035b81`，再執行：

```text
bash scripts/build/build_master.sh
bash scripts/build/build_slave.sh
```

Master 與 Slave 均回報 `Full Compilation was successful`；兩者的 timing
closure 仍為 `NO`，這是既有 implementation caveat，不作為本輪 runtime
判定。

兩張 DE5a 均 fresh-program 成功，Quartus programmer 回報 0 errors：

```text
DE5 [1-11.1] Master SOF checksum = 0x30ADDBBE
DE5 [1-11.2] Slave  SOF checksum = 0x30AB920F
```

本輪 programming 成功只代表 image 已寫入 FPGA，不代表 runtime preflight
或 Step5 成功。

## Runtime preflight

Fresh-program 後等待 180 秒，再在同一 SSH/JTAG workflow 連續執行三次
`read_wb_runtime.tcl --raw`。Raw files：

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-VALID-RUNTIME-REPEAT-1800S-20260831/preflight-01.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-VALID-RUNTIME-REPEAT-1800S-20260831/preflight-02.log
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-VALID-RUNTIME-REPEAT-1800S-20260831/preflight-03.log
```

三次的核心結果一致：

```text
Slave core_tm_link_up = 1
Slave core_link_ok    = 1
STEP1_REGRESSION      = PASS
STEP2_REGRESSION      = INVALID
STEP3_REGRESSION      = INVALID
STEP4B_ALLOWED        = NO
STEP4B_RESULT         = BLOCKED_BY_STEP2
FAILURE_CLASSIFICATION = JTAG/DASHBOARD_MEASUREMENT_FAILURE
```

Step2/3 的具體失效訊號包括：

```text
EP_MAC_H/EP_MAC_L = JTAG read inconsistent/NA
WDIAGS_MODE       = TIMEOUT
WDIAGS_PTP        = TIMEOUT / inconsistent read
WDIAGS_PTP_RX     = TIMEOUT
WDIAGS_PTP_TX     = TIMEOUT
WDIAGS_TX         = TIMEOUT
WDIAGS_RX         = TIMEOUT
WDIAGS_RXERR      = TIMEOUT
WDIAGS_FOREIGN_META = TIMEOUT
parentIsWRnode      = TIMEOUT
parentWrModeOn      = TIMEOUT
parentCalibrated    = TIMEOUT
LOCK_ENABLE         = TIMEOUT
```

所以雖然 Slave 的 PHY/link gate 在三次 preflight 都顯示 Step1 pass，
Endpoint/PTP 與 WR handshake 的 source-backed runtime data 仍不可讀；
`STEP4B` 不允許進入，不能將這輪標成 Step4B 或 Step5 failure。

## Smoke 與 1800-second observer

依分支5明確規則：

```text
Step2/Step3 preflight = INVALID
RUNTIME_OBSERVER_PREFLIGHT = FAIL
100-sample smoke = NOT RUN
1800-second observer = NOT RUN
```

因此下列結果在本輪均為「未測量」，不可填成 0 或 NO：

```text
VALID_FRAMES
PI_TRACE_PRESENT
MEASUREMENT_COHERENCE
POSITION_ACCOUNTING
TRANSACTION_ACCOUNTING
HELPER_LOCK_COUNT
HELPER_LOCKED
MAIN_ENABLED
MAIN_FREQ_LOCKED
MAIN_PHASE_LOCKED
MAIN_LOCKED
PSTAT_LOCKED
```

## 結論與下一步邊界

本輪只證明：

1. 同一個 `6176 / kp=-150 / ki=-1` image 可完成 Master/Slave compile 與
   fresh-program。
2. Fresh-program 後 Slave 的 `core_tm_link_up` 與 `core_link_ok` 可以讀到 1。
3. 但 Endpoint/PTP/WR-handshake 的 mailbox/diagnostic reads 在三次 preflight
   都 timeout 或 inconsistent，導致 runtime preflight fail。
4. 本輪沒有足夠資料判定 `ki=-1` 的方向效果，更不能判定 Step5 lock。

下一輪仍應保持所有控制參數不變，先恢復可重複的 runtime/JTAG preflight：
Master/Slave 必須無 timeout/inconsistent read，Slave 的 Step1/2/3 與
`STEP4B_ALLOWED=YES`、`STEP4B_RESULT=PASS` 都成立；之後先跑 smoke，smoke
通過才可開始 1800-second observer。

在分支5明確回覆 `STEP5_COMPLETE=YES` 且 `MERGE_APPROVED=YES` 前，禁止 merge
`main`。
