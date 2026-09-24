# EXP-WRPC-STEP4-REPROGRAM-CONTROL-20260822

## 實驗基本資料

- 實驗名稱：fresh SOF 重新燒錄後的 Step 2/3 控制與 Step 4 邊界觀測
- 日期：2026-08-22
- Git branch：`exp/step4-softpll-enable`
- RTL / firmware source commit：`5074e0e44cc2ef16c993489ab092e28dbb0b0a99`
- 實驗紀錄提交前文件狀態 commit：`72d3aed`
- 實驗目的：確認同一份 fresh HEAD SOF 重新 program 後，Step 3 handshake 是否能重現，以及在 `RCER/OCER` enable 後 DMTD 到 SoftPLL downstream 的第一個無活動邊界。
- 唯一操作變因：重新燒錄同一份已由 exact HEAD fresh compile 產生的 Master/Slave SOF；沒有修改 RTL、firmware、MIF、SoftPLL、WR signaling 或 runtime control register。

## 明確未修改項目

本次沒有修改 Master/Slave role switching、PTP 演算法、WR signaling 演算法、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional RTL。JTAG 讀取與本紀錄均為 read-only；沒有寫入 Wishbone control register，也沒有重新編譯。

## SOF 與燒錄 provenance

這兩份 SOF 都來自 exact source commit `5074e0e44cc2ef16c993489ab092e28dbb0b0a99` 的 fresh firmware build 與 Quartus clean compile。

| 項目 | Master | Slave |
|---|---|---|
| Cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |
| SOF SHA256 | `c7d7f861eb19cf66e4d14201c68a945c66861856ae962dad06b7bc257e244f34` | `187d2521cbc215b41b6ec2584e2a3822e86a3260c7ab6cd4a2f20f471194c15f` |
| Programmer checksum | `0x309EF758` | `0x30A56A72` |
| Programmer result | Configuration succeeded; 0 errors; 0 warnings | Configuration succeeded; 0 errors; 0 warnings |
| Raw log | `raw/program_control2_5074e0e_20260822.log` | 同一份 log |

Quartus 版本：`17.0.0 Build 595 04/25/2017 SJ Standard Edition`。

## 測試方法

1. 以同一份 fresh SOF 重新 program Master 與 Slave。
2. 等待 runtime 啟動後，以 read-only focused script 取 20 個樣本：
   `scripts/jtag/read_wr_handshake_focused.tcl 20 500`
3. 再以 Step 4 focused script 取 8 個樣本：
   `scripts/jtag/read_step4_startup_focused.tcl 8 250 events --raw`
4. 兩個 Tcl 測試均以 exit code 0 結束，Quartus SignalTap II 顯示 0 errors、0 warnings。

原始證據：

- `raw/regression_handshake_reprogram_5074e0e_20260822.log`
- `raw/regression_step4_reprogram_5074e0e_20260822.log`
- `raw/program_control2_5074e0e_20260822.log`

## Step 2 結果

### Master

- MAC `02:00:22:33:44:01`
- MODE `2`
- PTP `6`
- PTP/MiniNIC counters 在樣本期間增加

### Slave

- MAC `02:00:22:33:44:02`
- MODE `3`
- PTP 由 startup 的 `8` 進入 `9`
- Foreign master `1/0`
- parent fields 在前 15 個樣本為 `1/0/1`
- MiniNIC/PTP counters 增加
- RXERR `0`

Step 2 的封包路徑證據成立：

`STEP2_REGRESSION=PASS`

## Step 3 結果

Slave 的 20 個有效樣本中：

- 前 15 個樣本觀察到 `RX=0x1001`（LOCK）
- `TX=0x1000`（SLAVE_PRESENT）持續出現
- `LOCK_ENABLE=4`
- `RCER=1`
- `signal_good=16`
- `state_good=15`
- `state_idle=5`
- `signal_bad=4`
- `STATE_EVIDENCE=READ_INCONSISTENT`
- focused gate：`STEP3_REGRESSION=PASS`
- `POST_STEP3_LOCK_STAGE=TIMEOUT`

這表示同一次啟動中曾經取得 Step 3 的正向 handshake 證據，但後續樣本回到 idle/recovery 狀態。依 source audit，`wr_handshake_fail()` 會保存失敗狀態、將 next state 設為 `WRS_IDLE` 並重設 WR extension；因此不能把後段 `WRS_IDLE` 單獨解讀成「從未完成 handshake」。本次結論為：

`STEP3_REGRESSION=PASS_WITH_POST_STAGE_TIMEOUT`

此名稱描述本次控制實驗，不代表 Step 3 已達到長時間穩定 milestone。

## Step 4 結果

### Slave 觀測

- `SPLL_MODE_SEQUENCE=0x00030009`
- `RCER=1`
- `OCER=1`
- `SPLL_DMTD_STATE=0x00000008`，8 個樣本穩定
- 完整 `DMTD_REF_EVENTS` delta `0`
- 完整 `DMTD_FB_EVENTS` delta `0`
- `TAG_PENDING` delta `0`
- `TAG_GRANT` delta `0`
- `TAG_VALID` delta `0`
- `TRR_WRITE` delta `0`
- `IRQ` delta `0`
- `STATE_TRANSITION` delta `0`
- `HELPER_UPDATE` delta `0`

### Master 觀測

- `SPLL_MODE_SEQUENCE=0x00020009`
- `RCER=0`
- `OCER=1`
- DMTD event 與所有 downstream event 在本窗口也沒有增加

### 判讀

本次可確認 Slave 已經進入 SoftPLL channel enabled 的觀測狀態，但尚未取得「DMTD event 持續增加並流入 tag/TRR/helper」的 Step 4 PASS 證據。現階段最早可疑邊界位於 DMTD deglitch qualification / event-to-system-visible boundary；不能僅依 `SPLL_DMTD_STATE=8` 宣稱根因，也不能修改 SoftPLL 演算法來追 lock。

`DMTD_REF_SEEN` / `DMTD_FB_SEEN` 中新增 diagnostic counter 只保存低 15 bits；它們在長觀測窗口會自然 wrap，且跨 clock domain 多位元讀取不是 atomic snapshot。因此 raw log 中的 `DECREASED_OR_RESET` 只能視為 measurement limitation，不能當成硬體 failure。

本次結論：

`STEP4_REGRESSION=NOT_PASS`

## Regression barrier

| Gate | 本次結果 | 說明 |
|---|---|---|
| Step 1 PHY / Link | PASS | fresh SOF 的 status、CPU、PHY/link evidence 正常 |
| Step 2 Endpoint / MiniNIC / PTP | PASS | unique MAC、role/PTP、counter activity、foreign master |
| Step 3 WR Handshake | PASS_WITH_POST_STAGE_TIMEOUT | 16/20 signal-good，LOCK/SLAVE_PRESENT/LOCK_ENABLE=4，但後段回復 idle |
| Step 4 SoftPLL Startup | NOT_PASS | RCER/OCER 已 enable，但 DMTD/downstream event 未持續增加 |

因此目前仍不能宣稱 Step 4 完成，也不開始任何 SoftPLL algorithm functional modification。

## Conclusion

這次實驗把問題從「是否成功 program」與「Step 2 packet path」分離出來：fresh SOF 確實可 program，Step 2 成立；Step 3 在啟動期間曾取得完整正向 handshake，但未維持到後續穩定階段；Step 4 的 `RCER/OCER` enable 已觀察到，然而 DMTD event 到 tag/TRR/helper 的 downstream chain 沒有活動。

目前證據同時包含：

1. 硬體/firmware runtime 在部分啟動階段有正向 WR signaling evidence。
2. 後續穩定 SoftPLL activity 尚未觀察到。
3. packed diagnostic counters 有 wrap/非 atomic read 限制，不能把讀值下降當成硬體錯誤。

所以不能把根因定義成 SoftPLL 演算法錯誤，也不能把 dashboard 的單一 state sample 當作唯一結論。

## Next Step

先請 White Rabbit 技術專家 review 這次「Step 3 短暫通過、Step 4 RCER/OCER 已開但 DMTD downstream 無活動」的 raw evidence。下一個實驗仍只允許一個 read-only observability 變因：補足 DMTD deglitch 的 current/stability qualification 觀測，區分 `WAIT_STABLE`、`GOT_EDGE` 與 post-CDC event 是否真的沒有產生；不要修改 WR signaling、SoftPLL、PI、DCO、SI5340 或任何 functional algorithm。
