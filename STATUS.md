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

## 下一個實驗

只做唯讀 JTAG time-series，不修改 PHY、PTP filter、servo 演算法或 SI5340 設定：

- 每 1 秒讀取一次，持續 60 秒。
- Master/Slave：`status_probe`、`WDIAGS_SSTAT`、`WDIAGS_PSTAT`、`WDIAGS_PTP`、`time_valid`、`pps_valid`、`WDIAGS_UCNT`、`WDIAGS_CKO`、`WDIAGS_SETP`、`WDIAGS_DMS`。
- Slave 額外觀察 `FOREIGN_META`、parent metadata 與 PTP message counters。
- 目的：區分卡在 `TRACK_PHASE` 前、SoftPLL lock 尚未成立，或 `time_valid` gating 條件未成立。

本次 `STATUS.md` 更新只是文件狀態同步，沒有 compile、燒錄或新增硬體實驗；下一次燒錄後必須立即在實驗紀錄中新增完整結果。
