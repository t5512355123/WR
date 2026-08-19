# DE5a White Rabbit 目前狀態

最後更新：2026-08-19

目前研究分支：`exp/step3-wr-handshake`

本頁只整理目前證據與下一個研究 gate。既有燒錄實驗與 raw log 保留在 `docs/experiments/`，沒有刪除或改寫任何既有實驗紀錄。

## 目前結論

目前已經由 current branch 的 fresh HEAD 完成 firmware build、clean Quartus compile、雙板 programming 與 30 秒 JTAG time-series，並有足夠證據證明：

- QSFP-A lane 0 的 PHY/link baseline 可工作。
- Endpoint identity 已分離，兩端 MAC 分別為 `02:00:22:33:44:01` 與 `02:00:22:33:44:02`。
- Master runtime 為 `MODE=2`、`PTP=6`；Slave runtime 為 `MODE=3`、`PTP=9`。
- Master/Slave 的 PPSI-level PTP RX/TX counter 有活動。
- Slave `FOREIGN_META=0x03000001`，表示已找到一筆 foreign master record，並讀到 parent WR configuration。

這些 fresh HEAD 證據足以讓 **Endpoint / MiniNIC / PTP packet path（Step 2）判定為 PASS**。此外，Slave 已完成 Foreign Master discovery、`SLAVE_PRESENT`／`LOCK` signaling handshake，並進入 `WRS_S_LOCK`，因此 **WR Parent/Signaling（Step 3）判定為 PASS**。但是 Slave `PSTAT.locked=0`、`status_probe bit 4 time_valid=0`，所以目前不能宣稱 White Rabbit timing synchronization 已完成。

## 六步 milestone

| Step | 目標 | 狀態 | 證據或缺口 |
|---:|---|---|---|
| 1 | QSFP/Native PHY | **PASS** | link、PHY ready、RX/TX ready 的 status probe baseline 可觀察 |
| 2 | Endpoint/MiniNIC/PTP | **PASS** | MAC identity 分離；PTP state/counters 活動；Slave `FOREIGN_META=03000001` |
| 3 | WR Parent/Signaling | **PASS** | `PTP=9`、`FOREIGN_META=03000001`、`tx_msg=0x1000`、`rx_msg=0x1001`、`fail_state=2 (WRS_S_LOCK)`；30 秒 time-series 通過 |
| 4 | SoftPLL Enable | **NOT DONE** | 尚無 `PSTAT.locked=1` 證據；不能以 clock activity 代替 lock |
| 5 | DDMTD/SoftPLL/Si5340 closed loop | **NOT DONE** | 尚未證明 DDMTD（Digital Dual-Mixer Time Difference）到 SoftPLL、再到 SI5340 DCO 的閉迴路完成 |
| 6 | Global Time/execute_at(T) | **NOT DONE** | 尚未實作或驗證依共同 Global Time 在指定 `T` 啟動 accelerator |

## 2026-08-19 fresh HEAD JTAG 證據摘要

| 節點 | MODE | WDIAGS_PTP | MAC | WDIAGS_PTP_RX | WDIAGS_PTP_TX | WDIAGS_FOREIGN_META |
|---|---:|---:|---|---:|---:|---:|
| Master | 2 | 6 | `02:00:22:33:44:01` | 持續增加 | 持續增加 | 不適用 |
| Slave | 3 | 9 | `02:00:22:33:44:02` | 持續增加 | 持續增加 | `0x03000001` |

Step 3 signaling accepted samples：

- Master：`rx_msg=0x1000`、`tx_msg=0x1001`、`fail_state=3`
- Slave：`rx_msg=0x1001`、`tx_msg=0x1000`、`fail_state=2`、`WR_LOCK enable=4`
- Slave：30/30 筆 time-series samples 通過；Master：20/30 筆 accepted，其他為 frame consistency retry

### 證據界線

- `WDIAGS_PTP=6` 是 PPS_MASTER，`WDIAGS_PTP=9` 是 PPS_SLAVE。
- `WDIAGS_PTP_RX/TX` 是 PPSI-level PTP counters，不是 MiniNIC frame counters。
- `WDIAGS_TX/RX` 來自 `minic_get_stats()`，只能解讀為 MiniNIC frame-level traffic。
- `FOREIGN_META=03000001` 是 foreign master / parent discovery 證據，不等於 SoftPLL lock。
- `PSTAT.locked=0` 與 `time_valid=0` 是目前尚未完成 WR timing synchronization 的直接證據。

## 來源與硬體 provenance

先前的恢復成功實驗使用 historical `c88cc05` clean SOF；本次 Step 3 驗證則使用 `exp/step3-wr-handshake` 的 fresh HEAD build 與 fresh SOF。兩者必須分開解讀。current fresh build provenance 如下：

| 節點 | SOF SHA256 | programmer checksum | MIF SHA256 |
|---|---|---|---|
| Master | `008bcf4cc8d7a9816421ab35222c284a9a657114ed57472ef39b1cd472955120` | `0x30A3010A` | `5360a85577bf8235058ac6bfe63db1dd6e5c135db99637fa69e684868868eb34` |
| Slave | `15f2e983e86fc76900fc379ef619ea326e22b824a92d260ea40f2a9701f14248` | `0x30A3C3D7` | `bc46c529d66464acbb914b4cc325ff7489037982e7b6d32d9ed02b750feef3e5` |

每次新的 runtime log 都要記錄：實際 SOF SHA256、SOF 來源 commit/branch、Master/Slave MIF SHA256、Quartus 版本、programmer checksum，以及 JTAG decode script 的 commit 或 blob SHA256。

## 本次文件整理範圍

本次只更新：

- `docs/debug/jtag_register_map.md`
- `STATUS.md`
- `docs/MERGE_READINESS.md`
- `docs/experiments/exp-step3-wr-handshake/EXP-WRPC-STEP3-FRESH-HEAD-20260819.md`

本次文件更新沒有修改 functional RTL、PTP algorithm、SoftPLL algorithm、PHY 或 SI5340 DCO control；Step 3 fresh HEAD 的硬體實驗與原始輸出已在 `EXP-WRPC-STEP3-FRESH-HEAD-20260819.md` 記錄。

## 下一步

1. 保留 Step 3 fresh HEAD、SOF、programmer 與 JTAG raw logs，維持完整 provenance。
2. 保留 `exp/step3-wr-handshake` 作為 Step 3 milestone 的研究歷史。
3. 下一階段另行研究 SoftPLL lock／`time_valid`，並維持單一功能變因；本頁的 Step 3 PASS 不代表 Step 4/5 已完成。
