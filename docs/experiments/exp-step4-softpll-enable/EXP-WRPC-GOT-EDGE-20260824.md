# EXP-WRPC-GOT-EDGE-20260824

## 1. 實驗識別

- 日期：2026-08-24（台北時間）
- Branch：`exp/step4-softpll-enable`
- Git HEAD：`65efd17da85cdff92e438f44a5d8fb1b65563af2`
- 實驗名稱：DMTD `WAIT_EDGE -> GOT_EDGE` 唯讀邊界觀測

## 2. 想驗證什麼

前一輪已觀察到 DMTD sampled counter 持續增加，以及部分 qualification-entry 活動，但尚未知道是否曾跨過 `WAIT_EDGE -> GOT_EDGE`。本輪只加入 sticky read-only evidence，驗證這個邊界是否曾發生；不驗證也不修改 SoftPLL lock 行為。

## 3. 相較 baseline 的唯一修改

唯一變因是把既有 `dmtd_with_deglitcher` 內部的 `WAIT_EDGE -> GOT_EDGE` 事件接成 sticky diagnostic，經由既有 `SPLL_DMTD_STATE` 唯讀欄位輸出：

- bit 28：reference `WAIT_EDGE -> GOT_EDGE` 曾發生
- bit 29：feedback `WAIT_EDGE -> GOT_EDGE` 曾發生

本輪沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL FSM、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。`c1abb52` 的第一次 compile 缺少 entity/package port 宣告，已在 `65efd17` 補齊後重新 clean build；這是介面宣告修正，不是硬體功能變因。

## 4. Build 與燒錄

完整 provenance 與 programmer evidence：

- `raw/EXP-WRPC-GOT-EDGE-20260824/provenance_65efd17.md`

重點：

- Quartus 17.0 Build 595。
- Master SOF SHA-256：`f3dfed9f05f95f052ae2e6d6cd5f03d16148deda98470deb510c31fb393e4e51`。
- Slave SOF SHA-256：`ad489069dac068d95f503902ff0f7010e2c525bede56eb563109b3d704ba9806`。
- Master programmer checksum：`0x30B06E5A`，configuration succeeded。
- Slave programmer checksum：`0x30B1E80D`，configuration succeeded。
- 兩片燒錄均為 0 errors、0 warnings，燒錄後等待約 60 秒。

## 5. Step 2 / Step 3 regression

測試指令：

```text
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

原始輸出：

- `raw/EXP-WRPC-GOT-EDGE-20260824/step23_got_edge_65efd17.log`

結果：

| 板卡 | accepted | invalid | counter decrease | 重要證據 | 判定 |
|---|---:|---:|---:|---|---|
| Master `DE5 [1-11.1]` | 20/20 | 0 | 0 | MAC 正確、MODE=2、PTP=6、PTP_TX delta=67 | Step 2 PASS |
| Slave `DE5 [1-11.2]` | 20/20 | 0 | 0 | MAC 正確、MODE=3、PTP=9、PTP_TX delta=14、FOREIGN=1/0、parent=1/0/1、RX=0x1001、TX=0x1000、LOCK_ENABLE=4 | Step 2/3 PASS |

Master 的 `RXERR` 在 20 個 samples 中為固定值 1，沒有增加；因此本輪不把它誤判成持續錯誤，但也不宣稱 raw RXERR 為 0。所有 mailbox samples 都有效，沒有 `INVALID` 或 Tcl exception。

## 6. Step 4 read-only observation

測試指令：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 10 500
```

原始輸出：

- `raw/EXP-WRPC-GOT-EDGE-20260824/step4_got_edge_65efd17.log`

### Master `DE5 [1-11.1]`

- `ref_got_edge_seen=1`、`fb_got_edge_seen=1`。
- `DMTD_REF_SAMPLED` / `DMTD_FB_SAMPLED` 持續增加。
- `DMTD_REF_ACCEPT` / `DMTD_FB_ACCEPT` delta=0。
- `TAG_VALID`、`TRR_WRITE`、`IRQ`、`HELPER_UPDATE` 均 delta=0。
- `RCER=0`、`SPLL_STATE=0x00020009`、`PSTAT.locked=0`。
- Tcl 邊界分類：`DMTD_QUALIFICATION_ENTRY_TO_DEGLITCH_ACCEPT`。

### Slave `DE5 [1-11.2]`

- `ref_got_edge_seen=1`、`fb_got_edge_seen=1`。
- `DMTD_REF_SAMPLED` / `DMTD_FB_SAMPLED` 持續增加。
- `DMTD_REF_ACCEPT` / `DMTD_FB_ACCEPT` delta=0。
- `TAG_VALID`、`TRR_WRITE`、`IRQ`、`HELPER_UPDATE` 均 delta=0。
- `RCER=1`、`SPLL_STATE=0x00030009`、`PSTAT.locked=0`。
- Tcl 邊界分類：`DMTD_SAMPLED_TRANSITION_TO_QUALIFICATION_ENTRY`。

本次也看到部分 threshold/CDC counter 的 decrease/reset 標記。依既定規則，這只能列為 measurement caveat，不能由單一 decrease 宣稱硬體功能失敗。

## 7. 結果與結論

- `STEP1_REGRESSION = PASS`：PHY/link/CPU 基礎路徑在本次 read-only focused evidence 中正常。
- `STEP2_REGRESSION = PASS`：兩端均取得 20/20 有效 samples；identity、role、PTP activity 符合，且沒有持續 RXERR 增加。
- `STEP3_REGRESSION = PASS`：Slave 重複取得 Foreign Master、parent flags、`SLAVE_PRESENT`、`LOCK` 與 `LOCK_ENABLE=4`。
- `STEP4_ALLOWED = YES`：Step 1～3 已用目前 fresh image 的 repeated read-only evidence 通過 regression barrier。
- `STEP4_RESULT = NOT_PASS`：本輪證明兩片 DMTD 都曾跨過 `WAIT_EDGE -> GOT_EDGE`，但尚未觀察到 `DMTD accept` 或後續 TAG/TRR/IRQ/helper 活動，因此 SoftPLL startup 尚不能標示 PASS。

這次把 blocker 從「是否曾進入 GOT_EDGE」縮小到「GOT_EDGE/qualification 後到 accept，以及 downstream event path」；這是觀測邊界定位，不是根因定論。

## 8. 下一步

先保留 `65efd17` image 與全部 raw evidence，請 reviewer 依這個新邊界指定下一個單一、read-only、source-backed observation。下一輪若需燒錄，仍須先 commit、clean build、保存 MIF/SOF/programmer checksum，並立即新增實驗紀錄。
