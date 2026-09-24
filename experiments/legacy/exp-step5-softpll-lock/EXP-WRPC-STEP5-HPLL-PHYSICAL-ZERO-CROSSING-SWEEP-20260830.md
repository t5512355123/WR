# EXP-WRPC-STEP5-HPLL-PHYSICAL-ZERO-CROSSING-SWEEP-20260830

## 判定

```text
STEP4B = PASS (沿用既有 Step4B 證據；本輪使用同一個 Slave SoftPLL event path)
STEP5_ZERO_CROSSING_CALIBRATION = PASS_WITH_LOW_END_OUTLIER
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

本輪已在實體 HPLL physical-step sweep 中找到可重複的零交越點：

```text
N_ZERO = 6336 physical steps
FREQ_ERROR(6336) = 0       (第一次 fresh-program)
FREQ_ERROR(6336) = 0       (第二次有效 fresh-program repeat)
```

這證明了 physical HPLL burst 的方向、交易記帳與零交越位置，但還沒有
啟用 34-code normal tracker 並完成 Step5 closed-loop lock、frequency/phase
convergence 與長時間穩定性。因此不能把本輪標成 `STEP5_COMPLETE`，也不能
merge 到 `main`。

## Provenance

```text
branch = exp/step5-softpll-lock
code/measurement script commit = 3508c4f
raw evidence commit = a0a8d67
experiment = EXP-WRPC-STEP5-HPLL-PHYSICAL-ZERO-CROSSING-SWEEP
date = 2026-08-30 (Asia/Taipei)
board = DE5 [1-11.2] (Slave under test)
```

## 實驗限制與保持項目

本輪只執行 physical zero-crossing calibration：

- Slave `ENABLE_NORMAL_HPLL_TRACKER = 0`。
- Master 保留 `ENABLE_NORMAL_HPLL_TRACKER = 1`，作為 Slave 上游正常運作的必要條件。
- A polarity 保持 `polarity_reverse=0`。
- PI gains、thresholds、DMTD、PTP/PHY、Main PLL、reset tree 與 SoftPLL 控制流程未改動。
- 每個 N 都使用相同來源 SOF，並以 fresh-program pair 重新開始。
- 量測使用固定 helper-update window：`settle_updates=2`、`window_updates=10`。
- `FREQ_ERROR(N) = ΔPRECLAMP_ERROR / ΔHELPER_UPDATE_COUNT`。
- helper counter delta 使用 16-bit modulo，避免 counter rollover 被誤判成有效數值。

## Build / program evidence

兩個 Quartus Prime 17.0 Build 595 full compilation 都成功；timing 尚未 closed，
這是本輪的 implementation caveat，不是 zero-crossing 計算的接受條件：

```text
Master source build commit = a3e70f4
Master SOF_SHA256 = 49320adc70523c630e539bf5f72c55d9683fc352f6995a7ed1e3a6bd70b1f20e
Master programmed checksum = 0x30B897E6
Master worst setup slack = -0.453 ns

Slave source build commit = 9d3b24d
Slave SOF_SHA256 = 9056e04179ccd14af6bc3ad8be646c1c33f70ce3d522bb5f2a264125ccb16c4b
Slave programmed checksum = 0x30B694D0
Slave worst setup slack = -0.360 ns

TIMING_CLOSED = NO
programmer result = 0 errors, 0 warnings
```

## Sweep method

每一個有效點都執行：

```text
fresh-program Master + Slave
→ 5 s baseline
→ single FORCE_HPLL_ONE_STEP trigger with burst size N
→ wait for forced completion
→ settle 2 helper updates
→ fixed 10-helper-update window
→ compare PRECLAMP_ERROR and helper-update count
```

實際使用的腳本參數為：

```text
baseline_seconds=5
poll_ms=500
max_completion_polls=2400
settle_updates=2
window_updates=10
helper_poll_ms=100
polarity_reverse=0
fixed_sof=1
normal_hpll_tracker=0
board_filter=DE5 [1-11.2]
```

## 有效 sweep 結果

所有列入下表的點都滿足 `BURST_DONE=1`、固定 window 有效，且 forced transaction
完整記帳。`N=0` 是 no-force baseline；因此其 forced counters 為 0 是預期結果。

| N | ΔHELPER | ΔPRECLAMP | FREQ_ERROR | MEAN_TAG−EXPECTED | ΔADMITTED | ΔCOMPLETED | ΔDCO_STEP | normal req/complete |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 4098 | -4,654,039 | -1136 | -1137 | 0 | 0 | 0 | 0 / 0 |
| 512 | 4192 | -6,194,625 | -1478 | -1475 | 512 | 512 | 512 | 0 / 0 |
| 1024 | 4163 | -5,702,581 | -1370 | -1376 | 1024 | 1024 | 1024 | 0 / 0 |
| 1536 | 4131 | -5,191,166 | -1257 | -1260 | 1536 | 1536 | 1536 | 0 / 0 |
| 2048 | 4099 | -4,661,648 | -1138 | -1133 | 2048 | 2048 | 2048 | 0 / 0 |
| 4096 | 3966 | -2,473,701 | -624 | -626 | 4096 | 4096 | 4096 | 0 / 0 |
| 6144 | 3831 | -265,783 | -70 | -53 | 6144 | 6144 | 6144 | 0 / 0 |
| 6272 | 3819 | -77,511 | -21 | -16 | 6272 | 6272 | 6272 | 0 / 0 |
| 6336 | 3817 | 0 | 0 | -15 | 6336 | 6336 | 6336 | 0 / 0 |
| 6336 repeat | 3817 | 0 | 0 | +7 | 6336 | 6336 | 6336 | 0 / 0 |
| 6400 | 3811 | +55,564 | +14 | +14 | 6400 | 6400 | 6400 | 0 / 0 |
| 6656 | 3796 | +292,130 | +76 | +68 | 6656 | 6656 | 6656 | 0 / 0 |

關鍵 bracket 為：

```text
N=6144  → FREQ_ERROR=-70
N=6656  → FREQ_ERROR=+76

N=6272  → FREQ_ERROR=-21
N=6400  → FREQ_ERROR=+14

N=6336  → FREQ_ERROR=0
N=6336  → FREQ_ERROR=0  (fresh-program repeat)
```

因此零點不只落在 `|N_high-N_low|<=64` 的範圍內，還在相同 N 的第二次
有效 fresh-program repeat 中重現為零。

## Acceptance review

```text
ΔSTEP=N                              PASS
ΔFORCED_HPLL_COMPLETED=N             PASS
normal transactions=0                PASS
transaction accounting               PASS
FREQ_ERROR(0)<0                       PASS
N=1024..6656 trend toward zero       PASS
N_ZERO repeat                         PASS (N=6336)
```

有一個必須保留的 caveat：`N=512` 有效 recovery run 的 `FREQ_ERROR=-1478`，
比 `N=0` 的 `-1136` 更負，因此若把所有低端點要求成嚴格全局單調，這一筆
是 outlier。其後從 `N=1024` 到 `N=6656` 的趨勢則持續向零並穿越零點。
本報告不刪除此資料，也不把它包裝成嚴格全局 monotonic PASS；交由分支5
決定是否接受為低端 fresh-program repeatability caveat，或要求補測低端點。

## Invalid / excluded attempts

以下資料保留在 raw evidence，但不列入 acceptance：

- `N00512_zero_point.log`：fresh-program 後 Slave SoftPLL 尚未啟動，後續以 recovery run 取得有效 N=512。
- `N01536_zero_point.log`：helper counter rollover 造成 delta 無效；以 `N01536_zero_point_repeat.log` 重新取得有效值。
- `N06336_zero_point_repeat.log`、`N06336_zero_point_repeat_recovery.log`：fresh-program/recovery 後上游啟動未成立，所有計數器為 0。
- `N06400_zero_point.log`：fresh-program 後未啟動，後續 `N06400_zero_point_recovery.log` 有效。

另有一輪以 dashboard 讀取到 Slave `PSTAT=LISTENING`、`SPLL_INIT_COUNT=0` 的
狀態；這是啟動／JTAG dashboard 的 upstream-not-ready measurement failure，
不是有效的 Step5 lock result，也不覆蓋上述已完成 forced transaction 的有效點。

## Raw evidence

本輪 raw evidence 已提交於：

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-HPLL-PHYSICAL-ZERO-CROSSING-SWEEP-20260830/
```

主要檔案包括：

- `N06336_zero_point.log`
- `N06336_zero_point_repeat_timed.log`
- `N06272_zero_point.log`
- `N06400_zero_point_recovery.log`
- `N06144_zero_point.log`
- `N06656_zero_point.log`
- `build_info_jtag_master.txt`
- `build_info_jtag_slave.txt`
- 對應的 Master/Slave programming logs

## Next boundary

本輪完成後的合理下一步是：

```text
bootstrap N_ZERO=6336 physical steps
→ enable the proven 34-code normal tracker
→ fresh-program pair
→ verify Step4B upstream gate
→ run closed-loop lock observation (including long-duration stability)
```

在分支5審核本紀錄並明確回覆 `STEP5_COMPLETE=YES` 及
`MERGE_APPROVED=YES` 之前，維持：

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```
