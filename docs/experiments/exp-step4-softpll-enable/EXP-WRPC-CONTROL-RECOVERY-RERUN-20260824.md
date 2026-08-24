# EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824

## 實驗基本資料

- 實驗名稱：Fresh control image 回復、Step 2/3 regression barrier 與 Step 4 只讀觀測
- 日期：2026-08-24
- Git branch：`exp/step4-control-recovery-fresh`
- Git commit：`7dd298bb143d35b73d16dc9007c26d88c7da5622`
- 硬體 functional baseline：控制版本；本次沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL、PHY 或 firmware functional behavior
- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- 觀測原則：只使用 JTAG read-only diagnostics；沒有寫入 Wishbone control register

## 這次想驗證什麼

在進入 Step 4 功能研究前，先從目前 branch 的 exact HEAD 重新產生 firmware、執行 Quartus clean compile、燒錄兩片 DE5a，確認目前硬體是否能重新通過 Step 2 與 Step 3。若 regression barrier 通過，再以既有只讀腳本觀察 SoftPLL 是否已啟動。

這次特別用來區分：

1. 先前的問題是否只是 stale/historical SOF 或 runtime startup transition。
2. Step 2/3 是否能在 fresh/current hardware 上重現。
3. Step 4 的 DMTD、tag、TRR、IRQ、helper 路徑目前哪一段有可觀測活動。

## 相較 baseline 唯一修改

本次沒有加入新的 functional 修改。唯一操作變因是：以 branch `exp/step4-control-recovery-fresh` 的 exact HEAD 重新建置並燒錄 fresh firmware/SOF，取代板上原本的 bitstream。

## Fresh build provenance

Firmware build 與 Master/Slave Quartus clean compile 均成功。完整 build metadata 保存於：

- `raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/build_info_jtag_master.txt`
- `raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/build_info_jtag_slave.txt`
- `raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/master_build_hashes.sha256`
- `raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/slave_build_hashes.sha256`

### Master

- QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`a96c40101a7617d99c50eefe8104e5c0bc6d1e1745145ff0e09583a199cb1eac`
- SOF SHA256：`68fdf9d75243065909891a5c4518a82ccab8dd153694446a7abffa649829dfd7`
- Timing：Fitter successful；`TIMING_CLOSED=NO`，worst setup slack `-0.399 ns`

### Slave

- QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`e5f0f1265f114bdd3d2339d50367510a3b0b102b17c217af6d43a32fc3ffba25`
- SOF SHA256：`b9d6f424b028b4925284d215bd312da097af02166ed3f2ec83f5bf45fa3115ab`
- Timing：Fitter successful；`TIMING_CLOSED=NO`，worst setup slack `-0.182 ns`

## 燒錄結果

### Master

- Programmer cable：`DE5 [1-11.1]`
- SOF checksum：`0x30AA3EE5`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`

### Slave

- Programmer cable：`DE5 [1-11.2]`
- SOF checksum：`0x30B06A0E`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`0 errors, 0 warnings`

原始 programmer 輸出：

- `raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/program_master.log`
- `raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/program_slave.log`

## Step 2/3 regression 結果

使用既有 focused read-only script：

```text
quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

### 第一次燒錄後約 30 秒

原始輸出保存於 `raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/focused_step23.log`。

- Master：20/20 valid，`MODE=2`、`PTP=6`，PTP TX 有增加，Step 2 PASS。
- Slave：20/20 valid，`MODE=3`、`FOREIGN=1/0`、parent flags=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`，Step 3 PASS。
- 但 Slave 暫時為 `PTP=8`（UNCALIBRATED），所以第一次觀測的 Step 2 判定為 FAIL。
- 這不是 JTAG timeout；`valid_samples=20`、`invalid_samples=0`、`counter_decreased=0`。

### 等待後重測

等待 60 秒後，以相同 focused script 重測，原始輸出保存於 `raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/focused_step23_after60s.log`。

- Master：`MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`，`PTP_TX_DELTA=67`，Step 2 PASS。
- Slave：`MAC=02:00:22:33:44:02`、`MODE=3`、穩態 `PTP=9`，`PTP_TX_DELTA=9`，Step 2 PASS。
- Slave：`FOREIGN=1/0`、parent flags=`1/0/1`、RX=`0x1001`、TX=`0x1000`、`LOCK_ENABLE=4`，Step 3 PASS。
- Slave：20/20 valid，`invalid_samples=0`、`counter_decreased=0`。
- `STATE_EVIDENCE=READ_INCONSISTENT`：handshake evidence 穩定，但 current-state 欄位全部為 idle；因此保留為讀值不一致，不把它單獨宣稱為硬體失敗。

### Regression barrier

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
```

## Step 4 read-only 觀測

使用：

```text
quartus_stp -t /home/b10504072/04_WR/scripts/jtag/read_step4_startup_focused.tcl 20 500 all
```

完整 raw output 保存於：

`raw/EXP-WRPC-CONTROL-RECOVERY-RERUN-20260824/step4_focused_all.log`

### Slave 觀測到的活動

- `WR_LOCK_ENABLE_COUNT`：`4`
- `RCER`：`0x00000001`
- `SPLL_STATE`：`0x00030009`
- DMTD native edge count delta：`1562509222`
- REF native edge count delta：`1562708292`
- FB native edge count delta：`1562710115`
- REF/FB sampled counters 有大幅增加
- `HELPER_UPDATE_COUNT`：delta `324262`
- `SPLL_LOCK_CLASS=SPLL_UNLOCKED`，`PSTAT.locked=0`

### 仍未觀測到的 downstream activity

- `TAG_PENDING_COUNT` delta：`0`
- `TAG_GRANT_COUNT` delta：`0`
- `TAG_VALID_COUNT` delta：`0`
- `TRR_WRITE_COUNT` delta：`0`
- `IRQ_COUNT` delta：`0`
- `STATE_TRANSITION_COUNT` delta：`0`
- `DMTD_REF_ACCEPT` / `DMTD_FB_ACCEPT` delta：`0`

腳本將事件邊界分類為：

```text
STEP4_EVENT_BOUNDARY result=DMTD_SAMPLED_TRANSITION_TO_DEGLITCH_ACCEPT
```

同時 `DMTD_CLOCK` 與 input-edge ratio 判定在本次腳本中回報 `INVALID`；raw edge counters 本身仍有持續增加，因此這裡只能表示目前 Step 4 diagnostic qualification 尚未完成，不能把它直接等同於 PHY 或 JTAG 失敗。

## Observation

1. Fresh exact HEAD build、program、JTAG read 都成功。
2. Slave 的 PTP=8 會在 startup 後經等待轉為 PTP=9；因此只取單一早期 snapshot 會誤判 Step 2。
3. 20-sample focused regression 在等待後重新得到 Step 2/3 PASS，且沒有 mailbox invalid sample 或 counter decrease。
4. Step 3 handshake evidence 穩定存在，但 current-state 欄位顯示 idle，仍屬 read inconsistency，需要保留為觀測問題而非直接宣稱功能失敗。
5. Step 4 的 DMTD/raw sampled edge 與 helper 有活動，但 tag/TRR/IRQ/state transition 沒有活動，尚不能宣稱 SoftPLL startup gate 完整 PASS。

## Conclusion

本次實驗證明：

- `HARDWARE/FIRMWARE Step 2/3 = PASS`：在等待 startup transition 後，fresh/current hardware 的 Endpoint、MiniNIC、PTP、Foreign Master 與 WR handshake evidence 都通過 focused repeated sampling。
- `JTAG/DASHBOARD MEASUREMENT = PARTIAL`：Step 3 current-state 與 handshake evidence 仍有不一致；第一次 PTP=8 是 startup transitional state，不是 mailbox timeout。
- `Step 4 = NOT_PASS / PARTIAL EVIDENCE`：目前只有 DMTD sampled edge、RCER 與 helper activity 證據；tag/TRR/IRQ/state-transition downstream path 尚無活動，且 `PSTAT.locked=0`。因此不能宣稱 Step 4 已完成，也沒有修改 SoftPLL algorithm。

## Next Step

依 reviewer 建議，下一步先做 source/runtime read-only localization，沿著：

```text
DMTD sampled/deglitch accept
    -> tag request/grant/valid
    -> TRR write / IRQ
    -> helper update
```

確認第一個沒有活動的節點。未取得下一個單一變因與 reviewer 共識前，不修改 functional RTL、firmware、SoftPLL、DDMTD、PI、lock threshold、DCO 或 SI5340，也不 merge `main`。
