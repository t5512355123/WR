# DE5a White Rabbit 目前狀態

最後更新：2026-08-19

目前研究分支：`exp/restore-c88cc05-baseline`

本頁只整理目前證據與下一個研究 gate。既有燒錄實驗與 raw log 保留在 `docs/experiments/`，沒有刪除或改寫任何既有實驗紀錄。

## 目前結論

目前已經有足夠 JTAG 證據證明：

- QSFP-A lane 0 的 PHY/link baseline 可工作。
- Endpoint identity 已分離，兩端 MAC 分別為 `02:00:22:33:44:01` 與 `02:00:22:33:44:02`。
- Master runtime 為 `MODE=2`、`PTP=6`；Slave runtime 為 `MODE=3`、`PTP=9`。
- Master/Slave 的 PPSI-level PTP RX/TX counter 有活動。
- Slave `FOREIGN_META=0x03000001`，表示已找到一筆 foreign master record，並讀到 parent WR configuration。

這些證據足以讓 **Endpoint / MiniNIC / PTP packet path（Step 2）判定為 PASS**。但是 Slave `PSTAT.locked=0`、`status_probe bit 4 time_valid=0`，所以目前不能宣稱 White Rabbit timing synchronization 已完成。

## 六步 milestone

| Step | 目標 | 狀態 | 證據或缺口 |
|---:|---|---|---|
| 1 | QSFP/Native PHY | **PASS** | link、PHY ready、RX/TX ready 的 status probe baseline 可觀察 |
| 2 | Endpoint/MiniNIC/PTP | **PASS** | MAC identity 分離；PTP state/counters 活動；Slave `FOREIGN_META=03000001` |
| 3 | WR Parent/Signaling | **PARTIAL** | Slave 已進 `PTP=9` 且找到 foreign master，但 parent/WR signaling 尚未證明完成 |
| 4 | SoftPLL Enable | **NOT DONE** | 尚無 `PSTAT.locked=1` 證據；不能以 clock activity 代替 lock |
| 5 | DDMTD/SoftPLL/Si5340 closed loop | **NOT DONE** | 尚未證明 DDMTD（Digital Dual-Mixer Time Difference）到 SoftPLL、再到 SI5340 DCO 的閉迴路完成 |
| 6 | Global Time/execute_at(T) | **NOT DONE** | 尚未實作或驗證依共同 Global Time 在指定 `T` 啟動 accelerator |

## 2026-08-19 JTAG 證據摘要

| 節點 | MODE | WDIAGS_PTP | MAC | WDIAGS_PTP_RX | WDIAGS_PTP_TX | WDIAGS_FOREIGN_META |
|---|---:|---:|---|---:|---:|---:|
| Master | 2 | 6 | `02:00:22:33:44:01` | `0x11042` | `0x267C0` | 未提供 |
| Slave | 3 | 9 | `02:00:22:33:44:02` | `0x267BF` | `0x062C2` | `0x03000001` |

### 證據界線

- `WDIAGS_PTP=6` 是 PPS_MASTER，`WDIAGS_PTP=9` 是 PPS_SLAVE。
- `WDIAGS_PTP_RX/TX` 是 PPSI-level PTP counters，不是 MiniNIC frame counters。
- `WDIAGS_TX/RX` 來自 `minic_get_stats()`，只能解讀為 MiniNIC frame-level traffic。
- `FOREIGN_META=03000001` 是 foreign master / parent discovery 證據，不等於 SoftPLL lock。
- `PSTAT.locked=0` 與 `time_valid=0` 是目前尚未完成 WR timing synchronization 的直接證據。

## 來源與硬體 provenance

目前恢復成功的硬體實驗使用 historical `c88cc05` clean SOF，而不是目前 branch HEAD 的 fresh build。保存的 artifact hash：

| 節點 | SOF SHA256 | programmer checksum | MIF SHA256 |
|---|---|---|---|
| Master | `f565c0a209cf1567f048df25b0f3312e9db4bf45a3fc46914a87efefbf2b1abf` | `0x30A0A429` | `0705b4be17ed742fbd32860de8a8cbbebf91285c71e0e54465516a59e1b2dc7a` |
| Slave | `926d4a57f50dce0e39e437af7eba164a8ca1ec327c989b59d5f6480a038eb2cb` | `0x30A5A091` | `dbc19106386ebca90f3460309a8b41f09e5bde0694b91484e527ed4a56ef9d35` |

每次新的 runtime log 都要記錄：實際 SOF SHA256、SOF 來源 commit/branch、Master/Slave MIF SHA256、Quartus 版本、programmer checksum，以及 JTAG decode script 的 commit 或 blob SHA256。

## 本次文件整理範圍

本次只更新：

- `docs/debug/jtag_register_map.md`
- `STATUS.md`
- `docs/MERGE_READINESS.md`

本次沒有 compile、program、燒錄 FPGA，也沒有修改 functional RTL、PTP algorithm、SoftPLL algorithm、PHY 或 SI5340 DCO control。因此本次不是新的硬體實驗，不會宣稱任何新的硬體成功。

## 下一步

1. 先完成 current HEAD 的 fresh build，保存 Master/Slave MIF 與 SOF hash。
2. 以 fresh HEAD SOF 重新燒錄兩片 DE5a，再執行 read-only JTAG runtime script。
3. 比較 fresh HEAD 與 historical c88cc05 的 `MODE`、`PTP`、PTP counters、foreign/parent metadata、`PSTAT.locked` 與 `time_valid`。
4. 在 fresh HEAD runtime reproduction 完成前，維持 merge readiness 為 `NOT READY TO MERGE`。
