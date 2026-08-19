# Merge Readiness：`exp/restore-c88cc05-baseline`

最後整理：2026-08-19

## 結論

**STEP2_RELEASE_STATUS = READY_TO_MERGE**

目前 branch 已完成 fresh HEAD firmware build、clean Quartus compile、fresh Master/Slave SOF、雙板 programming、JTAG snapshot 與 30 秒 time-series。Step 2 acceptance gates 均通過，因此此 branch 已具備 merge candidate 資格；仍須等待研究者確認後才可真正 merge 到 `main`。

本輪沒有 merge、squash、rebase 或 force push。historical `c88cc05` 只作 Golden Behavioral Baseline，不是本輪實機驗證所使用的 SOF。

## Provenance

- branch：`exp/restore-c88cc05-baseline`
- fresh build checkout HEAD：`054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`
- functional change commit：`a427ed3f61a54a704c46cf1e0f650ef591f35de1`
- remote：`origin/exp/restore-c88cc05-baseline`
- main baseline：`origin/main` / `191006c`
- historical reference：`c88cc05`
- Quartus：`17.0.0 Build 595 (04/25/2017)`
- Master MIF SHA-256：`0d2e5a9468edc8fc7655c210c77e8122c5a980af5e66fa7f85ddfc319c2c5fb2`
- Slave MIF SHA-256：`9b0cd0b6f70e5ce752cb93cd29ec333e3b8d73635c72b0f267fad17c6149fb58`
- Master SOF SHA-256：`79cfac62ebfe86f338e5e79c6500956b6f3a06247c422508d5542f8b5912da1d`
- Slave SOF SHA-256：`8b5c6652fafabf2f3a6bc0fe0b870c643a6a03dfaf0f419ff52ae32475ae4dee`
- programmer checksum：Master `0x30A3010A`；Slave `0x30A3C3D7`
- JTAG snapshot log SHA-256：`a511764fa64eae7d580d28fd77f59cd33735aefdf16f7a8cfdde6a4d465851f9`
- JTAG 30 秒 time-series log SHA-256：`8cdb432c69a740a830de32bae0733f64b4caefdff0d8ae674d92b1ed7eb85926`
- `read_wb_runtime.tcl` blob SHA-1：`dae2d85faebb479d57a1732b71d0a997147dd289`
- `read_wb_timeseries_session.tcl` blob SHA-1：`2fd15298b748be97ca0e2811fa9e7afd28dedf36`

完整燒錄輸出、compile log 與 JTAG raw log 位於 `docs/experiments/exp-restore-c88cc05-baseline/EXP-WRPC-STEP2-DCO-RESTORE-20260819.md` 所列的 pain artifact 路徑。

## Step 2 acceptance

| Gate | Fresh HEAD evidence | Result |
|---|---|---|
| Firmware / CPU | Master/Slave `reset=0`、`fault=0`、`im_valid=1`、marker=`B004`/seen=1 | PASS |
| QSFP / Native PHY | link healthy、`RXERR=0`、RX/TX ready | PASS |
| Endpoint identity | Master `02:00:22:33:44:01`；Slave `02:00:22:33:44:02` | PASS |
| MiniNIC | `WDIAGS_TX/RX` 有活動 | PASS |
| PPSI/PTP packet | Master/Slave `WDIAGS_PTP_RX/TX` 持續增加 | PASS |
| PTP role | Master `MODE=2/PTP=6`；Slave `MODE=3/PTP=9` | PASS |
| Foreign Master | Slave `FOREIGN_META=03000001`，source mapping=`foreign_count=1,best_index=0` | PASS |
| Runtime repeatability | Master 30/30、Slave 30/30 accepted samples；STP 0 errors/0 warnings | PASS |

## 結果界線與殘餘風險

- `PSTAT.locked=0`、Slave `time_valid=0`：Step 3～5 尚未完成，不能宣稱完整 White Rabbit timing synchronization。
- Quartus build provenance 仍記錄 `TIMING_CLOSED=NO`，且有未約束 clocks/ports；這是後續工程風險，不是本輪 Step 2 packet-path gate。
- 本機 Git object database 缺少 `aef63f8916c94e088f9595741025009d7d38c622`，所以某些三點 diff 統計無法在本機重建。不得用 reset、rebase 或 force push 掩蓋；應另開 repository integrity 維護工作處理。
- 時序 script 的 mailbox frame 在跨 register snapshot 邊界偶爾需要重試；有效 sample 仍通過，這不等於 PTP packet path failure。

## Merge gate

- [x] fresh HEAD firmware / MIF / SOF 已產生
- [x] Quartus 17 clean compile 完成
- [x] fresh Master/Slave SOF program 成功
- [x] programmer checksum、SOF/MIF hash 已保存
- [x] JTAG snapshot 與 30 秒 time-series 已保存
- [x] Step 2 acceptance table 全部 PASS
- [ ] 研究者 review 並確認 merge

在研究者明確確認前，只保留目前 branch，**不執行 merge 到 `main`**。確認後才可使用非 fast-forward merge，並保留 `exp/restore-c88cc05-baseline` 作為可追溯的 milestone 分支。
