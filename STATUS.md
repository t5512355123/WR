# DE5a White Rabbit 目前狀態

最後更新：2026-08-19

目前研究分支：`exp/restore-c88cc05-baseline`

本頁只整理目前證據與下一個研究 gate。既有燒錄實驗與 raw log 保留在 `docs/experiments/`，沒有刪除或改寫任何既有實驗紀錄。

## 目前結論

目前已經由 current branch 的 fresh HEAD 完成 firmware build、clean Quartus compile、雙板 programming 與 30 秒 JTAG time-series，並有足夠證據證明：

- QSFP-A lane 0 的 PHY/link baseline 可工作。
- Endpoint identity 已分離，兩端 MAC 分別為 `02:00:22:33:44:01` 與 `02:00:22:33:44:02`。
- Master runtime 為 `MODE=2`、`PTP=6`；Slave runtime 為 `MODE=3`、`PTP=9`。
- Master/Slave 的 PPSI-level PTP RX/TX counter 有活動。
- Slave `FOREIGN_META=0x03000001`，表示已找到一筆 foreign master record，並讀到 parent WR configuration。

這些 fresh HEAD 證據足以讓 **Endpoint / MiniNIC / PTP packet path（Step 2）判定為 PASS**。但是 Slave `PSTAT.locked=0`、`status_probe bit 4 time_valid=0`，所以目前不能宣稱 White Rabbit timing synchronization 已完成。

## 六步 milestone

| Step | 目標 | 狀態 | 證據或缺口 |
|---:|---|---|---|
| 1 | QSFP/Native PHY | **PASS** | link、PHY ready、RX/TX ready 的 status probe baseline 可觀察 |
| 2 | Endpoint/MiniNIC/PTP | **PASS** | MAC identity 分離；PTP state/counters 活動；Slave `FOREIGN_META=03000001` |
| 3 | WR Parent/Signaling | **PARTIAL** | Slave 已進 `PTP=9` 且找到 foreign master，但 parent/WR signaling 尚未證明完成 |
| 4 | SoftPLL Enable | **NOT DONE** | 尚無 `PSTAT.locked=1` 證據；不能以 clock activity 代替 lock |
| 5 | DDMTD/SoftPLL/Si5340 closed loop | **NOT DONE** | 尚未證明 DDMTD（Digital Dual-Mixer Time Difference）到 SoftPLL、再到 SI5340 DCO 的閉迴路完成 |
| 6 | Global Time/execute_at(T) | **NOT DONE** | 尚未實作或驗證依共同 Global Time 在指定 `T` 啟動 accelerator |

## 2026-08-19 fresh HEAD JTAG 證據摘要

| 節點 | MODE | WDIAGS_PTP | MAC | WDIAGS_PTP_RX | WDIAGS_PTP_TX | WDIAGS_FOREIGN_META |
|---|---:|---:|---|---:|---:|---:|
| Master | 2 | 6 | `02:00:22:33:44:01` | `0xB1`（snapshot） | `0x186`（snapshot） | 未提供 |
| Slave | 3 | 9 | `02:00:22:33:44:02` | `0x174`（snapshot） | `0x7D`（snapshot） | `0x03000001` |

### 證據界線

- `WDIAGS_PTP=6` 是 PPS_MASTER，`WDIAGS_PTP=9` 是 PPS_SLAVE。
- `WDIAGS_PTP_RX/TX` 是 PPSI-level PTP counters，不是 MiniNIC frame counters。
- `WDIAGS_TX/RX` 來自 `minic_get_stats()`，只能解讀為 MiniNIC frame-level traffic。
- `FOREIGN_META=03000001` 是 foreign master / parent discovery 證據，不等於 SoftPLL lock。
- `PSTAT.locked=0` 與 `time_valid=0` 是目前尚未完成 WR timing synchronization 的直接證據。

## 來源與硬體 provenance

先前的恢復成功實驗使用 historical `c88cc05` clean SOF；本次 Step 2 milestone 則已改用 current branch fresh HEAD 的 SOF。兩者必須分開解讀。current fresh build provenance 如下：

| 節點 | SOF SHA256 | programmer checksum | MIF SHA256 |
|---|---|---|---|
| Master | `79cfac62ebfe86f338e5e79c6500956b6f3a06247c422508d5542f8b5912da1d` | `0x30A3010A` | `0d2e5a9468edc8fc7655c210c77e8122c5a980af5e66fa7f85ddfc319c2c5fb2` |
| Slave | `8b5c6652fafabf2f3a6bc0fe0b870c643a6a03dfaf0f419ff52ae32475ae4dee` | `0x30A3C3D7` | `9b0cd0b6f70e5ce752cb93cd29ec333e3b8d73635c72b0f267fad17c6149fb58` |

每次新的 runtime log 都要記錄：實際 SOF SHA256、SOF 來源 commit/branch、Master/Slave MIF SHA256、Quartus 版本、programmer checksum，以及 JTAG decode script 的 commit 或 blob SHA256。

## 本次文件整理範圍

本次只更新：

- `docs/debug/jtag_register_map.md`
- `STATUS.md`
- `docs/MERGE_READINESS.md`

本次文件更新沒有修改 functional RTL、PTP algorithm、SoftPLL algorithm、PHY 或 SI5340 DCO control；fresh HEAD 的硬體實驗與原始輸出已在 `EXP-WRPC-STEP2-DCO-RESTORE-20260819.md` 記錄。

## 下一步

1. 等待研究者 review Step 2 milestone 的 raw logs 與 acceptance table。
2. 經確認後再 merge 到 `main`；不要在未確認前刪除本研究分支。
3. Step 3 另行研究 WR parent/signaling，保留 `PSTAT.locked=0` 與 `time_valid=0` 的現況證據。
