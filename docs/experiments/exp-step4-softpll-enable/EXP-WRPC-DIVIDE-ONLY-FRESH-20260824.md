# 實驗紀錄：SoftPLL input divider 單一變因 fresh A/B

## 實驗資訊

- Experiment ID：`EXP-WRPC-DIVIDE-ONLY-FRESH-20260824`
- 日期：2026-08-24（Asia/Taipei）
- Git branch：`exp/step4-divide-only-fresh`
- Git commit：`cc2d19e1433ba3a8ecf19183146848afbdaf49cc`
- 實驗類型：fresh firmware、Quartus clean compile、雙板 fresh program、read-only Step 2/3 regression

## 實驗名稱

`固定 reverse=false，只把 SoftPLL input divider 設為 false`

## 這次想驗證什麼

在不修改 Master／Slave role、PTP、WR signaling、PHY、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340 演算法的前提下，測試 `g_softpll_divide_input_by_2 => false` 是否能改善 Step 4 前端的 DMTD／accepted event activity。

本輪的前置門檻仍是 Step 2／Step 3 必須先通過。若 role 或 parent/signaling regression 失敗，立即停止，不解讀 Step 4 event 結果。

## 相較 control 的唯一功能變因

相較 `exp/step4-post-div-edge-observability@48ba8b1`：

- Master top 新增 `g_softpll_divide_input_by_2 => false`。
- Slave top 新增 `g_softpll_divide_input_by_2 => false`。
- `wr_core`／`xwr_core`／`wrcore_pkg` 新增 generic，將 divider 與 `g_softpll_reverse_dmtds` 分離。
- `g_softpll_reverse_dmtds` 保持 false；沒有重新使用曾造成 Step 2/3 regression 的 reverse=true。
- 沒有修改 firmware source、role command、PTP、WR signaling、PHY、DDMTD polarity、servo、DCO 或 SI5340 行為。

Source audit 顯示，Master 啟動命令仍為：

```text
vlan off;ptp stop;mode master;ptp start
```

Slave 啟動命令仍為：

```text
vlan off;ptp stop;mode slave;ptp start
```

## 建置 provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Quartus 路徑：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Master MIF SHA-256：`3748b26ffc6d0919222adc8e99eab527deb26ad84797ac6882c464c2001b9dd7`
- Slave MIF SHA-256：`a96bc7494c2e72ccab4b44234a64ac1da2b3549d5e810cadeb66e5e5ff34c59b`
- Master QSF SHA-256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA-256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA-256：`bfb362d7d1b3ae39539c3a24d537d0f82eb0d2f1729f5ae1aa0fee316eea322f`
- Slave SOF SHA-256：`d5ac2888b8badf3b641e8cbd38497d0db3ecba99f8ca0cd690ad07eeff9c328d`
- Master Fitter：Successful；timing closed：`NO`，setup/hold=`-0.363/-0.617 ns`
- Slave Fitter：Successful；timing closed：`NO`，setup/hold=`-0.601/-0.608 ns`
- 建置原始 log：`raw/EXP-WRPC-DIVIDE-ONLY-20260824/build_jtag_master.log`、`build_jtag_slave.log`、`build_info_jtag_master.txt`、`build_info_jtag_slave.txt`

建置結果是兩邊 `Full Compilation was successful`；`TIMING_CLOSED=NO` 必須保留，不能寫成 timing closure 通過。

## 燒錄結果

使用 exact commit fresh SOF：

| 板卡 | Cable | Programmer checksum | 結果 |
|---|---|---:|---|
| Master | `DE5 [1-11.1]` | `0x30B14D0F` | `Configuration succeeded`、0 errors、0 warnings |
| Slave | `DE5 [1-11.2]` | `0x30AE0D80` | `Configuration succeeded`、0 errors、0 warnings |

同一份 image 的 reprogram confirmation 亦保存完整輸出：

- `raw/EXP-WRPC-DIVIDE-ONLY-20260824/EXP-WRPC-DIVIDE-ONLY-20260824-master-program-rerun.log`
- `raw/EXP-WRPC-DIVIDE-ONLY-20260824/EXP-WRPC-DIVIDE-ONLY-20260824-slave-program-rerun.log`

## Step 2／Step 3 read-only regression

使用：

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 500 25
```

第一次 fresh program 後的 barrier：

- Master：valid `21/30`、invalid `9/30`；valid sample 的 role 為 `MODE=3`，Step 2/3 均 FAIL。
- Slave：valid `13/30`、invalid `17/30`；雖曾讀到 `MODE=3/PTP=9`，但 foreign／parent／WR signaling／LOCK_ENABLE 沒有建立，Step 2/3 均 FAIL。

reprogram confirmation 後的 barrier：

- Master：valid `11/30`、invalid `19/30`；valid sample 仍為 `MODE=3`，Step 2/3 均 FAIL。
- Slave：valid `13/30`、invalid `17/30`；foreign metadata、parent flags、WR RX/TX message 與 lock-enable 仍為 0，Step 2/3 均 FAIL。
- 兩次測試都回報 Tcl / Quartus STP `0 errors, 0 warnings`；invalid mailbox frame 被標為 invalid，沒有被當成硬體錯誤。

原始 regression logs：

- `raw/EXP-WRPC-DIVIDE-ONLY-20260824/step23_postprogram_10x500.log`
- `raw/EXP-WRPC-DIVIDE-ONLY-20260824/EXP-WRPC-DIVIDE-ONLY-20260824-step23-rerun-30x500.log`

## Observation

1. fresh compile 與 programming 成功，不代表 Step 2／3 runtime 成功。
2. Master 沒有穩定進入要求的 `MODE=2/PTP=6`；即使 PTP counters 有活動，也不能取代 Master role gate。
3. Slave 沒有看到要求的 `FOREIGN_META=03000001`、parent flags、`SLAVE_PRESENT`／`LOCK` 與 `LOCK_ENABLE>0`。
4. 由於唯一 functional 變因是 divider，且 Master `mode master` 需要先執行 free-running-master SoftPLL 初始化／lock check，最合理的 source-level 解釋是：divider=false 改變了 Master startup 時的 SoftPLL lock path，使 role command 沒有在觀測窗口內完成；這是目前的 leading hypothesis，不是只靠 register snapshot 證明的最終根因。
5. 本輪不應解讀 DMTD／Step 4 activity，因為 Step 2／3 regression barrier 已先失敗。

## 判定

```text
STEP1_REGRESSION = PASS（PHY/link 與 CPU 基本 probe 在 accepted frame 中可讀）
STEP2_REGRESSION = FAIL
STEP3_REGRESSION = FAIL
STEP4_ALLOWED     = NO
```

目前證據比較支持：

```text
HARDWARE/FIRMWARE FAILURE：fresh image 的 role/parent runtime gate 未通過
JTAG/DASHBOARD MEASUREMENT FAILURE：invalid mailbox frame 已被辨識，不能單獨解釋為硬體失敗
```

這個結論不宣稱 divider 是所有問題的唯一根因；它只證明本變因不能在不破壞 Step 2／3 的條件下進入 Step 4。

## Next Step

1. 保留本分支與本輪 raw logs，不再對這份 image 做 Step 4 判讀。
2. 先回到 `g_softpll_divide_input_by_2 => true` 的 Step 2/3 可通過 control image，重新建立可靠 barrier。
3. 重新詢問 White Rabbit 技術應用 reviewer，提供本紀錄與 exact commit；下一個 functional A/B 必須維持 Master role 可重現，不能再讓 divider 變因擋住 regression gate。
4. 在 Step 2／3 fresh/current hardware 再次 PASS 前，不進行 Step 4 functional experiment、不 merge main。
