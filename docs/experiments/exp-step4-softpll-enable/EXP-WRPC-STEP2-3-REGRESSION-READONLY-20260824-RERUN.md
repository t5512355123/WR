# EXP-WRPC-STEP2-3-REGRESSION-READONLY-20260824-RERUN

## 實驗身分

- Experiment ID：`EXP-WRPC-STEP2-3-REGRESSION-READONLY-20260824-RERUN`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- Git HEAD：`8f2bdad95d587f426afdad1901f3f7b2ed611a71`
- Functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- 目的：在不改變 FPGA/firmware 功能的前提下，重新確認 Step 1、Step 2、Step 3 regression barrier，並區分硬體/firmware 問題與 JTAG 量測不一致。

## 本輪限制與實際操作

本輪只執行 read-only JTAG diagnostics：

- 沒有修改 RTL、firmware、MIF、PTP、WR signaling、SoftPLL、DDMTD、PI、lock threshold、DCO、SI5340 或 PHY 行為。
- 沒有 Quartus compile。
- 沒有 program FPGA。
- 沒有 reboot。
- 沒有寫入 Wishbone control register。
- 沒有 merge `main`。

本輪 branch 在 local 與 GitHub 均為 `8f2bdad95d...`；先前嘗試加入 firmware 診斷計數器的變更已由 `8f2bdad` 完整撤回，本次工作樹沒有 functional source modification。

## 硬體與工具 provenance

本輪沒有重新燒錄，因此以下是「沿用既有燒錄紀錄」而不是本輪 fresh SOF 證據：

| 項目 | Master | Slave |
|---|---|---|
| MIF SHA256 | `13f1dca14561ac118ab84a77c2f48bf433893911daf21e75b9e8b70dc7bdf260` | `172774ca0953de1485bfb41cc9d605651d6f300de37394b75320ded8850be3c7` |
| SOF SHA256 | `7a1ca58d525394a7a996247f27d8d851e307e8a3569054f13672ec4241860cef` | `29756c128e61acfbbaf2736a8a65d6058d771298167c20a58979ee60ff4a89f2` |
| Programmer checksum | `0x30AA777D` | `0x30ADDA10` |
| 既有燒錄來源 commit | `c9f1f15005fa41b581736ec56c27e207178731ac` | `c9f1f15005fa41b581736ec56c27e207178731ac` |

工具版本：Quartus Prime/SignalTap `17.0.0 Build 595`。

## 執行命令

### Focused Step 2/3 repeated sampling

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

### 完整 read-only dashboard

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl
```

兩個 Tcl 執行都完成，Quartus SignalTap 均回報 `0 errors, 0 warnings`，沒有 Tcl exception。

## Raw evidence

| 檔案 | SHA256 |
|---|---|
| [`step2_3_focused_20x500.log`](raw/EXP-WRPC-STEP2-3-REGRESSION-20260824/step2_3_focused_20x500.log) | `016B53B2659B7BA2804E2EFEE53D751C54A4F07CED1E73936A628FE6E96909B` |
| [`step2_3_dashboard.log`](raw/EXP-WRPC-STEP2-3-REGRESSION-20260824/step2_3_dashboard.log) | `B67C0B009869C01BA0B7C1046AEEF0D0E56E1D29524A7DCFAAA6CFB280B61E9A` |

本次 Tcl source hash：

| Script | SHA256 |
|---|---|
| `scripts/jtag/read_wb_runtime.tcl` | `5A7BE165404F22591CC0560C457CC68C019D0581C98628AA36785459F47FC2F6` |
| `scripts/jtag/read_wr_handshake_focused.tcl` | `7AABEC5AA181D576D0C10E149D0CF64A157BA4D8F383716FC82560500CC581B5` |

## Focused repeated sampling 結果

### Master：DE5 [1-11.1]

```text
valid_samples=20
invalid_samples=0
counter_decreased=0
PTP_TX_DELTA=69
STEP2_REGRESSION=PASS
STEP3_REGRESSION=NA
```

代表性證據：MAC `02:00:22:33:44:01`、MODE `2`、PTP `6`；PTP/MiniNIC counters 有活動，RXERR 沒有增加。

### Slave：DE5 [1-11.2]

```text
valid_samples=20
invalid_samples=0
counter_decreased=0
PTP_TX_DELTA=11
STEP2_REGRESSION=PASS
STEP3_REGRESSION=PASS
POST_STEP3_LOCK_STAGE=TIMEOUT
STATE_EVIDENCE=READ_INCONSISTENT
signal_good=20
signal_bad=0
state_idle=20
state_good=0
```

20 筆有效 sample 均支持：

- MAC `02:00:22:33:44:02`
- MODE `3`
- PTP `9`
- PTP RX/TX 與 MiniNIC TX/RX 有活動
- RXERR delta `0`
- Foreign Master `1`、best index `0`
- `parentIsWRnode=1`、`parentCalibrated=1`
- RX `0x1001` LOCK，TX `0x1000` SLAVE_PRESENT
- `LOCK_ENABLE=4`

同時 20 筆 live state 都是 `WRS_IDLE`，與 LOCK/SLAVE_PRESENT/LOCK_ENABLE 及 failure shadow 中的 `last_fail_state=WRS_S_LOCK` 不一致。因此標示為 `STATE_EVIDENCE=READ_INCONSISTENT`，不是 Step 3 FAIL。`POST_STEP3_LOCK_STAGE=TIMEOUT` 屬於 Step 3 之後的觀察，不推翻已成立的 Step 3 handshake evidence。

## Dashboard 結果

Master dashboard：

- Step 1 PHY/Link：`pass`
- Step 2 Endpoint/PTP：`pass`
- Step 3：`NA`（Master 不使用 Slave parent gate）

Slave dashboard：

- Step 1 PHY/Link：`pass`
- Step 2 Endpoint/PTP：`pass`
- Step 3 WR Parent/Signaling：`pass`
- Step 4 SoftPLL Startup：`error`

Dashboard 顯示的 Step 4 error 不納入本輪 Step 2/3 regression barrier；本輪沒有進行 Step 4 functional experiment。`OCER=TIMEOUT`、部分 Step 4 event delta 為 0 等值只能作為後續 Step 4 read-only investigation 的線索，不能回頭改判 Step 2 或 Step 3。

## 量測品質與判定原則

- 本次 focused sampling 沒有出現 `0xA5A5xxxx`、非法 enum、`TIMEOUT` 混入有效 Step 2/3 gate 的情況。
- `invalid_samples=0`、`counter_decreased=0`，因此本次沒有看到 mailbox stale read 或 counter reset/decrease 造成的 regression evidence。
- 單一 counter delta=0 不會單獨造成 Step 2 FAIL；本次 PTP/MiniNIC activity 與 RXERR evidence 均成立。
- `WRS_IDLE` 與其他 handshake evidence 的衝突屬於 JTAG snapshot/state evidence 不一致，需在後續 read-only 觀測中釐清，不可直接當成硬體功能失敗。

## 最終 regression gate

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
```

故障分類：

```text
HARDWARE/FIRMWARE_FAILURE = NOT_PROVEN for Step 1/2/3
JTAG/DASHBOARD_MEASUREMENT_FAILURE = NOT OBSERVED as invalid mailbox in this run
JTAG/DASHBOARD_MEASUREMENT_INCONSISTENCY = PRESENT for Slave live WRS state
```

這個結果只表示 Step 2、Step 3 的唯讀 regression barrier 目前通過；不表示 Step 4 SoftPLL 已 enable、已 lock 或已完成時間同步。

## Next Step

下一步才可以在同一 branch 進行 Step 4 的 read-only source/runtime audit，且仍須維持單一變因與完整紀錄。若未來需要 functional modification，必須另開獨立 commit，先說明變因，再依要求完成 clean build、program 與實驗紀錄；本輪不做這些操作。

pain 工作樹中原本存在的無關未追蹤項目 `-eq`、`0`、`;`、`\\`、`test` 本輪未刪除、未修改，也未納入本次實驗證據。
