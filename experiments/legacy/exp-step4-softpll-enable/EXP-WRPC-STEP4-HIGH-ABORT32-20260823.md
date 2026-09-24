# 實驗紀錄：Step 4 DMTD HIGH qualification-abort 32 位元觀測

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-STEP4-HIGH-ABORT32-20260823`
- 日期：2026-08-23（Asia/Taipei）
- branch：`exp/step4-softpll-enable`
- Git commit：`688b152b2551ca51c58b8ec0a40967f5d7e8dca0`
- pain checkout：detached exact HEAD `688b152b2551ca51c58b8ec0a40967f5d7e8dca0`

## 想驗證什麼

上一輪已確認兩板 `clk_sampled` transition 有活動，但 `deglitch accept`、DMTD event 與後續 tag/TRR/IRQ/helper 沒有持續活動。本輪要直接觀察 source 中既有的 HIGH qualification-abort 條件，判斷是否真的反覆發生：

```text
GOT_EDGE && clk_sampled = 0 && stab_cntr /= 0
```

這是 Step 4 的 read-only localization，不是要修改 SoftPLL 或讓它強行 lock。

## 相較 baseline 的唯一修改

本輪只修改 DMTD diagnostics：

- `dmtd_with_deglitcher.vhd` 的 HIGH qualification-abort counter 改成 32-bit natural-wrap counter。
- `wr_softpll_ng.vhd` 讓 `0x001002A0/0x001002A4` 直接輸出 32-bit REF/FB HIGH abort counter。
- JTAG Tcl 改為直接讀 32-bit counter，不再把 32-bit word 解成 LOW/HIGH packed 16-bit 欄位。
- register address 沒有變更，計數條件沒有變更。

沒有修改：Master/Slave role、PTP、WR signaling、SoftPLL algorithm、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或任何 Wishbone control write 行為。

## Build provenance

- Quartus：`Quartus Prime 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- build logs：
  - `raw/EXP-WRPC-STEP4-HIGH-ABORT32-20260823/build_master.log`
  - `raw/EXP-WRPC-STEP4-HIGH-ABORT32-20260823/build_slave.log`
- build wrapper 結果：Master/Slave 均 `Quartus build passed`，但 `timing_closed=NO`；這是本次 build 的實際輸出，不能省略。

### SHA256

```text
HEAD
688b152b2551ca51c58b8ec0a40967f5d7e8dca0

Master MIF
c9c3b3a0d71a6bf6db51de9acb48c63ee25fdd45ed7be21976e8f1d1067029e3
Slave MIF
07265f2ec85fec28dedc7ad94875ac00f307c14c5acce170206c1bcfd0f3fb51

Master QSF
cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f
Slave QSF
c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437

Master SDC
b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8
Slave SDC
b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8

Master SOF
44c0723391b3aa2eebd9738edd206d3fe4f7e0327891a15847eb8b958d183d9e
Slave SOF
91f78782b168a1f354200cc8fd6e778e63a8fa470ed80c74f0134b76c675c960
```

## 燒錄結果

第一次 programmer command 的遠端 shell quoting 錯誤使 `-o p;/path.sof` 被拆成兩個 shell token；Quartus 回報 `Programming option string "p" is illegal`，沒有發生 FPGA configuration。該 raw output 保留在 `program_master.log`，不列為硬體失敗。

修正 quoting 後的 fresh SOF 燒錄：

- Master cable：`DE5 [1-11.1]`
- Master checksum：`0x30A72F9D`
- Slave cable：`DE5 [1-11.2]`
- Slave checksum：`0x30A7AF69`
- 兩片：`Configuration succeeded`、`Successfully performed operation(s)`、0 errors、0 warnings。

之後以同一組 SOF 再做一次 immediate-window repeat，`program_master_repeat.log` 與 `program_slave_repeat.log` 也都顯示相同 checksum 與 configuration success。

## JTAG / runtime 原始證據

所有原始輸出位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HIGH-ABORT32-20260823/`

主要檔案：

- `step23_fresh_retry.log`：fresh program 後等待較長時間的 30-sample Step 2/3 focused regression。
- `step23_post_immediate.log`：重複 fresh program 後的最後 20-sample regression。
- `step4_immediate.log`：重複 program 後的短窗口。
- `step4_post_immediate.log`：短窗口後的 30-sample Step 4 focused series。
- `dashboard_fresh.log`：最後 dashboard。
- `program_*.log`、`build_*.log`：program/build provenance。

## Step 2 / Step 3 結果

`step23_post_immediate.log`：

- Master：valid samples `20/20`、Step 2 PASS、`MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`、`PTP_TX_DELTA=47`。
- Slave：valid samples `20/20`、Step 2 PASS、Step 3 PASS、`MAC=02:00:22:33:44:02`、`MODE=3`、`PTP=9`、`PTP_TX_DELTA=5`。
- Slave `FOREIGN=1/0`、parent=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`。
- `STATE_EVIDENCE=READ_INCONSISTENT`、`POST_STEP3_LOCK_STAGE=TIMEOUT` 被保留為觀測結果，不把單一 shadow state 直接改判成 Step 3 failure。
- Quartus STP script successful，0 errors、0 warnings。

`dashboard_fresh.log` 也顯示兩板 Step 1 PASS、兩板 Step 2 PASS、Slave Step 3 PASS。

## Step 4 結果

### Immediate window

`step4_immediate.log` 在重複燒錄後立即觀測到：

- Master HIGH abort：REF/FB `0/0`；sampled transition 有活動，accept 仍為 0。
- Slave HIGH abort：REF/FB `0/0`；sampled 與 accept 都有活動，DMTD event 有活動，boundary 前進至 `DMTD_TO_TAG_REQUEST`。

這表示 reset 後短時間內，Slave 確實可以跨過部分 deglitch boundary；不能只用長時間後的飽和值描述所有狀態。

### 30-sample window

`step4_post_immediate.log` 的 Slave：

```text
DMTD_REF_SAMPLED delta = 1168349225
DMTD_FB_SAMPLED  delta = 1165869005
DMTD_REF_ACCEPT  delta = 0
DMTD_FB_ACCEPT   delta = 0
DMTD_REF_SEEN    delta = 584189670
DMTD_FB_SEEN     delta = 582950225
DMTD events/tag/TRR/IRQ/helper = 0
```

同期 `SPLL_DMTD_STATE` 是 `ref_state=2, fb_state=2`，兩邊 threshold reached=1；boundary 為 `DMTD_DEGLITCH_ACCEPT`。因此本輪第一次取得直接的 HIGH abort 計數證據：大量 sampled transition 被 qualification abort，沒有形成 accepted edge。

Master 在同一長窗口的 sampled counter 出現 32-bit decrease/reset，Tcl 已標為 `DECREASED_OR_RESET`；其 HIGH abort delta 是 0。這是 counter wrap/reset 的量測限制，不拿來宣稱 Master 功能失敗。

## 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
```

目前證據支持：

1. fresh HEAD 的 Step 2/3 regression 已重現。
2. JTAG mailbox 在關鍵 series 中沒有 timeout/invalid，STP 完整成功。
3. Slave 的第一個明確 inactive boundary 是 `GOT_EDGE` HIGH qualification abort，而不是 PTP、Foreign Master、WR signaling 或 JTAG dashboard invalid read。

目前證據不支持：

- 尚不能把 `GOT_EDGE` abort 的物理根因定義成 PHY 壞掉。
- 尚不能宣稱 SoftPLL lock、time_valid 或 Step 4 PASS。

因此：

```text
HARDWARE/FIRMWARE_FAILURE = ROOT_CAUSE_NOT_PROVEN
JTAG/DASHBOARD_MEASUREMENT_FAILURE = NOT_OBSERVED_FOR_KEY_SAMPLES
```

## Next Step

先保持 `688b152` 與目前 SOF 不變，請外部 White Rabbit review 根據這次 direct HIGH-abort evidence 決定下一個單一 read-only source diagnostic。優先沿 `clk_sampled -> GOT_EDGE -> stab_cntr -> deglitch accept` 檢查 qualification abort 的來源與 threshold/clock-domain證據；不要在沒有下一個明確變因前修改 DDMTD polarity、SoftPLL algorithm、PI、lock threshold、DCO、SI5340 或 PHY。
