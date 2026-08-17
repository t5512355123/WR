# 實驗紀錄：Slave 使用已驗證 DCO handshake baseline

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-DCO-HANDSHAKE-BASELINE-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/master-9f-observability`
- Source/build commit：`a334630f6b041fb076c0495b5c308dbcc199d9de`

## 實驗名稱

`固定成功 Master，將 DCO handshake restore 版本套用到 Slave`

## 這次想驗證什麼

Master 已在相同 DCO handshake restore 版本恢復 `MODE=2/status=FF`。本次只重新編譯並燒錄 Slave，確認 Slave 在成功 Master 對端下是否能進入 parent/servo acquisition，並觀察 DCO state、SoftPLL activity/lock 與 `time_valid/pps_valid`。

成功判準不是只看 link：需要看到 Slave `MODE=3`、parent/foreign 有效、SoftPLL state/lock activity 有進展，最終才以 Slave `time_valid=1、pps_valid=1、spll_locked=1` 且連續取樣穩定作為同步證據。

## 相較 baseline 唯一修改

只把已在 Master A/B 證實可恢復 role 的 DCO controller handshake restore 版本編譯到 Slave image。Slave role、startup command、PHY、clock mapping、SoftPLL firmware 與 DCO debug probe 皆不再新增修改；Master 不重新燒錄。

## Build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Project/top-level：`DE5a_wr_slave_jtag`
- QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`f24527afe0e7bdb5b5bd103263fb87436e317c916186fa91e933ceef05b8e8a4`
- Slave SOF SHA-256：`fd9db251d8c81b4ef65ffed547f52bed4ebeb5fe6946ee5aaae94dd7567f5dff`
- Fitter：`Successful`
- Compile：`Full Compilation was successful`
- Timing closed：`NO`
- Worst setup/hold slack：`-0.195 ns / -3.503 ns`
- Unconstrained clocks/inputs/outputs：`3 / 471 / 82`
- Compile log：`/home/b10504072/04_WR/build/quartus_jtag_slave_compile.log`
- Compile log SHA-256：`eb3905e482893c8c38ff5868ce2d4ced7e16210939d61ecd3119a11142133749`

## 燒錄結果

待燒錄後立即補入 programmer 原始輸出、cable、JTAG ID、checksum、結果與 log hash。

## JTAG/runtime 原始結果

待燒錄後以 read-only `read_dco_state.tcl`、`read_dco_activity.tcl`、`read_clock_activity.tcl` 與 `read_wb_timeseries_session.tcl` 讀取。

## Observation

待補入實測結果。

## Conclusion

待補入；compile/program 成功不等於 Slave synchronization 成功。

## Next Step

若 Slave SoftPLL activity/lock 仍為 0，依 state/read-only 證據只選一個下一步：helper acquisition/source gating；若開始進入 lock，延長觀察確認穩定性，不改 Master。
