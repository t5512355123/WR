# EXP-WRPC-STEP4-D0-STABLE-HIT-20260824

## 實驗識別

- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Source commit：`6a25705feb653e5e9fd108054fc8d95cacbaf2b0`
- 實驗狀態：fresh firmware、Quartus compile、雙板燒錄、Step 1～3 barrier 與 Step 4 T0/T1 已完成
- Hardware source commit：`6a25705feb653e5e9fd108054fc8d95cacbaf2b0`
- 最終診斷 Tcl commit：`6ac8b869acf7fb6f54cd7b57565a988811ba474b`

## 驗證目標

前一輪已證明 Slave REF/FB 的 `clk_i_d0` transition 與後段 sampled
transition 持續活動，但 deglitch accept 與下游 event 仍為零。本輪只回答：
既有 `clk_i_d0` waveform 是否曾出現長度足以通過目前 functional deglitch
threshold 的 stable run。

## 唯一修改變因

- REF 與 FB 各新增一個 64-bit `D0_STABLE_HIT_COUNT64` 唯讀診斷 counter。
- 在既有 sampler DMTD clock domain 直接觀察 `clk_i_d0`，不重新取樣非同步
  `clk_in_i`。
- 第一個 sample 的 run length 為 1；同值持續時增加；值改變時重設為 1。
- 由於既有 functional deglitch FSM 比較舊值 `stab_cntr=T`，每個 stable run
  只在第一次到達 `T+1` samples 時增加一次。
- binary counter 在原 clock domain 轉成 registered Gray code，經兩級同步器
  進入 system clock domain 後再解碼；Wishbone 使用 `HI1 -> LO -> HI2`
  一致性讀取。
- 沒有修改 PTP、WR signaling、SoftPLL、DDMTD polarity、PI gain、lock
  threshold、DCO、SI5340、PHY 或 WRPC firmware 功能行為。

此 counter 只證明 waveform 是否曾出現足夠長的 stable run，不是完整重演
deglitch FSM，也不能單獨證明該 run 當時位於正確 FSM state 或一定會 accept。

## 建置來源與雜湊

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA256：`cf0bf4cfea3b751eb1a6bb9ac6a4e8edae53a12852a2206a7432e05027abe905`
- Slave MIF SHA256：`0896bf06fc985b29a351631f8655d958bbee220620dc47e9b053f9b0a4df4d7f`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`de1568c50ea54381de6357e0afe5c006ee940cb68fe2396689e391ab90b5032d`
- Slave SOF SHA256：`93a1ea028a3a8787238be93dbf2042bfa1bc4c95e939a5ca120a19250ac8a59a`

Master 與 Slave 均回報 `Full Compilation was successful`，compile log 未出現
Quartus Error。整體 timing 尚未 closed：Master setup/hold WNS 為
`-0.394/+0.039 ns`，Slave為 `-0.390/+0.037 ns`。因此後續 runtime 結果
必須保留 timing caveat，不能把單一 counter 結果直接當作功能根因。

## 燒錄結果

- Master：2026-08-24 06:04（Asia/Taipei）燒錄成功；programmer checksum
  `0x30B32E2A`；`Configuration succeeded -- 1 device(s) configured`；
  `0 errors, 0 warnings`。原始輸出保存於
  `raw/EXP-WRPC-STEP4-D0-STABLE-HIT-20260824/program_master.log`。
- Slave：2026-08-24 06:05（Asia/Taipei）燒錄成功；programmer checksum
  `0x30B41C87`；`Configuration succeeded -- 1 device(s) configured`；
  `0 errors, 0 warnings`。原始輸出保存於
  `raw/EXP-WRPC-STEP4-D0-STABLE-HIT-20260824/program_slave.log`。

## Runtime 原始結果

燒錄後執行 dashboard 與 `read_wr_handshake_focused.tcl 30 1000`：

| 板卡 | valid/invalid | PTP TX delta | Step 2 | Step 3 |
|---|---:|---:|---|---|
| Master `DE5 [1-11.1]` | 30/0 | 171 | PASS | N/A |
| Slave `DE5 [1-11.2]` | 30/0 | 21 | PASS | PASS |

Slave 的 accepted samples 全部為 `MODE=3`、`PTP=9`、foreign master
`1/0`、parent metadata `1/0/1`、RX `LOCK 0x1001`、TX
`SLAVE_PRESENT 0x1000`、`LOCK_ENABLE=4`，且 `signal_good=30`、
`signal_bad=0`。live WR state 仍為 30/30 `WRS_IDLE`，與其餘握手證據
衝突，因此依既有 gate 標為 `STATE_EVIDENCE=READ_INCONSISTENT`，不判定
為 Step 3 regression。

原始輸出保存於：

- `raw/EXP-WRPC-STEP4-D0-STABLE-HIT-20260824/dashboard.log`
- `raw/EXP-WRPC-STEP4-D0-STABLE-HIT-20260824/step123_focused.log`

### Step 4 T0/T1

T0、T1 各執行 `10 x 500 ms`，中間等待 10 秒；原始命令為：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 10 500 events
```

兩個視窗的 Slave 主要結果如下：

| 指標 | T0 | T1 |
|---|---:|---:|
| threshold | 1000 | 1000 |
| stable hit length | 1001 | 1001 |
| REF D0 stable hit delta | 0 | 0 |
| FB D0 stable hit delta | 0 | 0 |
| REF D0 transition delta | 706,279,748 | 716,144,582 |
| FB D0 transition delta | 701,346,982 | 711,327,638 |
| REF sampled/D0 | 1.000005062 | 1.000003533 |
| FB sampled/D0 | 0.895520037 | 0.999993575 |
| REF/FB accept delta | 0 / 0 | 0 / 0 |
| event/tag/TRR/IRQ/helper delta | 全部 0 | 全部 0 |

T0/T1 原始輸出保存於：

- `raw/EXP-WRPC-STEP4-D0-STABLE-HIT-20260824/step4_t0.log`
- `raw/EXP-WRPC-STEP4-D0-STABLE-HIT-20260824/step4_t1.log`

T1 曾發現一筆 REF stable-hit 讀值為全 0；這是 JTAG mailbox measurement
failure，不當成硬體下降。後續只修改唯讀 Tcl，新增 stable-hit 64-bit
non-decreasing retry/reject，沒有重新 compile 或燒錄。使用 Tcl commit
`6ac8b86` 在同一份 `6a25705` SOF 上重測 10 筆 raw samples 後：

```text
REF hit samples: 000000005425AA09 (10/10)
FB  hit samples: 000000005AF03E54 (10/10)
REF hit delta = 0
FB   hit delta = 0
threshold = 1000, hit_length = 1001
```

重測的 Slave 結果為：

```text
REF D0 transition delta = 711437140
FB  D0 transition delta = 708913646
REF sampled/D0 = 0.999891666
FB  sampled/D0 = 1.000002950
REF/FB accept delta = 0/0
event/tag/TRR/IRQ/helper delta = 0/0/0/0/0
```

重測原始輸出保存於：

- `raw/EXP-WRPC-STEP4-D0-STABLE-HIT-20260824/step4_raw_retry.log`

## Observation

- Step 1、Step 2、Step 3 regression barrier 均通過，因此允許執行本輪
  Step 4 T0/T1 唯讀觀測。
- 輸入 threshold 在完整視窗穩定為 `T=1000`，因此本輪 stable-hit 的目標
  run length 是 `T+1=1001` 個連續 `clk_i_d0` samples。
- REF/FB 的 D0 transition 在 T0、T1 與 raw retry 都持續大量增加，
  但 stable-hit counter 在 threshold 穩定後沒有增加。
- raw retry 中 sampled/D0 接近 1，表示從 `clk_i_d0` 到後段 sampled
  transition 計數的觀測管線沒有再大量遺失 transition。
- REF/FB deglitch accept、DMTD event、tag、TRR、IRQ 與 helper update
  仍沒有 sustained activity。
- 第一次 raw T1 讀值出現全 0，已由 Tcl non-decreasing retry/reject 排除；
  這一筆屬於 JTAG measurement failure，不是 hardware counter decrease。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_REF_FB_D0_TRANSITION = ACTIVE
SLAVE_REF_FB_D0_STABLE_HIT = NONE_OBSERVED
SLAVE_D0_TO_SAMPLED_PIPELINE = PRESERVED_APPROX_1_TO_1
SLAVE_DEGLITCH_ACCEPT_AND_DOWNSTREAM = NONE_OBSERVED
FIRST_INACTIVE_BOUNDARY = D0_STABLE_THRESHOLD_HIT_TO_DEGLITCH_ACCEPT
ROOT_CAUSE = NOT_PROVEN
```

本輪支持在 threshold `T=1000` 穩定後，沒有觀測到 `clk_i_d0` 出現足以達到
`T+1=1001` 的 stable run；同時 D0 transition 與 sampled transition 都活躍，
而 accept 與下游 event 沒有活動。這把下一個觀測焦點收斂到 D0 stable run
形成與 deglitch acceptance 的邊界，但仍不等於已證明 DDMTD polarity、相位
關係、metastability、threshold 或 timing 是唯一根因。

## Next Step

先將本輪完整證據推送至 GitHub，請 White Rabbit 技術對話審閱後，再決定下一個
只增加 read-only observability 的單一變因；在審閱前不修改 functional behavior。
