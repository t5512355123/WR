# EXP-WRPC-STEP4-HIGH-ABORT-WRAP32-20260824

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP4-HIGH-ABORT-WRAP32-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- 實驗 source commit：`3b427696d94afc927db8ce8e3a73a46570589d41`
- 狀態：fresh firmware 與 Quartus clean compile 完成；等待雙板燒錄與 runtime 量測

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
| Master | `DE5 [1-11.1]` | Master fresh SOF | 待測 | 待燒錄 |
| Slave | `DE5 [1-11.2]` | Slave fresh SOF | 待測 | 待燒錄 |

## JTAG / Runtime 原始結果

等待雙板燒錄完成後執行 Step 1～3 regression barrier 與 Step 4 T0/T1。

## Raw evidence

目前 build evidence 位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HIGH-ABORT-WRAP32-20260824/`

燒錄與 runtime logs 將在每個操作完成後立即加入同一資料夾。

## Conclusion

```text
STEP4_RESULT = NOT_YET_EVALUATED
```

compile 成功不等於硬體實驗成功；必須等待 fresh SOF 雙板 program 與 JTAG runtime evidence。
