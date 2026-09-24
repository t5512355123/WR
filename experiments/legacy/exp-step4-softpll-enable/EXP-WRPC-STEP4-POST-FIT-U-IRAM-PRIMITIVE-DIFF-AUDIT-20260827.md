# EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827

## 實驗目的

依分支 2 在 `d40317d`（同一份 Master SOF 跨兩片 DE5 重現）之後給出的單一步驟建議 `POST_FIT_U_IRAM_PRIMITIVE_DIFF_AUDIT`，稽核既有 Master/Slave Quartus post-fit `U_iram` / `altsyncram` 實作差異。

本輪只讀取既有 fitter/map report、生成的 `altsyncram` TDF 與已整理的 M20K location 清單；不修改 RTL、MIF、RAM mode、constraint，不重新編譯，也不重新燒錄。

## 稽核輸入與 provenance

- source/build checkout：`0b3b012df2697e785431a43f8ca77cd5f0f94a14`
- Quartus project：`quartus/jtag_runtime_diag`
- Master fit report：`quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.fit.rpt`
- Slave fit report：`quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.fit.rpt`
- Master map report：`quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.map.rpt`
- Slave map report：`quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.map.rpt`
- Master generated primitive：`altsyncram_vv44`（`db/altsyncram_vv44.tdf`）
- Slave generated primitive：`altsyncram_es44`（`db/altsyncram_es44.tdf`）
- Master SOF SHA-256：`d94cc19d0bd198b52b818e935df3b82e9df54de6583dc39de0eb39905f7b5102`
- Slave SOF SHA-256：`ed0e3a12cd426ca1b57f610b20e9609d671b8c8a0c0994204b1fd4668312480d`

四份 Quartus report 與兩份 generated TDF 的 SHA-256 及 remote raw excerpt SHA-256 見 [build_provenance.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/build_provenance.txt) 與 [artifact_sha256.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/artifact_sha256.txt)。

## Post-fit `U_iram` / `altsyncram` 比較

| 欄位 | Master | Slave | 稽核判讀 |
|---|---|---|---|
| `operation_mode` | `BIDIR_DUAL_PORT` | `BIDIR_DUAL_PORT` | 相同 |
| `width_a / width_b` | `32 / 32` | `32 / 32` | 相同 |
| `widthad_a / widthad_b` | `16 / 16` | `16 / 16` | 相同 |
| `address_reg_b` | `CLOCK0` | `CLOCK0` | 相同 |
| `outdata_reg_b` | `UNREGISTERED` | `UNREGISTERED` | 相同 |
| `clock_enable_input_b` | `NORMAL` | `NORMAL` | 相同 |
| `clock_enable_output_b` | `NORMAL` | `NORMAL` | 相同 |
| `read_during_write_mode_mixed_ports` | `DONT_CARE` | `DONT_CARE` | 相同 |
| `power_up_uninitialized` | `FALSE` | `FALSE` | 相同 |
| `init_file` | `../../build/firmware/master/wrc.mif` | `../../build/firmware/slave/wrc.mif` | 依 role 不同；是唯一明確的 primitive parameter 差異 |
| `init_file_layout` | `PORT_A` | `PORT_A` | 相同 |
| `ram_block_type` | `AUTO` | `AUTO` | 相同 |
| Fitter mode / clock mode | `True Dual Port / Single Clock` | `True Dual Port / Single Clock` | 相同 |
| 實作 RAM block | `96 M20K / 0 MLAB` | `96 M20K / 0 MLAB` | 資源數量相同 |

以上欄位取自 map report 的 post-map parameter log 與 fit report 的 `Fitter RAM Summary`，不是只比對原始 VHDL generic。完整欄位摘要見 [post_fit_iram_parameter_diff.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/post_fit_iram_parameter_diff.txt)。

## Physical M20K placement / bank-block mapping

- Master physical M20K location count：`96`
- Slave physical M20K location count：`96`
- 兩者共同 location：`69`
- Master-only location：`27`
- Slave-only location：`27`
- Master example：`M20K_X150_Y20_N0`, `M20K_X150_Y21_N0`, `M20K_X150_Y40_N0`, `M20K_X150_Y41_N0`, `M20K_X150_Y42_N0`
- Slave example：`M20K_X150_Y14_N0`, `M20K_X150_Y15_N0`, `M20K_X150_Y26_N0`, `M20K_X176_Y20_N0`, `M20K_X176_Y22_N0`

因此，兩個 fitted image 雖然對 `U_iram` 使用相同數量及相同類型的 M20K，實體 bank/block placement 並不相同。這支持「差異跟著 fitted image implementation 走」的方向，但尚不能從 placement 差異單獨推出某一個 M20K 或 routing net 是 root cause。location set 的摘要、集合 hash 與 raw excerpt hash 見 [post_fit_iram_location_diff.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/post_fit_iram_location_diff.txt)。

## Port-A / Port-B clock mapping

- Fitter summary 對兩邊均標示 `Single Clock`。
- generated primitive 對 Port-B 的 address、byte-enable、data-in、read-enable、write-enable clock 均標示為 `clock1`。
- post-map parameter log 對 Port-B 的 registered controls（`address_reg_b`、`byteena_reg_b`、`indata_reg_b`、`rdcontrol_reg_b`、`wrcontrol_wraddress_reg_b`）均為 `CLOCK0`；兩邊完全一致。
- 因此本輪沒有發現 Master/Slave 的 Port-A/Port-B clock configuration 差異；差異在 image-specific MIF、generated primitive identity、少量生成 TDF 的 alias/decode wiring，以及 M20K physical placement。

## Generated TDF 差異

將 primitive 名稱、Master/Slave MIF path 與只反映資源摘要的 `lut 144` 差異正規化後，兩份 TDF 只剩 8 個 +/- diff lines。內容是 `decode2` / `rden_decode_a` 周邊的 synthesis wire alias 與 assignment 形式差異：Master 直接使用 `address_a_wire[15..14]`，Slave 經 `w_addr_val_a4w` / `w_addr_val_a9w` 中間 wire。這是應保留的 post-fit elaboration 差異，但本輪尚未證明它造成 first-load q_b 差異。詳見 [post_fit_iram_tdf_diff.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/post_fit_iram_tdf_diff.txt)。

## 判讀

1. `operation_mode`、寬度、Port-B address/data/control register、clock enable、read-during-write、power-up、RAM block type 與 fitter 的 RAM/clock mode 均相同；目前沒有證據支持「Master/Slave 原始 RAM generic parameter 不同」是原因。
2. `init_file` 明確不同，且兩個 generated primitive 分別由 Master/Slave MIF 建立；這是 image-dependent implementation 差異，不能在本輪直接排除或定罪。
3. M20K placement 只有 `69/96` 相同，表示兩個 fitted image 的 physical bank/block mapping 確實不同。結合 `d40317d` 的同一份 Master SOF 跨兩片板結果相同，錯值更像跟著 image/fitted implementation 走，而非跟著 physical board identity 走。
4. 結合既有 `03c5f90`（raw primitive q_b 已出現差異）、`04c3241`（未觀察到 Port-A 同址寫入碰撞）及 `d40317d`（cross-board image-following），fault boundary 目前仍在 image-specific RAM initialization / generated elaboration / placement-routing 或其交互作用。

`ROOT_CAUSE = NOT_PROVEN`。本輪沒有足夠證據把原因唯一收斂到 MIF、TDF alias、某一個 M20K placement 或某一條 routing net。

## 限制與交接

- 本輪重用既有 build artifacts，沒有重新編譯，因此沒有新增 fit result 或 timing result。
- physical location set 的比較是 fit report 的 post-fit RAM summary；它能證明 placement 不同，不能單獨證明 placement 導致資料差異。
- TDF 的 8-line residual diff 可能只是 synthesis naming/aliasing，也可能代表需要更深的 netlist equivalence 檢查；尚未做 formal equivalence。
- 依流程，本報告推送後將把本輪結果交給分支 2，等待下一個單一步驟；在新建議前不修改 RAM mode、MIF 或加入 workaround。

## 原始證據

- [post_fit_iram_parameter_diff.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/post_fit_iram_parameter_diff.txt)
- [post_fit_iram_location_diff.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/post_fit_iram_location_diff.txt)
- [post_fit_iram_tdf_diff.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/post_fit_iram_tdf_diff.txt)
- [build_provenance.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/build_provenance.txt)
- [artifact_sha256.txt](raw/EXP-WRPC-STEP4-POST-FIT-U-IRAM-PRIMITIVE-DIFF-AUDIT-20260827/artifact_sha256.txt)
