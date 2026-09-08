# EXP-WRPC-STEP5-HPLL-NEAREST-QUANTIZED-STEP-20260909

## 判定

本輪驗證了 HPLL absolute target tracker 的 half-step admission 修正，
但沒有達成 Step5。修正確實消除了上一輪 `TARGET=65531`、`APPLIED=65477`
且殘差 54 小於 physical step 64 所造成的 dead zone；然而實體輸出仍固定在
Helper 高 rail，頻率誤差沒有收斂，故不能宣稱 lock 或 merge。

```text
SOURCE_COMMIT = 26bcd136403a402e5c86149646325b8f86cfdbfe
STEP1_TO_STEP3 = PASS
STEP4B = PASS
STEP5_VALID_MEASUREMENT = YES
STEP5_RESULT = NOT_COMPLETE
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## 唯一程式變更

`quartus/jtag_runtime_diag/si5340a_controller_dco.v` 新增：

```text
HPLL_HALF_STEP_CODE = HPLL_STEP_CODE >>> 1
```

normal HPLL tracker 的 admission threshold 由完整 physical step 改為 half
step。完成的實體交易仍只增加或減少一個完整的 64-code virtual step；沒有
改變 PI、bootstrap polarity、page/mask sequence、Main tracker 或 reset。

## Build / program provenance

Pain 由本 source commit 編譯，Master 與 Slave full compilation 均成功：

```text
MASTER_SOF_SHA256 = 0cb2d3cf350461b860133383ed81ed2a8c5c19276eae7e436f232a91b9d47504
SLAVE_SOF_SHA256  = 1e9d915d66dc2374e9c854e8bf4e946cf28b575d82b2e079b327717578c8d16b
MASTER_WORST_SETUP_SLACK_NS = -0.178
SLAVE_WORST_SETUP_SLACK_NS = -0.534
TIMING_CLOSED = NO
PROGRAM_ORDER = SLAVE_THEN_MASTER
PROGRAM_RESULT = Configuration succeeded, 0 errors, 0 warnings
```

本輪採用已恢復 upstream 的 Slave-first 載入順序。preflight 顯示雙板 link、
PTP RX/TX activity、Slave Step1/2/3 與 Step4B 均通過；Slave 的
`STEP4B_ALLOWED=YES`、`STEP4B_RESULT=PASS`、`STEP4B_FIRST_INACTIVE_BOUNDARY=ACTIVE`。

## Coherent closed-loop observation

觀測器執行 1200 筆 coherent snapshots，約 135 秒；量測與 position/accounting
均有效，期間沒有新增 reset 或 de-lock：

```text
SAMPLES = 1200
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = PASS
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
RESET_STABLE = PASS
SPLL_DELOCK_COUNT_DELTA = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
```

half-step admission 的硬體效果可由前後位置比較確認：

```text
previous valid run: TARGET=65531, APPLIED=65477
this run:           TARGET=65531, APPLIED=65541
```

也就是本輪確實多完成一次 FINC，並使 applied position 跨過 target；這證明
tracker 修正有進入 bitstream，而不是沒有送出 request。

但 1200 筆觀測的控制結果仍為：

```text
FREQ_ERROR_MEAN = -621.285833333
FREQ_ERROR_RMS = 621.383454479
FREQ_ERROR_MIN = -654
FREQ_ERROR_MAX = -583
FREQ_ERROR_FIRST = -622
FREQ_ERROR_LAST = -639
HELPER_ERROR_MEAN = -150000.0
FRACTION_ABS_ERROR_LE_200 = 0.0
HIGH_RAIL_FRACTION = 1.0
LOW_RAIL_FRACTION = 0.0
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
NORMAL_REQ_DELTA_OBSERVED = 0
NORMAL_COMPLETED_DELTA = 0
BOOTSTRAP_COMPLETED_FINAL = 1024
BOOTSTRAP_DONE_FINAL = 1
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

觀測開始後 `TARGET-APPLIED=-10`，小於 half-step admission threshold 32，
所以沒有再產生 normal request；然而 frequency error 仍約為 -621，Helper
仍為 100% high rail。這表示單純修正 quantization dead zone 並未建立有效的
實體頻率校正，較可能的下一個瓶頸是目前 bootstrap/physical operating point
位於 actuator 邊界，或該邊界的實體方向／座標仍與 virtual code 不一致。

## 下一輪建議

依 `Astra建議.md`，下一輪不再盲掃 PI。保留 page/mask、方向與 absolute
tracker，改做受控 operating-point A/B：把 bootstrap seed 帶離目前
`HELPER_OUTPUT=65531` 的高 rail，並以短時間 coherent 觀測確認 frequency
error 對實體 FINC/FDEC 是否有可用的中間工作點；只有確認 helper 能穩定落在
`|helper_error| <= 200` 後，才進入長時間 Step5 lock window。

## Raw evidence

本資料夾 `raw/` 保存 build、program、preflight、observer 與 SOF hash 原始紀錄。
遠端 raw archive：

```text
SHA256 = de2a7ecd67ab2f39069459e8f75216ff96369f9c795e54b56af8e3cf6df8f982
```
