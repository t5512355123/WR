# EXP-WRPC-MASTER-BASELINE-AB-20260817

## 實驗基本資料

- 實驗日期：2026-08-17
- 實驗名稱：17ac382 Master 映像與新增 task 版本的 A/B 啟動比較
- Git branch：`exp/jtag-runtime-observability`
- 來源映像 commit：`17ac382`
- 目的：確認 Master 的 B002 early-init failure 是否由 `2ecf3c4` 新增 task/程式碼變更觸發。

## 相較於 baseline 的唯一修改

本次不重新編譯，只重新燒錄已保存的 `17ac382` Master SOF；Slave、PHY、QSFP lane、DMTD 與板端設定不變。

## 映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA-256：`be99f76886ad899b6efded328b0161d8c146b50cfe3be36c2d84468102caf2`
- Master SOF SHA-256：`a3a9922a6584c24e37ef4bc8f217d78a2fd6793c8c844f60cad82a6c13636f77`
- SOF 來源：`artifacts/EXP-WRPC-MASTER-FLASH-SKIP-20260817/`
- QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`

## 燒錄結果

- 目標：`DE5 [1-11.1]`（Master）
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Configuration succeeded；Quartus Programmer 報告 0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-BASELINE-AB-20260817/program_master.log`

## JTAG/runtime 原始結果

燒錄後立即於 2026-08-17 12:54:27 讀取。

### Master（DE5 [1-11.1]）

- `cpu_marker=B004`、`WDIAGS_TEMP=A0000044`：可到達主迴圈。
- `WDIAGS_MODE=3`：仍為 Slave。
- `WDIAGS_PTP_RX=0`、`WDIAGS_PTP_TX=3`。
- `WDIAGS_SSTAT=0`、`WDIAGS_PSTAT=1`、`WDIAGS_RXERR=2`。

### Slave（DE5 [1-11.2]）

- `cpu_marker=B004`、`WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x1C53`、`WDIAGS_PTP_TX=0x1AF9`。
- `WDIAGS_SSTAT=1`、`WDIAGS_PSTAT=1`、`WDIAGS_RXERR=0`。

原始紀錄：`artifacts/EXP-WRPC-MASTER-BASELINE-AB-20260817/runtime_after_program.log`。

## Observation

1. 17ac382 舊映像可到達 B004，證明 2ecf3c4 的新增 `force-master` task/相關程式碼與 B002 failure 有高度關聯。
2. 17ac382 仍讀到 Master `WDIAGS_MODE=3`，所以它只是可運作的 firmware baseline，不是同步成功 baseline。
3. Slave PTP RX/TX 持續增加，但因 Master 沒有真正成為 Master，不能把這些計數器解讀成 WR synchronization。

## Conclusion

本實驗支持以下結論：

> 17ac382 能正常完成 early initialization，而 2ecf3c4 不能；下一步不應再增加 task table 項目。Master role 應改掛在已存在的 `check-link` job 中，並維持非阻塞 `wrc_ptp_set_mode()`。

## Next Step

只移除 `force-master` 新 task，改在既有 `wrc_check_link()` 第一次執行時套用 Master role；完成後重新 compile、燒錄並先驗證 Master `B004` 與 `WDIAGS_MODE=2`。
