# EXP-WRPC-STEP4-HIGH-ABORT-WRAP32-20260824

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP4-HIGH-ABORT-WRAP32-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- 實驗 source commit：`3b427696d94afc927db8ce8e3a73a46570589d41`
- 狀態：fresh firmware、Quartus clean compile、雙板燒錄與 runtime 量測均已完成

## 想驗證什麼

上一輪證明 Slave REF/FB 32-bit HIGH qualification-abort counter 在 bounded observation
開始前已飽和為 `0xFFFFFFFF`，使 `delta=0` 無法判斷目前活動。本輪只回答：

> Slave 位於 `GOT_EDGE` 時，HIGH qualification 是否持續累積後被 LOW sample 中斷？

## 相較上一輪的唯一修改

- 保留 HIGH qualification-abort 的 source condition 完全不變：
  `state = GOT_EDGE && stab_cntr != 0 && clk_sampled = 0`。
- 只把 `dbg_high_qual_abort_count` 的 arithmetic 從 32-bit saturating 改為 32-bit
  free-running wrapping counter。
- focused Tcl 只對 `0x001002A0/0x001002A4` 使用 unsigned modulo-32 delta。
- LOW-abort counter、deglitch FSM、threshold、sampler、WR role、PTP、WR signaling、
  SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 與 WRPC
  firmware functional behavior 均未修改。

## Build 與 Artifact Provenance

- Quartus：17.0.0 Build 595 Standard Edition
- Master MIF SHA256：`5a24c5985db8e56b2aca79a968bc8461f4b4190e3b3a92d35064918a3c2b3099`
- Slave MIF SHA256：`b2de3b2c7c3036abdf37e60014bcee9d92d9414c649f6270f5fcbe6b7bca1fdf`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`b9c2a303823ed960965e54038a1d3e457cc2d02f71da55a49113a8460537743b`
- Slave SOF SHA256：`b9c39dd63ba72fcb3ac9fd9f69241e7b8a67aedc6641fbb5624a4b19f93e9247`
- Master compile：PASS，`timing_closed=NO`，setup/hold WNS=`-0.438 ns / +0.037 ns`
- Slave compile：PASS，`timing_closed=NO`，setup/hold WNS=`-0.178 ns / +0.035 ns`

`TIMING_CLOSED=NO` 是 implementation caveat，不能在沒有直接 runtime 證據時宣稱為
本輪根因。

## 燒錄結果

| Board | Cable | SOF | Programmer checksum | 結果 |
|---|---|---|---|---|
| Master | `DE5 [1-11.1]` | Master fresh SOF | `0x30ADC41E` | configuration succeeded，0 errors / 0 warnings |
| Slave | `DE5 [1-11.2]` | Slave fresh SOF | `0x30AD7EE3` | configuration succeeded，0 errors / 0 warnings |

## JTAG / Runtime 原始結果

### Dashboard

- Tcl 正常結束，0 errors / 0 warnings。
- Master：Step 1/2 PASS，`MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`。
- Slave：Step 1 與 Step 3 PASS；單次 dashboard 在啟動過渡期間讀到 `PTP=8`
  (`UNCALIBRATED`)，因此該次 Step 2 是 `NA`，未把 transitional sample 當成 regression。

### Step 1～3 regression barrier

`read_wr_handshake_focused.tcl 30 1000` 結果：

| Board | Valid/Invalid | Step 2 | Step 3 | PTP TX delta | 主要證據 |
|---|---:|---|---|---:|---|
| Master | 30/0 | PASS | NA | 165 | `MAC ...:01`、`MODE=2`、`PTP=6` |
| Slave | 30/0 | PASS | PASS | 16 | `MAC ...:02`、`MODE=3`、`PTP=9`、foreign=`1/0`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4` |

Slave 30/30 samples 都有 WR signaling success evidence。單獨的 live WR state 讀值持續為
`WRS_IDLE`，與 LOCK、SLAVE_PRESENT、LOCK_ENABLE 及既有 failure shadow 衝突，因此依既定
regression 規則保留為 `STATE_EVIDENCE=READ_INCONSISTENT`，不把它誤判成 Step 3 regression。

### Step 4 focused T0/T1

兩次量測均為 `10 samples x 500 ms`，中間等待 10 秒。下列 HIGH-abort delta
使用 unsigned modulo-32 計算：

| Slave signal | T0 delta | T1 delta |
|---|---:|---:|
| REF sampled transition | 689,533,914 | 689,360,637 |
| FB sampled transition | 688,719,357 | 688,512,742 |
| REF HIGH qualification abort | 344,766,461 | 344,677,586 |
| FB HIGH qualification abort | 344,367,796 | 344,253,442 |
| REF/FB accept | 0 / 0 | 0 / 0 |
| tag/TRR/IRQ/helper update | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |

其他 bounded evidence：

- Slave T0/T1 current deglitch state 都是 `GOT_EDGE/GOT_EDGE`。
- `ref_max_before_abort/fb_max_before_abort`：T0=`22/4`，T1=`26/4`。
- LOW qualification abort 與 WAIT_EDGE entry 在 T0/T1 都沒有 sustained delta。
- 所有 focused register series 都有 10/10 valid samples；本輪關鍵 HIGH-abort 結果不是
  JTAG timeout、invalid sample 或飽和值造成。
- Master 的 HIGH-abort delta 為 0；本輪問題定位以 Slave 為主，不用 Master 的 inactive
  channel 推論 Slave 根因。

## Raw evidence

完整 build、program 與 runtime evidence 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HIGH-ABORT-WRAP32-20260824/`

- `program_master.log` / `program_slave.log`
- `dashboard.log`
- `step123_focused.log`
- `step4_t0.log` / `step4_t1.log`

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_HIGH_QUAL_ABORT_ACTIVE = YES
SLAVE_CURRENT_DEGLITCH_STATE = GOT_EDGE/GOT_EDGE
SLAVE_ACCEPT_AND_DOWNSTREAM_ACTIVITY = NONE_OBSERVED
ROOT_CAUSE = NOT_PROVEN
```

本輪已排除「HIGH-abort counter 飽和所以看不見目前活動」這個診斷限制。直接證據支持：
Slave sampled input 持續活動，deglitcher 位於 `GOT_EDGE`，而 HIGH qualification 反覆被 LOW
sample 中斷，沒有形成新的 accepted DMTD event，所以下游 tag/TRR/IRQ/helper 沒有活動。

這仍不能單獨證明 DDMTD polarity、qualification threshold、時序違反或其他特定項目就是
根因；下一步需維持單一變因，依 reviewer 對這份 fresh runtime evidence 的判讀再決定。
