# EXP-WRPC-STEP4-WDIAGS-MAP-FIX-2

## 實驗基本資料

- 實驗日期：2026-08-20（Asia/Taipei）
- 實驗名稱：Step 4 WDIAGS correlation 位址配置修正後的 fresh HEAD 燒錄與 runtime 驗證
- Git branch：`exp/step4-softpll-enable`
- 實際燒錄來源 commit：`edd12590eef2b77cd61aed8cb182280a1fbe9fe4`
- 實驗目標：確認修正 private WDIAGS 與 secondary bridge 對齊後，fresh firmware、fresh Quartus SOF 是否仍能提供正確的 Step 1-3 runtime evidence，並讓 Step 4 correlation read-only observability 不再發生欄位 alias。

## 本次唯一修改

本輪沒有修改 PHY、PPSI、WR signaling、SoftPLL 演算法、PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 控制行為。

相較前一個可編譯 commit `b2274d98f1cb6841e1a45dcf152c1fb04365d5f5`，本次只有：

1. 將 secondary Wishbone bridge SDB base 從 `0x00000E00` 移到合法對齊的 `0x00001000`。
2. 同步更新 `c_secbar_sdb_address` 與 RTL 位址配置註解。

這是為了修正 Quartus crossbar 的位址重疊錯誤，不是功能演算法變更。

## 先前 build-only 失敗證據

commit `b2274d98f1cb6841e1a45dcf152c1fb04365d5f5` 的 clean compile 沒有燒錄，Quartus 報告：

```text
Address ranges must be distinct (slaves 9[0xc00/0xff00] & 12[0xe00/0xfc00])
Quartus Prime Full Compilation was unsuccessful
```

保留檔案：`build_master_alignment_failure.log`。

這次錯誤屬於 Wishbone SDB address alignment，不是 runtime 或 FPGA configuration 失敗。

## Fresh build provenance

兩片板均從 commit `edd12590eef2b77cd61aed8cb182280a1fbe9fe4` clean checkout/build，使用 Quartus Prime 17.0.0 Build 595。

### Master

- Project：`DE5a_wr_master_jtag`
- QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`6989b73e3cf3d64a57cfca9f28a2d2625b0c92f90900450db2bd7f24d27c8f3e`
- SOF SHA256：`1ac0873a3b06b5220cbfc13b6fa243be53ca4a3d7df190d26f0230e0f3df2f43`
- Fitter：Successful
- Timing：`TIMING_CLOSED=NO`；worst setup `-0.178 ns`、worst hold `-3.499 ns`

### Slave

- Project：`DE5a_wr_slave_jtag`
- QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- MIF SHA256：`3657f026b9f69cf3e321e142be886eb6cd04945a1bafd36924fa24cd64b45f81`
- SOF SHA256：`dbd0a2ab07b7e1b0459568da43b4b323da60055a74f63641d74070e50e705fe3`
- Fitter：Successful
- Timing：`TIMING_CLOSED=NO`；worst setup `-0.408 ns`、worst hold `-3.503 ns`

完整 build identity、Quartus compile log 與 MIF hash 放在同資料夾的 `build_info_jtag_*.txt`、`quartus_jtag_*_compile.log` 與 `*_build_hashes.sha256`。

## 燒錄結果

2026-08-20 00:49-00:50 使用上述 fresh SOF 燒錄：

| 板卡 | Programmer checksum | 結果 |
|---|---:|---|
| Master `DE5 [1-11.1]` | `0x30A4A8E2` | `Configuration succeeded -- 1 device(s) configured` |
| Slave `DE5 [1-11.2]` | `0x30A39139` | `Configuration succeeded -- 1 device(s) configured` |

兩次 programmer 都回報 `0 errors, 0 warnings`。完整原始輸出保留於 `program_master.log`、`program_slave.log`；`programmed_sof.sha256` 用來核對燒錄前後的 SOF 檔案來源。

## JTAG runtime 結果

本次在兩片 FPGA 燒錄上述 fresh SOF 後，只使用唯讀 JTAG script 觀察；沒有寫入設定，也沒有寫 `DATA_SNAPSHOT`。原始輸出保留於本實驗資料夾：

- `jtag_runtime_snapshot.log`
- `jtag_timeseries_10x1000ms.log`
- `jtag_hpll_helper_correlation_20x1200ms.log`

### Fresh HEAD 的 Step 1-3 證據

| 項目 | Master `DE5 [1-11.1]` | Slave `DE5 [1-11.2]` | 判讀 |
|---|---|---|---|
| CPU | `reset=0, fault=0, im_valid=1, marker=B004, seen=1` | `reset=0, fault=0, im_valid=1, marker=B004, seen=1` | firmware runtime 有活動 |
| MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` | 節點身份正確且唯一 |
| WR role | `MODE=2, PTP=6` | `MODE=3, PTP=9` | Master/Slave role 正確 |
| PHY/link | status low `FF`，`RXERR=0` | status low `CF`，`RXERR=0` | link/PHY gate 通過；Slave 尚非 time-valid |
| PTP counter | `PTP_RX=0xA8, PTP_TX=0x17D` | `PTP_RX=0x17F, PTP_TX=0x75` | PPSI/PTP packet path 有活動 |
| Foreign Master | 不適用 | `FOREIGN_META=03000001` | foreign count=1、best index=0 |
| MiniNIC counter | `TX=0x1EC, RX=0x108` | `TX=0x119, RX=0x1DB` | frame-level path 有活動 |

以上證據表示這個 exact fresh HEAD 已重現 Endpoint、MiniNIC、PPSI/PTP packet path 與 Master/Slave role；不表示 SoftPLL 已鎖定，也不表示 Slave `time_valid=1`。

### Step 4 read-only time-series 證據

時間序列中只採用 script 標示為有效的 sample；JTAG 讀取期間若跨 register refresh 邊界造成 torn/invalid frame，該列不作判斷。

- Slave `LOCK_ENABLE=4`，`SPLL_STATE=00030004`，`LOCK_POLLS` 持續存在。
- `REF_COUNT`、`TAG_COUNT`、`IRQ`、`TAG_VALID_COUNT`、`TRR_WRITE_COUNT` 與 `UCNT` 隨時間增加，表示 DDMTD/tag/TRR/servo helper 路徑有持續活動。
- `FOREIGN_META=03000001`、PTP=9、parent flags 維持有效，表示輸入來源與 WR parent discovery 沒有在本輪消失。
- helper correlation 欄位已不再出現前一輪的位址 alias；`PRECLAMP_ERROR`、`TAG_DELTA`、`EXPECTED_DELTA`、`P_SETPOINT` 等欄位可獨立變化。
- `read_hpll_helper_correlation.tcl` 在 Master 端回報 `No In-System Sources and Probes instance was found`；這是該額外 correlation probe 不存在或不可連線的 observability 限制，Master 的一般 `read_wb_runtime.tcl` 與 time-series read 仍可執行，不據此修改硬體。

### Step 4 的第一個可觀測停滯點

Slave correlation sample 反覆顯示：

```text
DCO_DEBUG=FF6800000008A3A2
STEP=0  HPLL_LOAD=0  BUSY=1  ERROR=0
DAC_HPLL=010003E8  DAC_MAIN=010002E8
```

`DCO_DEBUG` 的 source-based decode 為：`STEP` 是已完成的 DCO step count、`HPLL_LOAD` 是當下的 HPLL load pulse、`BUSY` 是 DCO controller bus activity、`ERROR` 是 controller error。20 次 correlation observation 中 `STEP` 一直是 0，且 DAC shadow 沒有改變；因此目前能由證據指出的第一個停滯點，是 **helper/SoftPLL 輸出之後到 DCO actuator 完成 step 的路徑**。這還不是根因定論：JTAG snapshot 可能捕捉不到短暫的 load pulse，下一步必須沿 `dac_hpll_data/load -> si5340a_controller_dco -> I2C bus done -> step_count` 做 source/runtime 對照。

本輪沒有修改 SoftPLL 演算法、PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 控制行為。

## 目前結論

本次證據支持：

1. commit `edd1259` 的 Master/Slave firmware 與 Quartus design 可以 clean compile。
2. 兩份由 exact fresh HEAD 產生的 SOF 已成功 configuration 到指定 FPGA。
3. fresh HEAD 已重現 Step 1-3 的 CPU、PHY/link、唯一 MAC、MiniNIC counter、PPSI/PTP counter、Master/Slave role 與 Slave Foreign Master。
4. Step 4 尚未 PASS。SoftPLL 輸入 tag、TRR、helper、servo update 都有活動，但 DCO controller 尚未觀察到完成 step；`STEP=0`、`HPLL_LOAD=0`、DAC shadow 不變是目前最接近第一個 blocker 的證據。
5. 目前不能只憑 `BUSY=1` 判定 I2C 一定死鎖，也不能只憑 JTAG snapshot 宣稱 load pulse 從未發生；根因仍需 source-level handshake audit 與必要時增加一次性的 read-only event evidence。
6. timing closure 尚未達成（Master worst setup `-0.178 ns`、Slave `-0.408 ns`），這是 fresh build 的限制，與本次 runtime 判讀分開記錄。

## 下一步

1. 維持目前 bitstream 不變，先完成 source audit：`xwr_core` 的 `dac_hpll_load_p1_o/dac_hpll_data_o`、top-level `si5340a_controller_dco` 的 pending 判斷、I2C `bus_state/bus_done` 與 `dco_step_count` 的完整 handshake。
2. 確認 `iHPLL_LOAD` 是 pulse、data change detection 是否成立，以及 controller 是否能觀察到 bus busy 再回到 idle。
3. 若需要新的證據，先只增加 read-only observability；任何 functional change 都必須另開單一變因、先 commit、clean build、燒錄後立即新增實驗紀錄。
4. 不在 Step 4 為了追求 `spll_locked=1` 或 `time_valid=1` 修改 PI、lock threshold、DDMTD 或 SI5340 演算法。
