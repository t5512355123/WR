# EXP-WRPC-STEP5-HPLL-DIRECTION-CORRECTED-CLOSED-LOOP-5632-64-20260909

## 結論

本輪已按照流程完成 laptop source push、Pain 拉取、Master/Slave 完整編譯、
Master→Slave 燒錄、Step1–4B upstream gate 與 1200 筆 coherent closed-loop
觀測。新的 FINC/FDEC 方向修正確實進入 runtime path，但 Helper PI 仍在兩端
rail 之間切換，沒有進入 lock window；因此 Step5 尚未完成。

```text
SOURCE_COMMIT = b990d7b812b2fab2016e5940398a3b6f2d065a79
MASTER_SOF_SHA256 = 96c9ec500a609a627855dc03024cea96be54332851ae343b68f186abad04734b
SLAVE_SOF_SHA256  = ffba3b61a2a69f54739cd9390b10c6b3d075f030137e3a919b37b4234cae7fea
TIMING_CLOSED = NO
PROGRAM_ORDER = MASTER_THEN_SLAVE
STEP1_TO_STEP3 = PASS (preflight 2)
STEP4B = PASS (preflight 2)
DIRECTION_FIX_EXERCISED = YES
STEP5 = NOT_COMPLETE
MERGE_APPROVED = NO
```

## 變更與驗證範圍

本輪保留 coarse bootstrap=5632、HPLL code-per-physical-step=64、Main absolute
tracker、page/mask runtime sequence 與原有 static-FSM fix；Slave top-level
將 `ENABLE_STEP5_HPLL_PLANT_TEST` 設為 0，使 normal HPLL tracker 真正啟用。

Upstream gate 的有效 preflight 2 顯示：

```text
Master link 1/1, PTP MASTER, PTP RX/TX deltas > 0
Slave  link 1/1, PTP SLAVE,  PTP RX/TX deltas > 0
Slave WR_RX_SIGNAL = LOCK
LOCK_ENABLE_COUNT = 4
SPLL_INIT_COUNT = 1
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_RESULT = PASS
```

## Closed-loop 觀測結果

觀測器成功完成 1200 筆、約 139.1 秒的 coherent snapshots；measurement
seqlock、transaction accounting 與 reset stability 均成立：

```text
COHERENT_MEASUREMENT_SNAPSHOTS = 1200
MEASUREMENT_COHERENCE = PASS
TRANSACTION_INVARIANT_FAILS = 0
DCO_INVARIANT_FAILS = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
RESET_STABLE = PASS
```

方向修正確實有被執行。觀測軌跡顯示：

```text
sample 1:   TARGET=65531, APPLIED=65477, NORMAL_FINC=1023, NORMAL_FDEC=0
sample 500: TARGET=65531, APPLIED=65477, NORMAL_FINC=1023, NORMAL_FDEC=0
sample 600: TARGET=5,     APPLIED=5,     NORMAL_FINC=1023, NORMAL_FDEC=1023
sample 1200:TARGET=5,     APPLIED=5,     NORMAL_FINＣ=1023, NORMAL_FDEC=1023
```

也就是本輪不再是上一輪的 negative control：normal request/completion 都有
實際增加，而且兩種方向均有完成交易：

```text
NORMAL_REQ_DELTA_OBSERVED = 1023
NORMAL_COMPLETED_DELTA = 1023
FINC_DELTA = 0
FDEC_DELTA = 1023
DCO_STEP_DELTA = 1023
```

`POSITION_INVARIANT_FAILS=550` 不能直接解讀成硬體位置錯誤，因為 observer
仍使用上一版的 `5 + 64*(FDEC-FINC)` 舊方向公式；本輪 RTL 已改為 FINC 增加、
FDEC 減少。重新套用新方向公式後，上述 65531→5 的軌跡符合 absolute target
與 applied position 的預期。這是觀測器待修正的 accounting 問題，不是本輪
Step5 PASS 的理由。

## 為何 Step5 仍未通過

Helper 沒有形成可鎖定的細部控制輸出，而是長時間在兩個端點間切換：

```text
HELPER_ERROR_MEAN = 14250.0
HELPER_ERROR_RMS = 150000.0
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.0
LOW_RAIL_FRACTION = 0.545833333333
HIGH_RAIL_FRACTION = 0.4525
NO_RAIL_FRACTION = 0.00166666667
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
```

頻率誤差也沒有收斂到零附近：

```text
FREQ_ERROR_FIRST = -2164
FREQ_ERROR_LAST = -2400
FREQ_ERROR_MEAN = -2303.4625
FREQ_ERROR_RMS = 2305.96358005
```

因此「方向修正」只修好了 command polarity；它沒有解決目前的第二個瓶頸：
Helper PI 輸入是約 ±150000 的累積 phase error，而輸出因目前增益與 bias
配置直接撞到 5/65531，沒有留下可供 fine lock 的中間控制範圍。這與
Astra 建議的「先分離 actuator direction，再處理 rail/operating-point」一致。

## 判定

本輪不能宣稱 Step5 PASS，也不能詢問或執行 merge。下一輪應先修正 observer
的 signed/absolute position accounting，並以一個可審計的 Helper PI operating
point 實驗確認輸出不再直接 rail；不要再盲目掃描大量 Kp/Ki 組合。優先保留
方向修正，對 Helper PI 的輸出尺度與初始 bias 做最小、可逆、可量測的變更，
完成短時間 30–60 秒觀測後再決定是否進入長時間 lock window。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

本資料夾 `raw/` 保存本輪的：

- `compile-master.log`、`compile-slave.log`
- `firmware-master.log`、`firmware-slave.log`
- `program-master.log`、`program-slave.log`
- `preflight-1.log`、`preflight-2.log`
- `observer-coherent-1200.log`
- `sof-sha256.txt`
