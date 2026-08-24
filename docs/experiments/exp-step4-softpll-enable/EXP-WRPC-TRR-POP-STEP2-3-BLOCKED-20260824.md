# EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824

## 1. 實驗基本資料

- Experiment ID：`EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824`
- 日期：2026-08-24
- Branch：`exp/step4-softpll-enable`
- Git commit：`1bcbd379581134b3bd7a6cab2bd8edd02b09490a`
- 實驗主機：`pain`
- Quartus：Intel Quartus Prime 17.0 Build 595
- 實驗類型：fresh firmware build、clean Quartus compile、雙板 program、read-only Step 2/3 regression

## 2. 實驗目的

本實驗原本要為 Step 4 的 `TRR` FIFO 取出行為增加一個 source-backed、read-only 的觀測計數器；在進入 Step 4 前，先重新確認 Step 2 Endpoint/MiniNIC/PTP 與 Step 3 WR Parent/Signaling regression gate。

本輪沒有修改 FPGA 的 WR/PTP/SoftPLL/PHY 演算法，也沒有寫入任何 Wishbone control register。因 Step 2/3 regression 未通過，本輪沒有進行 Step 4 functional experiment。

## 3. 相較前一版本唯一修改

相較於前一個 branch HEAD `618fe1c`，本輪只加入 TRR FIFO 取出觀測：

- `wrpc_spll_trr_pop_count` 在 `spll_irq_entry()` 成功讀取 `SPLL->TRR_R0` 後累加。
- 透過 WDIAGS private read-only offset `0x00100B54` 對外提供。
- 更新 JTAG scripts 與 register map 以讀取及顯示該計數器。
- 沒有修改 SoftPLL 的 TRR 讀取、DDMTD、PI、lock threshold、DCO、SI5340 或 WR signaling 行為。

但 source audit 顯示，目前 `1bcbd37` 相對使用者指定的 functional baseline `51864b8743759bc20bea817af4bcd19ea81ab4ac`，仍存在先前實驗累積的 functional tree 差異，包含 DMTD/SoftPLL 相關模組。因此本次結果不能單獨證明 TRR counter 是失敗原因。

## 4. Build 與 provenance

### Master

- QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`8c4fe16907556bee75fbf6af21b3edd65c0a7709686e4295058367bbb64f1a10`
- SOF SHA256：`0d5b7b50e3bc4b0892fb1cca554ca042728a1a5b174923cfbe4262b0c6345c74`
- Programmer checksum：`0x30B32E2A`
- Compile：成功，0 errors，282 warnings
- Timing：未關閉；worst setup `-0.394 ns`

### Slave

- QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`4ad4d920c308de7772b8608b190ebce13fe522d82b2740a688ef687d95fc6760`
- SOF SHA256：`f5a8a486440913789beb9c70ae6e64e16c16a35c38bd7acac2863ee39571c4f7`
- Programmer checksum：`0x30B52E94`
- Compile：成功，0 errors，282 warnings
- Timing：未關閉；worst setup `-0.182 ns`、worst hold `-3.515 ns`

### 燒錄

Master 與 Slave 均顯示：

```text
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

原始 build、program 與 hash 資料位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/`

## 5. Read-only regression 結果

燒錄後等待 60 秒，執行 `read_wr_handshake_focused.tcl 20 500 25`；之後再等待 60 秒，以相同參數重測一次。兩次均由 Quartus SignalTap 成功完成，沒有 Tcl exception。

### Dashboard snapshot

兩片結果相同的部分：

- Step 1 PHY/link：PASS
- CPU reset 已解除、CPU 可讀，MAC identity 正確
- MiniNIC TX/RX counter 有 delta
- PPSI PTP RX/TX counter 有 delta
- RXERR delta = 0

Master：

- `WDIAGS_MODE = 2 MASTER`
- `WDIAGS_PTP = 4 LISTENING`，預期穩態為 `6 MASTER`
- `WDIAGS_PTP_RX delta = 2`
- `WDIAGS_PTP_TX delta = 5`

Slave：

- `WDIAGS_MODE = 3 SLAVE`
- `WDIAGS_PTP = 4 LISTENING`，預期穩態為 `9 SLAVE`
- `WDIAGS_PTP_RX delta = 8`
- `WDIAGS_PTP_TX delta = 3`
- `WDIAGS_FOREIGN_META` 本次 dashboard 讀取為 `TIMEOUT`，沒有有效 parent evidence

### Focused repeated sampling

第一次 20 samples：

```text
Master valid_samples=10 invalid_samples=10 counter_decreased=0
PTP_TX_DELTA=14 STEP2_REGRESSION=FAIL

Slave valid_samples=14 invalid_samples=6 counter_decreased=1
PTP_TX_DELTA=0 STEP2_REGRESSION=INVALID STEP3_REGRESSION=FAIL
STATE_EVIDENCE=READ_INCONSISTENT
```

第二次 20 samples：

```text
Master valid_samples=9 invalid_samples=11 counter_decreased=0
PTP_TX_DELTA=0 STEP2_REGRESSION=FAIL

Slave valid_samples=15 invalid_samples=5 counter_decreased=1
PTP_TX_DELTA=0 STEP2_REGRESSION=INVALID STEP3_REGRESSION=FAIL
STATE_EVIDENCE=READ_INCONSISTENT
```

## 6. 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = FAIL / INVALID
STEP3_REGRESSION = FAIL
STEP4_ALLOWED     = NO
```

### Observation

目前證據支持 PHY、CPU、MAC、MiniNIC 與 PTP counter path 有活動；但兩片都停在 `WDIAGS_PTP=4 LISTENING`，沒有重新建立已知的 Master `PPS_MASTER` 與 Slave `PPS_SLAVE` 穩態。Slave 也沒有取得可接受的 Foreign Master/WR signaling evidence。

因此 Step 2/3 尚未在這個 fresh `1bcbd37` image 上重現成功，不能進入 Step 4。

### 對失敗來源的保守解讀

- 不是 JTAG Tcl exception：兩次 focused script 與 dashboard 都正常結束。
- 不是單一 `A5A51330` 類 invalid enum read 造成的假 FAIL：dashboard 讀到的是可解碼的 `PTP=4`，而且兩次 observation 都呈現相同方向的 runtime 狀態。
- 不能只把 `PTP_TX delta=0` 當成硬體失敗，因為同時看到 PTP RX、MiniNIC TX/RX 活動；但整體 PTP role/state 仍未達 acceptance gate。
- 目前不能把根因指定為 TRR counter，因為 `1bcbd37` 仍包含相對 `51864b...` 的既有 DMTD/SoftPLL functional changes，且本輪尚未做移除 TRR counter 的 A/B。
- timing report 亦顯示未 timing closed；這是風險證據，不足以單獨證明本次 PTP regression 的根因。

## 7. 下一步

1. 保留目前 fresh `1bcbd37` SOF 與本次所有 raw evidence，不覆蓋。
2. 先由 source audit 對照 `51864b874...` 與 `b7d262b...`，辨識哪些 functional delta 可能破壞 Step 2/3。
3. 在未取得可靠 Step 2/3 regression PASS 前，不進行 Step 4 functional experiment。
4. 下一輪若需要重新 program，必須先建立獨立 commit、重新產生 MIF/SOF、保存 hash/programmer output，並立即新增實驗紀錄。

## 8. 原始證據索引

- `raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/step2_3_focused_1bcbd37.log`
- `raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/step2_3_focused_1bcbd37_rerun.log`
- `raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/dashboard_1bcbd37_after_regression.log`
- `raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/program_jtag_master_1bcbd37.log`
- `raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/program_jtag_slave_1bcbd37.log`
- `raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/build_info_jtag_master.txt`
- `raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/build_info_jtag_slave.txt`
- `raw/EXP-WRPC-TRR-POP-STEP2-3-BLOCKED-20260824/remote_sha256.txt`
