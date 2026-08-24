# EXP-WRPC-STEP23-REGRESSION-20260825

## 實驗基本資料

- 實驗名稱：Step 2 / Step 3 read-only regression barrier
- 日期：2026-08-25
- Git branch：`exp/step4-softpll-enable`
- Git commit：`3930b918d05fbd819742f8b295884dbaac42767d`
- 功能基準：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- FPGA 燒錄：未執行
- Quartus compile：未執行
- MIF / SOF / programmer checksum：本輪不適用，沒有產生或燒錄新硬體映像

## 本次想驗證什麼

在進入 Step 4 前，先確認目前板端仍能以可靠的 read-only JTAG evidence 重現：

1. Step 2：Endpoint、MiniNIC 與 PPSI/PTP packet path。
2. Step 3：Slave foreign master、WR parent/signaling 與 `locking_enable()` evidence。
3. mailbox 無效值不會被誤判為硬體功能失敗。

## 相較前一版本唯一修改

只修改 JTAG Tcl validator：

- `read_wb_runtime.tcl`：對 `0x00100AA4` / `0x00100AA8` 的 OCER/RCER readback 要求 source-backed low-byte 格式；無效上 24 位會 retry/reject。
- `read_master_ptp_slave_parent_long.tcl`：採用相同 OCER/RCER validator。

沒有修改 RTL、firmware、MIF、PTP、WR signaling、SoftPLL、DDMTD、PI、DCO、SI5340 或 PHY。

## 執行方式與原始證據

兩個腳本都是透過 pain 上 exact commit `3930b91` 執行，且只做 Wishbone read / Direct Probe read：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wb_runtime.tcl --raw

/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

原始檔案：

- `raw/dashboard-regression-3930b91-20260825.log`
- `raw/focused-regression-3930b91-20260825.log`

檔案 SHA256：

- dashboard log：`8307924363777EB7583D7B41997889563A51245FF1EDA0F031A1DDA3CBC90BD0`
- focused log：`C550FAD4784EE58BFC92FE13FD98DAF3CE73E95E60125EC3B064496B9915A9B6`

## 結果

### Dashboard

兩張板的 raw dashboard 都回報：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
FAILURE_CLASSIFICATION = NO_FAILURE_EVIDENCE
```

Quartus STP 結果為 Tcl evaluation successful、`0 errors, 0 warnings`。

### Focused repeated sampling

20 samples、每筆間隔 500 ms：

| 板卡 | valid | invalid | counter decrease | PTP TX delta | Step 2 | Step 3 |
|---|---:|---:|---:|---:|---|---|
| Master `DE5 [1-11.1]` | 20 | 0 | 0 | 67 | PASS | N/A |
| Slave `DE5 [1-11.2]` | 20 | 0 | 0 | 7 | PASS | PASS |

Slave 每筆 accepted sample 都觀察到：

- `MAC=02:00:22:33:44:02`
- `MODE=3`
- `PTP=9`
- `FOREIGN=1/0`
- `parent=1/0/1`
- `RX=0x1001`
- `TX=0x1000`
- `LOCK_ENABLE=4`
- `RXERR=0`

Slave 的 `local_state=0` 與上述 handshake evidence 同時存在，因此腳本保留：

```text
POST_STEP3_LOCK_STAGE=TIMEOUT
STATE_EVIDENCE=READ_INCONSISTENT
```

這是 read-only state shadow 與已建立 handshake 證據的差異，不能僅由此宣稱 Step 3 hardware/firmware failure。

## Regression barrier 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

本輪只能得出「Step 2 / Step 3 regression gate 通過，允許安排下一個 Step 4 實驗」。本輪沒有進行 Step 4 functional experiment，也沒有證明 SoftPLL 已 lock 或 `time_valid=1`。

## 如何看待結果

- `A5A51330` 這類 mailbox filler 若再次出現，現在會先被 validator 判為無效並重試，不會被當成合法 `WDIAGS_PTP` 或直接變成 Step 2 FAIL。
- PTP_TX 短窗口 delta 很小或為 0 時，不能單獨推翻同時存在的 PTP_RX、MiniNIC TX/RX activity；本次 focused sampling 的 PTP_TX delta 為正。
- counter decrease 只應視為 reset、wrap、clear 或非 atomic snapshot 的待重測訊號，不可直接寫成硬體故障。
- `WRS_IDLE` shadow 與 `SLAVE_PRESENT` / `LOCK` / `LOCK_ENABLE` 的證據不一致，仍需在後續 Step 4 研究中保留，不可把它藏掉或任意改寫成已完成長期 lock。

## 下一步

可以進入下一個「單一 diagnostic variable」的 Step 4 實驗，但必須另立 commit、重新建立 provenance，且若需要硬體變更，仍要依規則執行 fresh firmware build、clean Quartus compile、program 與完整實驗紀錄。本輪沒有執行那些動作。
