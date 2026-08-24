# EXP-WRPC-STEP4-POSTDIV-20260824

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-POSTDIV-20260824`
- 日期：2026-08-24（台北時間）
- Branch：`exp/step4-post-div-edge-observability`
- Git commit：`e97520fcaab7c4e621305c82f8925c38ff342737`
- 實驗名稱：SoftPLL sampler 除頻後 edge rate 唯讀觀測
- 目的：直接量測實際送入 DMTD sampler 的 post-divider edge rate，驗證目前 `D0` 近乎逐拍翻轉是否與有效 `/2` 除頻一致。

本輪只增加/使用診斷觀測，不修改 Master/Slave role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 firmware 功能行為。

## Source / Build provenance

- Pain checkout：exact detached HEAD `e97520fcaab7c4e621305c82f8925c38ff342737`
- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`fae6f1d749f6babcd1fe905c6c4fa20ff7e237d5d3ff52f7cdff62808899bfd7`
- Slave MIF SHA256：`45985d0443aaad940380fad9eb60582bcf1a1d5108a2d2c39ea1a29ea60ab9f5`
- Master SOF SHA256：`bff263cbf119e112e95d7e39968f9c12cb2d9698720eda1c06ee235ac4b4d3b2`
- Slave SOF SHA256：`563aaeccc23c07dac5e383d885c19b34826947782a7956d488f15efad2f86a02`
- Master programmer checksum：`0x30AA3EE5`
- Slave programmer checksum：`0x30B06A0E`
- Timing：Master `TIMING_CLOSED=NO`, WNS `-0.399 ns`; Slave `TIMING_CLOSED=NO`, WNS `-0.182 ns`

Master/Slave 均執行 Quartus clean compile，回報 `Full Compilation was successful`。兩片燒錄均回報 `Configuration succeeded`、0 errors、0 warnings。

## 本輪實驗變因

新增的觀測欄位：

- `REF_POST_DIV_EDGE_COUNT64`
- `FB_POST_DIV_EDGE_COUNT64`

計數器在實際 post-divider `clk_in` domain 計數，使用 Gray code、兩級 CDC 與 64-bit Wishbone readback。它不接回任何 sampler、deglitcher 或 SoftPLL functional path。

## Step 2 / Step 3 regression

`read_step23_register_reliability.tcl 30 500 all`：

- Master：30/30 valid，MAC `02:00:22:33:44:01`、MODE `2`、PTP `6`、PTP/MiniNIC activity、RXERR 維持 0。
- Slave：30/30 valid，MAC `02:00:22:33:44:02`、MODE `3`、PTP `9`、`FOREIGN_META=03000001`、PTP/MiniNIC activity、RXERR 維持 0、`LOCK_ENABLE=4`。
- Step 2：PASS。
- Step 3：PASS；focused samples 取得 parent WR/calibrated、RX `0x1001 LOCK`、TX `0x1000 SLAVE_PRESENT`。live state 仍顯示 `WRS_IDLE`，因此保留 `STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`，沒有把它誤寫成 Step 3 failure。

## Step 4 T0/T1 結果

測試命令：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 10 500 events
```

兩個視窗均觀察到：

| 指標 | Master T0 | Master T1 | Slave T0 | Slave T1 |
|---|---:|---:|---:|---:|
| DMTD native edge delta | 737,654,768 | 737,749,253 | 737,602,899 | 737,939,822 |
| REF native edge delta | 737,628,976 | 737,707,035 | mailbox cross-field invalid | 738,019,664 |
| FB native edge delta | 737,625,627 | 737,704,019 | 737,702,064 | 738,008,477 |
| REF post-div edge delta | 368,815,226 | 368,848,986 | 368,850,655 | 368,996,206 |
| FB post-div edge delta | 368,815,011 | 368,848,939 | 368,850,475 | 368,993,579 |
| REF post-div/native | 0.500001 | 0.499994 | cross-field invalid | 0.499982 |
| FB post-div/native | 0.500003 | 0.499996 | 0.499999 | 0.499986 |
| D0 transition | 731,370,311 | 731,308,936 | 735,987,910 | 736,250,885 |
| sampled transition | 731,372,877 | 731,432,432 | 656,177,097 | mailbox cross-field invalid |
| REF/FB accept delta | 0/0 | 0/0 | 0/0 | 0/0 |
| event/tag/TRR/IRQ/helper | 0/0/0/0/0 | 0/0/0/0/0 | 0/0/0/0/0 | 0/0/0/0/0 |

其中 Slave T0 的部分跨 register 欄位出現非原子讀值，已標示為 measurement invalid；不以該欄位做硬體結論。所有 64-bit post-div counter 本身均為 valid、單調增加的讀值。

## Observation

1. Fresh HEAD 的 Step 1～3 regression gate 重新通過，表示本輪診斷沒有破壞 Endpoint、MiniNIC、PTP 或 WR handshake。
2. REF/FB native edge 約 125 MHz，而 post-divider edge 約為 native 的一半；這與目前 sampler 有效 `/2` 除頻的 source hypothesis 一致。
3. D0 與 sampled transition 持續增加，且大致保留 transition；但 deglitch accept、event、tag、TRR、IRQ、helper 都沒有 sustained activity。
4. `RCER=1`、SoftPLL sequence 已離開 disabled，但 Step 4 所需的 downstream activity 尚未出現。
5. 目前 timing 尚未 closed，因此不能把 post-div ratio 單獨宣稱為唯一根因。

## 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
ROOT_CAUSE       = NOT_PROVEN
```

本輪支持：目前有效 sampler input 的 edge rate 確實約為 native input 的一半，且這個現象與 `D0` 高頻 transition、deglitch accept 為零的行為一致。

本輪尚不能支持：已證明 `/2` 是唯一 causal root cause、DDMTD polarity 必須修改、threshold/FSM 有 bug、timing violation 已是根因，或 Step 4 已完成。

## 原始證據

- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/firmware_build.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/quartus_master_compile.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/quartus_slave_compile.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/provenance_build.txt`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/program_master.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/program_slave.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/step23_reliability.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/step3_focused.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/step4_t0.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/step4_t1.log`
- `raw/EXP-WRPC-STEP4-POSTDIV-20260824/dashboard.log`

## Next Step

本輪結果先交由 White Rabbit 技術對話複核。尚未修改任何 functional variable；下一輪若要進行 A/B，必須另開分支並只改一個明確的 sampler configuration，保留本輪 SOF、raw logs 與 provenance。
