# EXP-WRPC-STEP23-REGRESSION-GATE-20260824

## 實驗身分

- Experiment ID：`EXP-WRPC-STEP23-REGRESSION-GATE-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- Diagnostics commit：`9811e3c5c9437a67ad6ffa4196ccc416ef042f08`
- 使用者指定的 functional baseline：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- 目的：先重新建立可靠的 Step 1、Step 2、Step 3 read-only regression barrier，區分 WR 功能失敗與 JTAG/mailbox 量測失效，再決定是否允許繼續 Step 4。

## 本輪唯一修改

本輪只修改 JTAG Tcl 與 diagnostics 文件：

1. 拒絕已觀察到的 `0xA5A5xxxx` stale/filler mailbox 值。
2. Critical enum/status register 最多重讀 5 次，並要求兩次合法一致值；失敗時回報 `INVALID`，不轉成 hardware FAIL。
3. Dashboard counter 視窗由 750 ms 延長為 5 s；單一 `PTP_TX delta=0` 不使 Step 2 FAIL。
4. Step 2 focused gate 要求 PTP RX、MiniNIC TX/RX 持續活動，RXERR 不持續增加；counter decrease 只列為 retest。
5. Step 3 focused gate要求 foreign master、parent flags、LOCK、SLAVE_PRESENT 與 `LOCK_ENABLE>0`。若 live WR state 與既有 handshake 證據衝突，列為 `READ_INCONSISTENT`，不直接宣告 Step 3 FAIL。
6. 依 `softpll_export.h` 修正 `SPLL_STATE` sequencer 解碼；正式 enum 為 1..10，0 僅代表 C global 尚未初始化的診斷狀態。

沒有修改 Master/Slave role switching、PTP、WR signaling、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY RTL 或 WRPC firmware functional behavior。

## Hardware / SOF Provenance

本輪依要求沒有 Quartus compile、沒有 program FPGA。板上 image 沿用緊接在本輪之前的 D1 read-only observability 實驗；該實驗的 source commit 是 `c9f1f15005fa41b581736ec56c27e207178731ac`，其 White Rabbit functional behavior 沿用 `51864b8` baseline。以下 hash 來自既有 `EXP-WRPC-STEP4-D1-PIPELINE-MISMATCH-20260824` 燒錄紀錄，不是本輪重新燒錄取得：

| 項目 | Master | Slave |
|---|---|---|
| MIF SHA256 | `13f1dca14561ac118ab84a77c2f48bf433893911daf21e75b9e8b70dc7bdf260` | `172774ca0953de1485bfb41cc9d605651d6f300de37394b75320ded8850be3c7` |
| SOF SHA256 | `7a1ca58d525394a7a996247f27d8d851e307e8a3569054f13672ec4241860cef` | `29756c128e61acfbbaf2736a8a65d6058d771298167c20a58979ee60ff4a89f2` |
| Programmer checksum | `0x30AA777D` | `0x30ADDA10` |

本輪 diagnostics script SHA256：

| Script | SHA256 |
|---|---|
| `read_wb_runtime.tcl` | `ee101d5992c37a1cd2d5b17a52ba1f8b8f2f51b694725117fdfe3d969bc063e7` |
| `read_wr_handshake_focused.tcl` | `e9a531ff776d991992b5875cb8a94182d8daed35fb68b020631dc538a1b5605b` |
| `read_step23_register_reliability.tcl` | `6415ed2ce5b2b97ca54f4a1d5914833966dbe2405e00d8428e402b1e5e650a1e` |

## 執行方式

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 1000
quartus_stp -t scripts/jtag/read_step23_register_reliability.tcl 20 250 all
```

三個命令都只執行 JTAG probe 與 Wishbone read，沒有寫入 control register。Quartus SignalTap II 版本為 `17.0.0 Build 595`，三次 Tcl evaluation 均成功，0 errors、0 warnings。

## Runtime 結果

### Dashboard

| Gate | Master | Slave |
|---|---|---|
| Step 1 PHY / Link | PASS | PASS |
| Step 2 Endpoint / PTP | PASS | PASS |
| Step 3 WR Handshake | N/A | PASS |

Master：MAC `02:00:22:33:44:01`、MODE 2、PTP 6；5 s 內 PTP RX/TX delta `17/33`、MiniNIC TX/RX delta `41/23`、RXERR delta 0。

Slave：MAC `02:00:22:33:44:02`、MODE 3、PTP 9；5 s 內 PTP RX/TX delta `22/4`、MiniNIC TX/RX delta `16/27`、RXERR delta 0；foreign `1/0`、parent `1/0/1`、RX `LOCK 0x1001`、TX `SLAVE_PRESENT 0x1000`、`LOCK_ENABLE=4`。

### Focused 30 x 1 s

```text
Master: valid=30 invalid=0 decrease=0 PTP_TX_DELTA=172 STEP2=PASS
Slave : valid=30 invalid=0 decrease=0 PTP_TX_DELTA=24  STEP2=PASS STEP3=PASS
Slave : signal_good=30 signal_bad=0 state_idle=30
        POST_STEP3_LOCK_STAGE=TIMEOUT STATE_EVIDENCE=READ_INCONSISTENT
```

Slave 30 筆均有 foreign `1/0`、parent `1/0/1`、RX `0x1001`、TX `0x1000`、`LOCK_ENABLE=4`。Live state 30 筆皆為 `WRS_IDLE`，但 failure shadow 30 筆皆保留 `last_fail_state=WRS_S_LOCK`，因此這是 post-Step-3 timeout / state evidence conflict，不推翻已成立的 Step 3 handshake gate。

### Independent register reliability 20 samples

- Master：`STEP2_INDEPENDENT=PASS`，Step 3 N/A。
- Slave：`STEP2_INDEPENDENT=PASS`、`STEP3_INDEPENDENT=PASS`。
- 所有 Step 2/3 關鍵 register 均 20/20 valid、0 invalid、0 decrease。
- Slave `FOREIGN_META=0x03000001`、`WR_RX_SIGNAL=0x10010001`、`WR_TX_SIGNAL=0x10000001`、`LOCK_ENABLE=4`，各 20/20 穩定。
- Slave `WDIAGS_TEMP` 20/20 為 `WRS_IDLE`，同時 `WR_FAILURE_DEBUG=0x02020001` 20/20 證明先前已到 `WRS_S_LOCK` 後 timeout；腳本輸出 `POST_STEP3_LOCK_STAGE=TIMEOUT`。

## Acceptance Table

| Gate | 必要證據 | 結果 |
|---|---|---|
| Step 1 | 兩板 PHY/link/ready/encoding gate 正常 | PASS |
| Step 2 Master | MAC ...01、MODE 2、PTP 6、packet activity、RXERR 不增加 | PASS |
| Step 2 Slave | MAC ...02、MODE 3、PTP 9、packet activity、RXERR 不增加、foreign 1/0 | PASS |
| Step 3 Slave | parentIsWRnode=1、parentCalibrated=1、LOCK、SLAVE_PRESENT、LOCK_ENABLE>0 | PASS |
| JTAG reliability | repeated accepted samples，沒有 A5A5/invalid/decrease 混入判定 | PASS |

## Observation

新的 dashboard 沒有再把非法 PTP 值解讀成 PTP state，也沒有 Tcl exception。三種唯讀量測方法對 Step 1～3 給出一致結果。Slave live `WRS_IDLE` 與歷史 `WRS_S_LOCK` failure shadow 的衝突仍存在，但目前證據支持「Step 3 已到達，之後在 post-Step-3 lock stage timeout」，不支持「Step 3 從未成功」。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
FAILURE_CLASSIFICATION = NO_FAILURE_EVIDENCE_FOR_STEP1_TO_STEP3
```

本輪沒有觀察到 Step 1～3 的 hardware/firmware regression，也沒有把 invalid mailbox sample 當成 hardware failure。`STEP4_ALLOWED=YES` 只表示 regression barrier 已通過，不表示 Step 4 已完成或 SoftPLL 已 lock。

## Next Step

可以在後續獨立 commit 中繼續 Step 4 的單一變因、read-only observability 實驗；本輪沒有執行任何 Step 4 functional 修改、compile 或 program。

## Raw Evidence

- `raw/EXP-WRPC-STEP23-REGRESSION-GATE-20260824/dashboard.log`
- `raw/EXP-WRPC-STEP23-REGRESSION-GATE-20260824/focused_30x1s.log`
- `raw/EXP-WRPC-STEP23-REGRESSION-GATE-20260824/register_reliability_20x250ms.log`
- `raw/EXP-WRPC-STEP23-REGRESSION-GATE-20260824/provenance.txt`
