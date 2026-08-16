# DE5a White Rabbit 目前狀態

最後更新：2026-08-16

本文件描述 `exp/jtag-runtime-observability` 研究分支的現況。`main` 仍保留穩定 baseline，不在本次文件更新中修改。

## Git 與可追溯性

- 研究分支：`exp/jtag-runtime-observability`
- 本次文件更新前的 source 基線：`5a4def7`
- 最新文件與實驗紀錄：`docs/experiments/EXP-WRPC-JTAG-RUNTIME-20260816.md`
- GitHub：`git@github.com:t5512355123/WR.git`
- pain 工作副本：`/home/b10504072/04_WR`
- 所有新建置都必須從 GitHub fetch/checkout 明確 commit 後執行。

最近一次有效燒錄的 source 變因是 `c88cc05` 的 clean Quartus build；`d82cf9c` 與 `5a4def7` 只追加實驗紀錄及 Git 跨平台治理，沒有修改 WR 功能。

## 硬體限制與固定條件

- 兩張 DE5a，各自以獨立 JTAG 連接 pain。
- 兩張 DE5a 都以 PCIe 連接 pain。
- QSFP-A lane 0 是目前唯一的 WR timing link。
- QSFP-B/C/D 暫不參與 bring-up。
- 不新增 RS422、Common Reset 或 Common START。
- PHY、lane、polarity、line rate、reference clock 與 PTP 演算法在目前診斷階段固定不變。

## Gate 進度

| Gate | 內容 | 狀態 |
|---|---|---|
| 0 | Git、可重現建置與 artifact provenance | 已完成 |
| 1 | DE5a、Quartus 17、JTAG programming | 已完成 |
| 2 | QSFP-A lane 0 PHY/PCS link | 已完成；status low 16-bit 為 `0x82CF` 基線 |
| 3 | uRV CPU 執行 | 已完成；兩片 `fault=0`、`im_valid=1` |
| 4 | wrpc-sw boot/runtime | 已完成；兩片 marker `0xB004 seen=1` |
| 5 | PTP Master/Slave traffic | 已完成；RX/TX counters 持續增加 |
| 6 | Master/Slave unique node identity | 已完成；MAC 已分離 |
| 7 | Slave foreign/parent 與 servo activity | 已觀察到 activity，仍需更完整 parent 證據 |
| 8 | Master `time_valid=1`、`pps_valid=1` | 已觀察到 |
| 9 | Slave `pps_valid=1` | 已觀察到 |
| 10 | Slave `time_valid=1`、`TRACK_PHASE`、SoftPLL lock | 尚未完成 |
| 11 | 長時間同步穩定性 | 尚未開始 |
| 12 | TX/RX delay calibration 與外部 PPS 量測 | 尚未開始 |
| 13 | `execute_at(T)` scheduler | 尚未開始 |
| 14 | 雙 FPGA accelerator 同步啟動 | 尚未開始 |

## 最近一次燒錄後 runtime 證據

來源：`c88cc05` clean Quartus 17 build，燒錄後等待約 60 秒讀取兩片 JTAG。

### Master

- MAC：`02:00:22:33:44:01`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- status low byte：`0xFF`
- 目前 probe mapping 顯示 `time_valid=1`、`pps_valid=1`
- `WDIAGS_PTP_RX=0xB4`、`WDIAGS_PTP_TX=0x18D`

### Slave

- MAC：`02:00:22:33:44:02`
- `WDIAGS_MODE=3`
- `WDIAGS_PTP=9`
- status low byte：`0xEF`
- `pps_valid=1`，但 `time_valid=0`
- `WDIAGS_FOREIGN_META=03000001`
- `WDIAGS_DMS_L=0007594B`
- `WDIAGS_CKO=023A7EE1`
- `WDIAGS_UCNT=0000000A`
- PTP counters 持續增加，CPU 沒有 fault。

完整原始輸出保存在 pain：

```text
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/runtime_after_program_68s.log
```

這些證據支持「唯一身份已生效、PTP traffic 正常、Slave servo/parent 路徑已有活動」，但不足以宣稱兩端已完成 White Rabbit 時間同步。

## 建置與 timing 注意事項

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Master/Slave build script 在 compile 前執行 `quartus_sh --clean`，避免 stale SOF。
- 最近建置的 timing closure 仍為 `NO`；負 slack 與 unconstrained clocks 是獨立的 timing 工作，不與目前 servo bring-up 混改。
- 每個新 artifact 必須保存：Git commit、branch、Master/Slave MIF SHA256、QSF/SDC SHA256、SOF SHA256、Quartus 版本、programmer checksum、JTAG 原始輸出。

## 已完成：唯讀 JTAG 伺服器時間序列

實驗 ID：`EXP-WRPC-SERVO-TIMESERIES-20260816`。本次使用 `dba7d9b` 的觀測腳本，沿用最近一次有效燒錄 `c88cc05` 的既有 SOF；沒有重新 compile、燒錄或修改 PHY、PTP filter、servo、SI5340。

- 每 1 秒讀取一次，連續 60 個 sample。
- Quartus STP 回報 Tcl script 成功，沒有 timeout、CPU fault 或 reset。
- Master：`SSTAT=0x00000000`、`PSTAT=0x00000001`、PTP=6，status low 固定 `0x82FF`。
- Slave：`SSTAT=0x00000001`、`PSTAT=0x00000001`、PTP=9，status low 為 `0x82CF/0x82EF`；`time_valid=0` 全程未成立，`pps_valid` 不穩定。
- Slave `UCNT` 持續增加，DMS/CKO 有活動；foreign/parent mailbox 多數為有效值，但少數 sample 出現不一致或全零欄位。

### 目前判斷

依現行 register mapping，Slave 仍停在 `TRACK_PHASE` 之前，SoftPLL lock 尚未成立；證據不支持目前已進入「SoftPLL 已鎖定但 time_valid gating 阻擋」的階段。少數 mailbox 欄位不一致表示現有多 register JTAG 讀取不是原子 snapshot，parent flags 暫不能只依單列值下結論。

完整原始輸出：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SERVO-TIMESERIES-20260816/runtime_60samples.log
```

下一步只改善 JTAG mailbox 的讀取一致性，例如同一 JTAG session 的完整 frame、有效位重讀與欄位一致性檢查；在此之前不修改 PHY、PTP 演算法、servo 或 SI5340。
