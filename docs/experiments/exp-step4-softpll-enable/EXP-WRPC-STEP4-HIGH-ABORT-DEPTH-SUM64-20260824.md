# EXP-WRPC-STEP4-HIGH-ABORT-DEPTH-SUM64-20260824

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP4-HIGH-ABORT-DEPTH-SUM64-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- 實驗 source commit：`8ff33fe7e4c212916ab8e28b355ebb561254d9bf`
- 狀態：fresh firmware、Quartus clean compile、雙板燒錄與 read-only runtime 量測均已完成

## 想驗證什麼

上一輪已證明 Slave REF/FB 的 HIGH qualification abort 在 bounded window
內持續發生，但單看 abort 次數無法知道每次在累積多少個 HIGH
sample 後被 LOW 中斷。本輪只回答：

> Slave REF/FB 每次 HIGH qualification abort 的平均 `stab_cntr` 深度是多少？

## 相較上一輪的唯一變因

- 保留原有 HIGH-abort 觸發條件、32-bit wrapping abort counter、deglitch FSM、
  threshold 與所有 functional path。
- REF/FB 各新增一個 64-bit free-running wrapping diagnostic accumulator；每次既有
  HIGH-abort 發生時，只執行 `depth_sum += zero_extend(stab_cntr)`。
- Wishbone 僅新增四個 read-only words：REF LO/HI 與 FB LO/HI。原有 write-only
  register 的 write side 完整保留。
- Tcl 以 `HI1 -> LO -> HI2` 讀取，只接受 `HI1 == HI2` 的 64-bit 值，
  並以 modulo-2^64 delta 計算平均 abort 深度。
- 未修改 WR role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、
  lock threshold、DCO、SI5340、PHY 或 WRPC firmware functional behavior。

## Build 與 Artifact Provenance

- Quartus：17.0.0 Build 595 Standard Edition
- Master MIF SHA256：`b5bde3d6f458ed34255788627268599a31a9d805b759a8e5d7bb479d6bb8d5b9`
- Slave MIF SHA256：`500461aa3108e99ceffafa1ebbaf4248de9ad53eb4b13b17038cd2d8ab0c5fc9`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`aacd886354b5995d9532de67aa46d24242be9c312ee6fc02af7d789371c7e9f9`
- Slave SOF SHA256：`4a51e881b9f50ba32bd62a4cc2b414d2eddb8a44f0f231e38f8bcb28d35dd0d3`
- Master compile：PASS，`timing_closed=NO`，setup/hold WNS=`-0.451 ns / +0.037 ns`
- Slave compile：PASS，`timing_closed=NO`，setup/hold WNS=`-0.211 ns / +0.037 ns`

`TIMING_CLOSED=NO` 必須保留為 implementation caveat，不可在沒有直接 runtime
證據時宣稱為本輪根因。

## 燒錄結果

| Board | Cable | SOF | Programmer checksum | 結果 |
|---|---|---|---|---|
| Master | `DE5 [1-11.1]` | Master fresh SOF | `0x30ACB311` | configuration succeeded，1 device configured，0 errors / 0 warnings |
| Slave | `DE5 [1-11.2]` | Slave fresh SOF | `0x30AC5A92` | configuration succeeded，1 device configured，0 errors / 0 warnings |

## JTAG / Runtime 原始結果

### Dashboard

- Tcl 完整輸出兩張板的 Step 1～6，0 errors / 0 warnings。
- Master：Step 1/2 pass，`MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`。
- Slave：Step 1/3 pass；單次 dashboard 讀到啟動過渡的 `PTP=8`，因此
  Step 2 標示 `NA` 而非 fail。後續 focused samples 已穩定為 `PTP=9`。

### Step 1～3 regression barrier

`read_wr_handshake_focused.tcl 30 1000` 結果：

| Board | Valid/Invalid | Step 2 | Step 3 | PTP TX delta | 主要證據 |
|---|---:|---|---|---:|---|
| Master | 30/0 | PASS | NA | 169 | `MAC ...:01`、`MODE=2`、`PTP=6` |
| Slave | 30/0 | PASS | PASS | 21 | `MAC ...:02`、`MODE=3`、`PTP=9`、foreign=`1/0`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4` |

Slave 30/30 samples 都具有 WR signaling success evidence。live WR state 在 30 次都是
`WRS_IDLE`，與 LOCK、SLAVE_PRESENT、LOCK_ENABLE 與既有 failure shadow 互相衝突；
依 regression 規則保留 `STATE_EVIDENCE=READ_INCONSISTENT`，不當成 Step 3 regression。

### Step 4 focused T0/T1

通過 barrier 後才執行：

- T0：`10 samples x 500 ms`
- 等待 10 秒
- T1：`10 samples x 500 ms`
- 平均 abort 深度：`delta(depth_sum64) / delta(high_abort_count32)`

Slave 結果：

| Signal | T0 | T1 |
|---|---:|---:|
| REF abort delta（與 depth sum 同組量測） | 307,197,053 | 307,080,095 |
| REF depth-sum delta | 307,360,091 | 307,231,569 |
| REF average abort depth | 1.000531 | 1.000493 |
| FB abort delta（與 depth sum 同組量測） | 307,039,488 | 306,953,925 |
| FB depth-sum delta | 307,040,569 | 306,955,166 |
| FB average abort depth | 1.000004 | 1.000004 |
| REF/FB max depth before abort | 2 / 1 | 2 / 1 |
| REF/FB sampled transition delta | 678,628,562 / 677,920,481 | 678,721,642 / 678,113,202 |
| REF/FB accept delta | 0 / 0 | 0 / 0 |
| tag/TRR/IRQ/helper update delta | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |

- REF/FB depth-sum 每個視窗都是 10/10 valid，沒有 timeout 或 invalid 64-bit read。
- T0/T1 的 Slave deglitch state 均為 `GOT_EDGE/GOT_EDGE`。
- Master REF 也觀測到 abort activity，平均深度約 `1.0055/1.0053`；Master FB
  inactive。本輪問題定位仍以 Slave 為主，不用 Master 結果替 Slave 推論根因。

## Raw evidence

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HIGH-ABORT-DEPTH-SUM64-20260824/`

- `firmware_*_build.log` / `firmware_*_hashes.sha256`
- `quartus_jtag_*_compile.log` / `build_info_jtag_*.txt`
- `program_master.log` / `program_slave.log`
- `dashboard.log`
- `step123_focused.log`
- `step4_t0.log` / `step4_t1.log`
- `EXP-WRPC-STEP4-HIGH-ABORT-DEPTH-SUM64-provenance.txt`

## Observation

新增的 64-bit depth sum 在兩個獨立視窗都與 abort counter 一起持續增加。
Slave REF/FB 的平均 abort 深度都非常接近 1，且視窗內最大值只有
`2/1`。這表示幾乎每次在 `GOT_EDGE` 開始 HIGH qualification 後，只累積一個
HIGH sample 就被 LOW sample 中斷。

同時 accept 與所有下游 event/tag/TRR/IRQ/helper 仍沒有 sustained activity。
新增 readout 沒有出現 abort delta 大於 0 但 sum delta 為 0 的診斷不一致。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_HIGH_ABORT_DEPTH_READOUT = VALID
SLAVE_REF_AVERAGE_ABORT_DEPTH = APPROX_1
SLAVE_FB_AVERAGE_ABORT_DEPTH = APPROX_1
SLAVE_ACCEPT_AND_DOWNSTREAM_ACTIVITY = NONE_OBSERVED
ROOT_CAUSE = NOT_PROVEN
```

本輪支持的最窄結論是：Slave REF/FB 的 HIGH qualification 幾乎都在深度 1
就中斷，因此無法達到 acceptance boundary。這個結果仍不能單獨證明
DDMTD polarity、threshold、implementation timing 或任何特定 functional node 是根因。

## Next Step

將 exact source/artifact/runtime evidence push 至 GitHub，再請 reviewer 依本輪的 fresh
量測指定下一個單一診斷變因。在 reviewer 確認前不修改 functional behavior。
