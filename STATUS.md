# DE5a White Rabbit 目前狀態

最後更新：2026-08-20

目前研究分支：`exp/step4-softpll-enable`

本頁只整理目前證據與下一個研究 gate。既有燒錄實驗與 raw log 保留在 `docs/experiments/`，沒有刪除或改寫任何既有實驗紀錄。

## 目前結論

目前已經由 `exp/step4-softpll-enable` 的 fresh HEAD `edd12590eef2b77cd61aed8cb182280a1fbe9fe4` 完成 firmware build、clean Quartus compile、雙板 programming 與唯讀 JTAG observation，並有足夠證據證明：

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
| 4 | SoftPLL Enable | **BLOCKED：DCO request handshake 未完成** | Slave tag/TRR/IRQ/helper/UCNT 持續活動；但 DCO debug 長期為 `rt_state=2`、`bus_state=0`、`STEP=0`，目前第一個可觀測 blocker 是 50 MHz runtime request 與分頻 I2C controller 的 handshake |
| 5 | DDMTD/SoftPLL/Si5340 closed loop | **NOT DONE** | 尚未證明 DDMTD（Digital Dual-Mixer Time Difference）到 SoftPLL、再到 SI5340 DCO 的閉迴路完成 |
| 6 | Global Time/execute_at(T) | **NOT DONE** | 尚未實作或驗證依共同 Global Time 在指定 `T` 啟動 accelerator |

## 2026-08-20 fresh HEAD JTAG 證據摘要

| 節點 | MODE | WDIAGS_PTP | MAC | WDIAGS_PTP_RX | WDIAGS_PTP_TX | WDIAGS_FOREIGN_META |
|---|---:|---:|---|---:|---:|---:|
| Master | 2 | 6 | `02:00:22:33:44:01` | `0xA8` 起並持續增加 | `0x17D` 起並持續增加 | 不適用 |
| Slave | 3 | 9 | `02:00:22:33:44:02` | `0x17F` 起並持續增加 | `0x75` 起並持續增加 | `0x03000001` |

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
| Master | `1ac0873a3b06b5220cbfc13b6fa243be53ca4a3d7df190d26f0230e0f3df2f43` | `0x30A4A8E2` | `6989b73e3cf3d64a57cfca9f28a2d2625b0c92f90900450db2bd7f24d27c8f3e` |
| Slave | `dbd0a2ab07b7e1b0459568da43b4b323da60055a74f63641d74070e50e705fe3` | `0x30A39139` | `3657f026b9f69cf3e321e142be886eb6cd04945a1bafd36924fa24cd64b45f81` |

每次新的 runtime log 都要記錄：實際 SOF SHA256、SOF 來源 commit/branch、Master/Slave MIF SHA256、Quartus 版本、programmer checksum，以及 JTAG decode script 的 commit 或 blob SHA256。

## 2026-08-20 Step 4 fresh HEAD 唯讀稽核摘要

本輪在 `exp/step4-softpll-enable @ edd1259` 完成 clean firmware build、Quartus 17 clean compile、雙板 fresh SOF programming，並以 JTAG 做 read-only observation。這一輪沒有修改 SoftPLL 演算法、PTP、PHY、PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法。

已確認的鏈路：

```text
WRS_S_LOCK
  -> locking_enable()                         PASS
  -> spll_init(SPLL_MODE_SLAVE)               PASS
  -> RCER/tagger/ptracker/IRQ/TRR              PASS
  -> helper_update()                           PASS（有活動）
  -> helper correlation / UCNT                 PASS（輸入與 helper 有活動）
  -> DCO runtime request                       BLOCKED（rt_state=2、bus_state=0）
  -> I2C bus transaction completion             NOT OBSERVED
  -> completed DCO step                        NOT OBSERVED（STEP=0）
```

fresh runtime snapshot 顯示：Master `MODE=2/PTP=6/status=FF`；Slave `MODE=3/PTP=9/status=CF`、`FOREIGN_META=03000001`。Slave 的 `REF/TAG/IRQ/TAG_VALID/TRR_WRITE/UCNT` 持續增加，helper correlation 欄位也會變化；但 DCO correlation 反覆為 `DCO_DEBUG=FF6800000008A3A2`，即 `rt_state=2`、`bus_state=0`、`BUSY=1`、`STEP=0`、`HPLL_LOAD=0`、`ERROR=0`，DAC shadow 不變。

source audit 顯示 DCO 外層 state machine 使用 50 MHz `iCLK`，而 `i2c_bus_controller_dco` 使用 `clock_divider` 產生的較慢 clock。現行 state 1 的 `runtime_start/bus_start` 可能只存在一個 50 MHz cycle，未必被 I2C controller 看到；進入 state 2 後又等待永遠沒有出現的 `bus_state`。這支持「跨時脈 request pulse 被漏採樣」是目前優先假設，但尚不能單憑 snapshot 宣稱 I2C 實體線路故障。

完整資料見：
`docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-WDIAGS-MAP-FIX-2-20260820.md`。

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
