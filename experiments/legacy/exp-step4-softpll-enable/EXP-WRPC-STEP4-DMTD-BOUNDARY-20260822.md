# EXP-WRPC-STEP4-DMTD-BOUNDARY-20260822

## 實驗基本資料

- 實驗名稱：Step 4 DMTD 邊界唯讀觀測
- 日期：2026-08-22
- Git branch：`exp/step4-softpll-enable`
- Git commit：`5074e0e44cc2ef16c993489ab092e28dbb0b0a99`
- 實驗目的：在不改變 White Rabbit functional 行為的前提下，辨識 Step 4 中 DMTD event、tag、TRR、IRQ 與 helper activity 的第一個無活動邊界。
- 唯一變因：只新增 DMTD `clk_sampled` transition counter 與 `new_edge_p_dmtdclk` deglitch accept counter，並將其封裝到既有 read-only diagnostics register；這些 counter 不接回 functional path。

## 明確未修改項目

本次沒有修改 Master/Slave role、PTP 演算法、WR signaling 演算法、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional RTL。沒有寫入任何 runtime Wishbone control register。

## Build provenance

本次由 pain 在 exact HEAD `5074e0e44cc2ef16c993489ab092e28dbb0b0a99` 執行 fresh firmware build 與 Quartus clean compile。

### Master

- Project：`DE5a_wr_master_jtag`
- MIF SHA256：`13ec6ac7fd6fa3e9396dd2f116271cb770a8f587739a367512f42c38b6f4f7bc`
- QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- SOF SHA256：`c7d7f861eb19cf66e4d14201c68a945c66861856ae962dad06b7bc257e244f34`
- Programmer checksum：`0x309EF758`
- Quartus：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Compile：`Full Compilation was successful`
- Timing：`TIMING_CLOSED=NO`，worst setup slack `-0.204 ns`

### Slave

- Project：`DE5a_wr_slave_jtag`
- MIF SHA256：`cd0799f35ede0eaa5daba39f7acda92f913570b918498872ab348a5060d832c1`
- QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- SOF SHA256：`187d2521cbc215b41b6ec2584e2a3822e86a3260c7ab6cd4a2f20f471194c15f`
- Programmer checksum：`0x30A56A72`
- Quartus：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Compile：`Full Compilation was successful`
- Timing：`TIMING_CLOSED=NO`，worst setup slack `-0.187 ns`

## 燒錄證據

- Master cable：`DE5 [1-11.1]`
- Slave cable：`DE5 [1-11.2]`
- Master 結果：`Configuration succeeded`，0 errors，0 warnings。
- Slave 結果：`Configuration succeeded`，0 errors，0 warnings。
- 原始 Programmer log：
  - `raw/program_master_5074e0e_20260822.log`
  - `raw/program_slave_5074e0e_20260822.log`

## Runtime 測試方法與原始證據

所有 runtime 讀取均為 read-only，沒有寫入 Wishbone control register，也沒有重新燒錄或重開機。

1. Step 2 / 長時間封包觀測：
   `quartus_stp -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 30 500`
2. Step 2 / Step 3 focused repeated sampling：
   `quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 500`
3. Step 4 DMTD boundary sampling：
   `quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 30 500 all --raw`

原始 output：

- `raw/regression_long_fresh_5074e0e_20260822.log`
- `raw/regression_handshake_fresh_5074e0e_20260822.log`
- `raw/regression_step4_fresh_5074e0e_20260822.log`

三個 Tcl 執行皆以 exit code 0 結束，Quartus SignalTap II 顯示 `0 errors, 0 warnings`。

## Observation

### Step 1：PHY / Link

- Master repeated samples：status `0xFF`，CPU、PHY、link bits 均維持健康值。
- Slave repeated samples：status `0xEF`；PHY/link/RX/TX ready 與 encoding-error bits 維持健康，bit4 `time_valid=0` 不屬於本次 Step 1 gate。
- Master/Slave 的 `cpu_reset=0`、`fault=0`、`im_valid=1`、`cpu_marker=0xB004` 且 `seen=1`。

本次 fresh SOF 的 Step 1 evidence 可判定 PASS。

### Step 2：Endpoint / MiniNIC / PTP

長時間 repeated sampling 顯示：

| 項目 | Master | Slave |
|---|---|---|
| MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` |
| MODE | `2` | `3` |
| PTP state | `6` | `9` |
| PTP counter | TX 持續增加 | RX/TX 持續增加 |
| MiniNIC counter | 持續增加 | 持續增加 |
| RXERR | 未見持續增加 | `0` 且未見持續增加 |
| FOREIGN_META | 不適用 | `0x03000001` |

Slave 的 `FOREIGN_META=0x03000001` 仍可由 source-defined mapping 解碼為 foreign master count `1`、best index `0`。因此 fresh HEAD 的 Endpoint / MiniNIC / PTP packet path 有 repeated evidence，可判定：

`STEP2_REGRESSION=PASS`

focused script 的 Master summary 顯示 `STEP2_REGRESSION=FAIL`，但該腳本的 Master-side gate 不是完整 Master/Slave acceptance gate；與長時間 raw evidence 不一致時，本紀錄採用逐欄位 repeated evidence，不採用該孤立 aggregate line 作硬體失敗結論。

### Step 3：WR Parent / Signaling Handshake

Slave focused 30 samples 中，以下項目成立：

- Foreign master：`1`，best index：`0`
- parent is WR：source-defined parse field 顯示 `1`
- parent calibrated：source-defined parse field 顯示 `1`
- TX message：`0x1000`，`SLAVE_PRESENT` count `4`

但同一組 fresh runtime 中：

- RX message 沒有穩定出現 `0x1001 LOCK`
- `LOCK_ENABLE=0`
- `polls=0`
- `state_idle=30/30`
- `state_good=0/30`
- `STATE_EVIDENCE=READ_INCONSISTENT`

因此不能把本次 fresh run 標成 Step 3 PASS。現階段最保守的 regression 結論是：

`STEP3_REGRESSION=NOT_PASS`

這是「本次 fresh runtime 尚未取得 Step 3 acceptance evidence」；它不是單靠 dashboard shadow state 就宣稱 WR 演算法根因。Step 4 functional experiment 依 regression barrier 暫停。

### Step 4：DMTD 到 SoftPLL startup 的 boundary

`read_step4_startup_focused.tcl` 的 30-sample raw evidence：

- Master：`DMTD_REF_EVENTS` 與 `DMTD_FB_EVENTS` 維持不變，`RCER=0`，tag pending/grant/valid、TRR write、IRQ、helper update 全部沒有 activity。
- Slave：`DMTD_REF_EVENTS` delta `126,366,907`，`DMTD_FB_EVENTS` delta `126,264,797`，表示 system-visible DMTD event counter 有 activity；但是 tag pending/grant/valid、TRR write、IRQ、helper update 全部仍為 0，`RCER=0`、`OCER=0`。
- Slave 的 `SPLL_MODE_SEQUENCE` / `SPLL_DMTD_STATE` 有變化，但尚未形成 Step 4 acceptance 所需的 downstream event chain。

因此本次不判定 Step 4 PASS：

`STEP4_REGRESSION=NOT_PASS`

若只看目前可見的 activity boundary：

- Master 的第一個可疑邊界在 DMTD event generation 之前或其觀測點。
- Slave 的 DMTD event 已有 activity，但從 DMTD event 到 tag request/SoftPLL downstream path 沒有看到 pending、tag、TRR、IRQ 或 helper activity。

這個結果不能直接當作 Step 4 functional root cause，因為 Step 3 在同一 fresh run 尚未通過；依 barrier 不進行 Step 4 演算法修改。

### DMTD packed counter 的量測限制

本次新增的 A0/A4 packed diagnostic 只攜帶 sampled/accept counter 的低 15 bits。低位 counter 在觀測窗口內可以自然 wrap，且多位元跨 clock domain read 不是 atomic snapshot。因此 Tcl 看到 `DECREASED_OR_RESET` 時，只能標示 packed measurement 不足以判斷 reset；不能把它直接當成硬體 failure。

相對地，本次判讀 DMTD activity 優先使用既有完整 `DMTD_REF_EVENTS` / `DMTD_FB_EVENTS` register 的 repeated delta。後續若要改善 dashboard，只能先修 read-only counter decode/overflow 顯示，不改 functional path。

## Regression Barrier 結果

| Gate | 結果 | 證據 |
|---|---|---|
| Step 1 PHY / Link | PASS | fresh SOF repeated status、CPU marker、PHY/link bits |
| Step 2 Endpoint / MiniNIC / PTP | PASS | unique MAC、MODE/PTP、PTP/MiniNIC activity、FOREIGN_META |
| Step 3 WR Handshake | NOT_PASS | fresh 30 samples 未取得穩定 LOCK/LOCK_ENABLE |
| Step 4 SoftPLL Startup | NOT_ALLOWED | Step 3 barrier 未通過；downstream activity 也未形成 acceptance chain |

## Conclusion

本次已證明 exact HEAD `5074e0e44cc2ef16c993489ab092e28dbb0b0a99` 可以完成 fresh firmware build、Quartus clean compile、雙板 fresh SOF program，且 fresh hardware 的 Step 1 與 Step 2 repeated evidence 成立。

本次沒有證明 Step 3 PASS，也沒有證明 Step 4 PASS。Step 4 目前不能開始 functional experiment。現有證據應分成兩類：

1. **JTAG/diagnostic measurement limitation**：packed 低 15-bit DMTD counter 的 wrap/非 atomic read，不能直接作為硬體錯誤。
2. **fresh runtime 尚未達 acceptance**：Slave 未重現 `LOCK=0x1001` 與 `LOCK_ENABLE>0`，且 DMTD downstream counters 沒有形成完整 activity chain。

目前沒有足夠證據宣稱 PTP、WR signaling 或 SoftPLL 演算法的根因；依要求不修改這些 functional behavior。

## Next Step

1. 先請 White Rabbit 技術專家 review 本次 fresh Step 2/3/4 raw logs。
2. 先做 read-only source/runtime audit，釐清 Step 3 的 LOCK/LOCK_ENABLE 未重現，以及 Master/Slave DMTD event 差異。
3. 若只需改善觀測，將 packed 15-bit counter 改以 modulo-wrap/invalid 狀態呈現，避免把自然 wrap 誤判成 reset；這仍不改 FPGA functional path。
4. 在 Step 3 取得 repeated PASS 前，不燒錄新的 Step 4 functional image，也不修改 SoftPLL、DDMTD、PI、DCO 或 SI5340 行為。
