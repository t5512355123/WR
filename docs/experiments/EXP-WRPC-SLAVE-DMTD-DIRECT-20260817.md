# 實驗紀錄：Slave 恢復 direct DDMTD 取樣方向

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-SLAVE-DMTD-DIRECT-20260817`
- 日期：2026-08-17（Asia/Taipei）
- Git branch：`exp/master-9f-observability`
- Git commit：`de7156d1dcd437a67b72b383568465525b066683`
- GitHub：`origin/exp/master-9f-observability`

## 這次想驗證什麼

在不改變已知可工作的 Master role 與 Master bitstream 的前提下，確認 Slave 的 SoftPLL helper error 飽和與未鎖定，是否來自 reverse DDMTD 取樣方向。目標是讓 Slave 從 reverse 取樣恢復為 WR core 預設的 direct 取樣方向，並重新觀察 helper lock、SoftPLL lock、`time_valid` 與 `pps_valid`。

## 相較 baseline 唯一修改

只修改 `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd` 的 Slave `xwr_core` generic：

```vhdl
g_softpll_reverse_dmtds => false
```

Master 的 source、MIF、SOF、role 設定與已燒錄映像均未修改。沒有改 WR role 切換方法、PTP、servo 演算法、SI5340 控制或 PHY lane 設定。

## 建置與識別資料

- Quartus Prime：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Slave QSF SHA-256：`4d24dc4238a5562d49d304462b54149f18f82e61cd250cafff9ec7264f22c233`
- Slave SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave MIF SHA-256：`0a6cc58f3a331aceab74757e321afebe63a403d04281dfbf0fe84f5742d283fa`
- Slave SOF SHA-256：`f12bc0fb001c7977c2dc251f948cc6bf60957cb2dfbf040ca1593b66230d0ebd`
- Fitter：`Successful`
- Compile：`Full Compilation was successful`
- Timing closed：`NO`
- Worst setup slack：`-0.234 ns`
- Worst hold slack：`0.037 ns`

Master 固定沿用乾淨 9f 基線：

- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`

## 燒錄結果

- 目標：Slave，cable `DE5 [1-11.2]`
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A3C0EE`
- `Configuration succeeded -- 1 device(s) configured`
- `Quartus Prime Programmer was successful. 0 errors, 0 warnings`
- 燒錄時間：2026-08-17 16:59:48 至 17:00:07

原始證據位於 pain：

```text
/home/b10504072/04_WR/artifacts/EXP-WRPC-SLAVE-DMTD-DIRECT-20260817/
```

其中包含 `program_slave.log`、`build_info_jtag_slave.txt`、`quartus_jtag_slave_compile.log`、SOF/MIF 副本與燒錄前 hash。

## JTAG/runtime 原始結果

本節在燒錄完成後立即建立，runtime 唯讀觀測尚待執行；尚未以本實驗宣稱 Slave 已同步。

預計使用同一 JTAG session 讀取：

- `status_probe`、`WDIAGS_SSTAT`、`WDIAGS_PSTAT`
- `WDIAGS_PTP`、PTP RX/TX 與 parent metadata
- `WR_SPLL_HELPER_LOCKDET`、helper error/output、tag valid/TRR write
- `time_valid`、`pps_valid` 與 `UCNT`

## Observation

燒錄與 compile 證據已成立；同步結果尚未取得。

## Conclusion

目前只能確認：Slave direct-DDMTD 版本已成功編譯並成功燒錄。尚不能確認此單一變因是否使 Slave SoftPLL lock 或完成兩台 DE5a 的時間同步。

## Next Step

使用現有唯讀 JTAG 時間序列腳本觀察 Slave，並與固定的 Master 9f 基線比較。只有在 Slave 穩定呈現 `link_ok=1`、`WDIAGS_PSTAT` lock bit=1、`time_valid=1`、`pps_valid=1`，且同一觀測窗內 parent/servo 證據一致時，才可宣稱同步完成。
