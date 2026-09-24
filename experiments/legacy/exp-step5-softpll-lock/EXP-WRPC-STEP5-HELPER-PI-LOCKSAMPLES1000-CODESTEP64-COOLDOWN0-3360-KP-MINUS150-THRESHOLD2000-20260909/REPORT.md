# EXP-WRPC-STEP5-HELPER-PI-LOCKSAMPLES1000-CODESTEP64-COOLDOWN0-3360-KP-MINUS150-THRESHOLD2000-20260909

## 判定

本輪 **不是 Step5 PASS**，因此不具備 merge 到 `main` 的條件。

```text
Step1 PHY / Link              PASS
Step2 Endpoint / PTP          PASS
Step3 WR Handshake             PASS
Step4B Slave SoftPLL startup   PASS
Helper lock gate               PASS（本輪首次跨過）
Main enabled                   PASS（本輪首次進入）
Step5 Closed-loop Lock         NOT COMPLETE
```

本輪之後的第一個未通過邊界是 `MAIN_FREQUENCY_LOCK`：Helper 已達 `1000/1000` 並保持 locked，Main 已啟動，但 Main frequency/phase/PSTAT 尚未 lock。

## 本輪目的

上一輪在 threshold=1200 下，Helper error RMS 約 654，但有多次越過 ±1200，Helper dwell 無法完成。本輪只做一個可回退的 admission-boundary A/B：

- 實際 HPLL physical step 維持 64
- bootstrap 維持 3360、cooldown 維持 0
- Helper PI 維持 `kp=-150`、`ki=-1`
- lock samples 維持 1000
- Helper lock threshold `1200 -> 2000`
- 不修改 DCO direction、SI5340 runtime write、Main absolute target/applied tracking 或 reset/SoftPLL FSM

threshold=2000 只用來確認 Helper gate 是否是目前進入 Main 的實際瓶頸；不能單獨用來宣告 Step5。

## 實際建置與燒錄

本輪 source commit：

```text
ebdbe37efdf471ca884f0776ce9150a56771ecd9
```

Pain 端先 pull 該 commit，再使用正式 Master/Slave firmware build scripts 重新產生 MIF、執行 Quartus compile，最後依 Master→等待→Slave 順序重新燒錄。

SOF SHA-256：

```text
Master 5afa5df8f563e175afdb148d673ba981cfa89d6c5bf666a3c3650cc8f68bd027
Slave  72240d0ad67a15143ffc79c10804405a68c17d433a374910e51f988e920bbf98
```

Build 與 program exit code 均為 0；preflight exit code 為 0。

## Preflight 結果

```text
Master WDIAGS_PTP       = 6 MASTER
Slave WDIAGS_PTP        = 9 SLAVE
parentIsWRnode           = 1
STEP4B_ALLOWED           = YES
STEP4B_RESULT            = PASS
```

Preflight 在觀測前讀到 Helper lock counter：

```text
before: 15/1000, threshold=2000, locked=0
after:  100/1000, threshold=2000, locked=0
```

## 60 秒 PI 觀測

```text
SAMPLES                       = 600
VALID_FRAMES                  = 600
INVALID_FRAMES                = 0
PI_TRACE_PRESENT              = 600
PI_SNAPSHOT_REJECTS           = 0
PI_ACCOUNTING_FAILS           = 0
PI_OUTPUT_MISMATCH_FAILS      = 0
MEASUREMENT_COHERENCE         = PASS
POSITION_ACCOUNTING           = PASS
TRANSACTION_ACCOUNTING        = PASS
ATOMIC_SNAPSHOT_TRANSPORT_V3  = PASS
```

Helper trajectory：

```text
HELPER_ERROR_MEAN             = 4.1433
HELPER_ERROR_RMS              = 705.1618
HELPER_ERROR_MAX_ABS          = 2341
FRACTION_ABS_ERROR_LE_2000    = 99.5%
RAW_ERROR_MIN/MAX             = -2341 / 2202
ERROR_BAND_EXIT_EVENTS        = 3
LOW_RAIL_FRACTION             = 0%
HIGH_RAIL_FRACTION            = 0%
NO_RAIL_FRACTION              = 100%
DYNAMICS_CANDIDATE            = UNDERDAMPED_OR_OVERAGGRESSIVE_CANDIDATE
```

Lock/runtime 結果：

```text
HELPER_LOCK_COUNT_MAX         = 0       # PI snapshot window 的 frozen state
HELPER_LOCK_COUNT_FINAL       = 0       # PI snapshot window 的 frozen state
HELPER_LOCKED_FINAL           = 0       # PI snapshot window 的 frozen state
```

觀測結束後立即執行 direct WDIAGS postflight，得到：

```text
HELPER locked=1 changed=0 cnt=1000/1000 threshold=2000
MAIN enabled=1 locked=0 freq=0 phase=0 freq_cnt=0/50 phase_cnt=0/1000
PSTAT_locked=0
STEP5_RESULT=NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY=MAIN_FREQUENCY_LOCK
```

因此 PI snapshot window 的 lock-state mirror 與 postflight direct lock detector snapshot 出現時間差；後者證明 Helper gate 最終確實已跨過，並且 Main 已被啟動，但沒有證明 Main closed-loop lock。

其他健康度：

```text
SPLL_INIT_COUNT              = 1 -> 1
CLEAR_DACS_COUNT             = 1 -> 1
BOOTSTRAP_COMPLETED_FINAL    = 3360
BOOTSTRAP_DONE_FINAL         = 1
NORMAL_REQ_DELTA             = 19149
NORMAL_COMPLETED_DELTA       = 19149
DCO_STEP_DELTA               = 19153
SPLL_DELOCK_COUNT            = 0 -> 0
BOOT/CPU/WR/SI reset deltas   = 0 / 0 / 0 / 0
RESET_STABLE                  = PASS
```

## 解讀

threshold=2000 確實讓 Helper lock detector 最終達到 `1000/1000`，並讓 FSM 從 `SEQ_WAIT_HELPER` 進入 Main；這是相對 threshold=1200 的實質進展。可是 Main 的 frequency lock detector 仍為 `0/50`，因此 `mpll` 尚未完成 frequency lock，後續 phase lock 與 PSTAT 也不會成立。

PI snapshot 的 600 個 frozen frames 都在 Helper gate 跨越前/尚未反映 direct state 的時間窗內，所以它的 final Helper state 不能推翻 postflight 的 direct evidence；但也不能把 postflight 的 Helper locked 誤當成 Step5 PASS。

目前 Main 尚未 rail、reset 未增加、DCO transaction accounting 通過，故下一個合理邊界是 Main frequency pre-lock dynamics，而不是重新修改 Helper gate。

## 下一輪建議

下一輪應先 fresh reprogram，並在任何 Helper PI snapshot request 之前執行 Main-frequency pre-lock observer，避免 PI overlay claim 使 Main overlay 不可用。需要取得：

- Main `dref_dt`、`dout_dt`、frequency error 的完整時間序列
- Main frequency lock counter 的 rise/fall
- Main PI output、bias、clamp side 與 update count
- Helper→Main 啟動時間與 Main first-valid sample
- Main frequency lock 是否因 threshold、初始 bias 或頻率方向而無法累積

在取得這些證據前，不應再調整 Helper threshold，也不應宣告 Step5 或 merge 到 `main`。

## Raw evidence

本輪 Pain 原始 build、program、preflight、PI observer、postflight log 與 source/SOF checksum 已保存於同資料夾的 `raw/`；同一份 raw archive 已保存於 `artifacts/`。
