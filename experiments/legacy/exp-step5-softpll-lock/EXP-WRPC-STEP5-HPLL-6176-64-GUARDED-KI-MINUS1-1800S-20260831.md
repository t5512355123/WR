# EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-1800S-20260831

## 判定

```text
EXPERIMENT_VALID = NO
OBSERVATION_CLASS = JTAG/DASHBOARD_MEASUREMENT_FAILURE
STEP4B_COMPLETE = NOT_ADJUDICATED_FROM_THIS_RUN
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

本輪不能用來判定 `ki=-1` 對 closed-loop dynamics 的效果，也不能判定
`NEVER_LOCKED`。原因是完整 observer 雖然執行了 18000 次取樣，但沒有取得
任何一筆有效 frame。

## 變因與保持不變項

Branch：`exp/step5-softpll-lock`

Commit：`1c638094e71e33f7a3540353225f654da0bb42b7`

唯一 functional change（Slave/WR-node firmware）：

```text
CONFIG_WR_NODE helper PI：ki -2 -> -1
```

保留：

```text
bootstrap = 6176
kp = -150
threshold = 200
lock_samples = 10000
code_per_step = 64
anti_windup = 1
```

本輪沒有修改 DMTD、P_ADDER、P_SETPOINT、phase setpoint、Main PLL、sequencer、
reset tree、VUART 或 observer control semantics。

## Fresh-program evidence

兩張 DE5a 均完成 programming，Quartus programmer 回報 0 errors：

```text
DE5 [1-11.1] Master SOF checksum = 0x30ADDBBE
DE5 [1-11.2] Slave  SOF checksum = 0x30AB920F
```

本紀錄以 remote raw evidence 中可見的 programming 結果為準；本輪沒有把
「programming 成功」誤當成 runtime link 或 Step5 成功。

## Dashboard evidence

Remote raw：

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-1800S-20260831/valid-fresh-program/dashboard-after-fresh-program.log
```

Master 的穩定後 snapshot 曾顯示：

```text
core_tm_link_up = 1
core_link_ok    = 1
STEP1_REGRESSION = PASS
```

但 Master 的 JTAG/diagnostic fields 仍有 timeout/inconsistent read，因此 Step2
為 `NA`、Step4A 為 `INVALID`。

同一份 dashboard 對 Slave 的後續 snapshot 顯示：

```text
core_tm_link_up = 0
core_link_ok    = 0
si_config_done  = 1
wr_ready        = 1
wr_rx_ready     = 1
wr_tx_ready     = 1
CPU_RESET_n     = 1
STEP1_REGRESSION = FAIL
STEP2_REGRESSION = INVALID
STEP3_REGRESSION = INVALID
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP4B_FIRST_INACTIVE_BOUNDARY = UPSTREAM_PREREQUISITE
STEP5_RESULT = UPSTREAM_NOT_READY
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP4B
FAILURE_CLASSIFICATION = JTAG/DASHBOARD_MEASUREMENT_FAILURE
```

因此使用者看到的：

```text
Step 1 PHY / Link             error
Step 2 Endpoint / PTP         NA
Step 3 WR Handshake           NA
Step 4 SoftPLL Startup        error/blocked
Step 5 Closed-loop Lock       NA
Step 6 Global Time             NA
```

與本輪 raw 一致；Step2–6 是上游 Step1/runtime measurement gate 的連帶結果，
不是 `ki=-1` 已經證明失敗。

## 1800-second observer evidence

Remote raw：

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-1800S-20260831/valid-fresh-program/pi-trace-18000.log
```

Observer 結束時間為 2026-08-31 21:56:14（remote，UTC+8），處理時間 01:11:02。

```text
SAMPLES = 18000
VALID_FRAMES = 0
INVALID_FRAMES = 18000
WINDOW_SECONDS = 1799.900
PI_TRACE_PRESENT = 0
PI_TRACE_FRACTION = 0.000
PI_SNAPSHOT_REJECTS = 0
PI_ACCOUNTING_FAILS = 0
PI_OUTPUT_MISMATCH_FAILS = 0
ANTI_WINDUP_VIOLATIONS = 0
DYNAMICS_CANDIDATE = INSUFFICIENT_DATA
MEASUREMENT_COHERENCE = CHECK
POSITION_ACCOUNTING = CHECK
TRANSACTION_ACCOUNTING = CHECK
RESET_STABLE = CHECK
KP = -150
KI = -1
```

所有取樣的 `FRAME_VALID=0`、`PI_TRACE_PRESENT=0`；因此以下欄位均為
`INVALID` 或 `CHECK`，不可當作 closed-loop 結果：

```text
FRACTION_ABS_ERROR_LE_200
HELPER_LOCKED
HELPER_LOCK_COUNT
MAIN_ENABLED
MAIN_FREQ_LOCKED
MAIN_PHASE_LOCKED
MAIN_LOCKED
PSTAT_LOCKED
SPLL_INIT_COUNT
SPLL_DELOCK_COUNT
RESET_* deltas
```

## 結論與下一步

本輪只證明：

1. `ki=-1` 版本已被寫入本輪使用的 firmware commit。
2. 兩張板完成 programming。
3. Slave 在 dashboard gate 上失去 `core_tm_link_up/core_link_ok`，導致 Step4B
   upstream blocked。
4. 1800 秒 observer 沒有任何可用 telemetry，不能判定 lock 或 ki 方向效果。

因此本輪應標記為 **INVALID / REPEAT REQUIRED**，而不是 Step5 pass 或 fail。
下一輪應先恢復並驗證同一 JTAG session 的 Slave `core_tm_link_up=1`、
`core_link_ok=1`，且先取得有效 Step1–4B upstream gate，再重跑完整 1800 秒
observer；不得在無效 observer 上更改 `kp`、`ki` 或其他控制參數。

## Raw evidence location

完整 raw 留在 pain 的：

```text
/home/b10504072/04_WR/docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-6176-64-GUARDED-KI-MINUS1-1800S-20260831/valid-fresh-program/
```

本輪尚未取得可直接加入 GitHub 的 raw 檔副本；此報告保留遠端路徑與完整
summary，避免把無效資料誤標成 Step5 evidence。
