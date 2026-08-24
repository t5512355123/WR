# EXP-WRPC-STEP23-REGRESSION-20260825

## 實驗識別

- 日期：2026-08-25
- 實驗名稱：Step 2 / Step 3 唯讀回歸閘門與 JTAG mailbox reliability
- Git branch：`exp/step4-softpll-enable`
- Git commit：`5fa7b7bed154a16bc8c5ef0c9fc7b60e3da1e2d7`
- 參考 functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- Quartus：17.0.0 Build 595 (2017/04/25 SJ Standard Edition)

本輪只修改 `scripts/jtag/read_step23_register_reliability.tcl` 的唯讀讀值處理：
critical enum/status 欄位必須通過 source-backed 合法性檢查，並在最多五次嘗試內取得兩次一致讀值；counter 仍以 time-series delta 判斷，decrease/reset 只標記為 retest/invalid。沒有修改 FPGA RTL、firmware、MIF、PTP、WR signaling、SoftPLL、PHY 或任何 Wishbone control 行為。

## 燒錄與建置界線

- 本輪沒有 program FPGA。
- 本輪沒有使用 SOF 進行實驗，因此沒有本輪 Master/Slave SOF checksum 可填。
- 本輪沒有執行新的 Quartus compile。前一輪殘留的 `ce2c81e` slave fit process 在本輪開始前仍停留於 `quartus_fit`；因本輪禁止 compile，已終止該殘留 process，且未使用其 SOF。
- current hardware image 的 SOF provenance 沒有在本輪重新量測；`51864b8...` 僅是使用者指定的 functional baseline reference，不能替代實際 SOF SHA256。

## 驗證目的

確認目前兩片 DE5a 的 Step 2 / Step 3 是否能以重複、有效的 JTAG mailbox sample 通過 regression gate，並區分：

1. FPGA/firmware/WR path 真的退化。
2. 單次 JTAG mailbox torn/stale read 或 dashboard snapshot 造成的 measurement failure。

## 方法與唯一變因

### 唯一變因

只將 `read_step23_register_reliability.tcl` 的 critical fields 改成「合法且連續兩次一致」才接受。PTP_TX 短窗口為零與 counter decrease 不直接作為硬體 FAIL。

### focused repeated sampling

使用既有唯讀腳本，25 samples、500 ms 間隔、mailbox poll 25 次：

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 25 500 25
```

### reliability smoke

```text
quartus_stp -t scripts/jtag/read_step23_register_reliability.tcl 10 100 step2 25
quartus_stp -t scripts/jtag/read_step23_register_reliability.tcl 10 100 step3 25
```

### dashboard smoke

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl
```

上述命令全部 read-only，沒有寫入 `WDIAGS_CTRL`、`DATA_SNAPSHOT` 或其他 control register。

## 原始證據

原始輸出保存在：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP23-REGRESSION-20260825/`

| 檔案 | SHA256 |
|---|---|
| `read_wr_handshake_focused.log` | `A76CFB2E06F3325C3D275BE2764C7BE68574E39683049DE8E55FA28B5647E300` |
| `read_step23_step2.log` | `4F4620FF6E0640AB940AE1C737BC3A15CAB60C1111E09BA2D054D75CAA608799` |
| `read_step23_step3.log` | `9DC719A2B86F3884C8B3B3BAF7B6A6D888AF74B5D25C346520A790B4BF0891D8` |
| `read_wb_runtime.log` | `3BA81934B8A2125DA328AD9BF2957E1D7D642F7F6C5E851A93356D11D5B1D350` |

所有 `quartus_stp` 執行最後均回報：`Evaluation of Tcl script ... was successful`、`0 errors, 0 warnings`。

## Step 2 結果

### focused 25-sample gate

| 板卡 | 有效 samples | MAC | MODE | PTP | PTP RX delta | PTP TX delta | MiniNIC TX delta | MiniNIC RX delta | RXERR delta | 結果 |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---|
| Master `DE5 [1-11.1]` | 25/25 | `02:00:22:33:44:01` | 2 | 6 | 28 | 75 | 97 | 46 | 0 | PASS |
| Slave `DE5 [1-11.2]` | 25/25 | `02:00:22:33:44:02` | 3 | 9 | 86 | 14 | 62 | 105 | 0 | PASS |

reliability step2 10-sample smoke 也得到兩板 `valid=10, invalid=0, decrease=0` 與 `STEP2_INDEPENDENT ... result=PASS`。Slave 的 PTP_TX 在該短窗口保持不變，但 PTP_RX、MiniNIC TX/RX 都有活動；這符合本輪「單一 counter delta=0 不可單獨 FAIL」的規則。

## Step 3 結果

Slave focused 25 samples 全部有效，且每筆都觀察到：

- `FOREIGN_META=1/0`，即 foreign master count=1、best index=0。
- `parent=1/0/1`，即 parent is WR=1、parent WR mode on=0、parent calibrated=1。
- RX WR message `0x1001`，count=1。
- TX WR message `0x1000`，count=1。
- `LOCK_ENABLE=4`。
- `STEP3_REGRESSION=PASS`。

同時 25 筆 live state 都是 `WRS_IDLE`，focused script 明確輸出 `STATE_EVIDENCE=READ_INCONSISTENT`；reliability 10-sample script 也以 `WRS_S_LOCK` failure shadow 與 `LOCK_ENABLE=4` 輸出 `POST_STEP3_LOCK_STAGE`，最後 `STEP3_INDEPENDENT ... result=PASS`。因此本輪不把單一 live state 欄位直接宣稱成 Step 3 hardware failure。

## Dashboard 交叉檢查

`read_wb_runtime.tcl` 的單次 before/after dashboard 顯示：

- 兩板 Step 1 PASS。
- 兩板 Step 2 PASS。
- Slave 單次 snapshot 的 WR TX signal 顯示 `UNKNOWN count=0`，Step 3 顯示 error。
- Slave Step 4 顯示 `OCER=TIMEOUT` 與多個 event delta=0。

這與 focused repeated evidence 的 Step 3 PASS 不一致，證明單次 dashboard snapshot 不足以作 Step 2/3 regression gate；它應保留作快速健康檢查，正式 gate 必須使用 focused/reliability repeated samples。這是 dashboard/mailbox measurement limitation 的證據，不是本輪足以宣稱 FPGA/firmware regression 的證據。

## 結論

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

以上 PASS 僅代表目前 read-only、repeated JTAG evidence 通過 Step 1/2/3 gate；沒有宣稱 Step 4 SoftPLL 已啟動，也沒有宣稱 SoftPLL lock、time_valid 或 closed-loop convergence。

本輪證據較支持：

```text
Step 2 / Step 3：沒有觀察到 hardware/firmware regression
單次 dashboard 的 Step 3 error：JTAG/dashboard measurement inconsistency
```

但因本輪沒有重新 program FPGA，也沒有取得實際 current SOF SHA256，不能把這次結果宣稱為 `51864b8...` fresh SOF provenance 的完整重現。

## 下一步

在不改變 Step 2/3 functional behavior 的前提下，保留本輪 gate 作為 Step 4 barrier：

1. 若要繼續 Step 4，先以同一組 focused Step 2/3 scripts 作 preflight。
2. Step 2/3 任一 gate 不是 PASS 就停止 Step 4。
3. Step 4 只做 read-only observability，先定位 `GOT_EDGE` 到 qualification/accept/tag/TRR 的第一個沒有活動節點。
4. 任何需要新 SOF 的 functional change，另開 commit，先保存 MIF/SOF provenance，再由使用者明確授權 program。
