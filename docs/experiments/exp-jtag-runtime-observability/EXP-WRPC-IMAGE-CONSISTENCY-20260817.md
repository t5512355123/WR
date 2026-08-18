# EXP-WRPC-IMAGE-CONSISTENCY-20260817：Master/Slave 唯讀 probe 對齊與角色映像核對

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-IMAGE-CONSISTENCY-20260817`
- 日期：2026-08-17
- Git branch：`exp/jtag-runtime-observability`
- 硬體 source commit：`5bddeda`（對齊 Master 時鐘狀態唯讀 probe）
- pain checkout：detached `5bddeda`

## 這次想驗證什麼

先讓 Master 與 Slave 使用相同的 clock-activity probe 欄位定義，再觀察兩端的 clock/reset、PHY link、PTP 與 WR state，避免把不同映像的 probe 讀值拿來比較，或把單純的 compile/program success 當成時間同步成功。

## 相較 baseline 唯一修改了什麼

- 只在 `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd` 把 `clock_activity_probe(63 downto 54)` 接到與 Slave 相同的唯讀訊號：system clock lock、WR reset、PHY reset、SI5340 done、PPS/time valid、RX/TX ready 與 link status。
- 沒有修改 WR firmware 原始碼、PHY lane/polarity/PCS、DMTD、SoftPLL 或 SI5340 控制。
- 重新產生 Master firmware/MIF 與 Master SOF，並只重新燒錄 Master；Slave 沿用既有 `933ce3e` 診斷版。

## 版本、建置與映像追溯

- Quartus Prime：17.0.0 Build 595
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`17c716835d9eebcb59169598395ede3ba3569e6bd553d977445d943941417baf`
- Master SOF SHA-256：`fba3c3cdfb5c70acd5f1357ceb6f1ba993035f321427ec59beaaaf265d14e9b3`
- Slave SOF SHA-256（沿用）：`f45a648f0e380a5ed0238f2d1030ebea9943cba93066c1f5cbc7247d40aa4a67`
- Full Compilation：成功，0 errors；timing closure=`NO`
- compile log SHA-256：`8aa2b56e4a624ff92d1f5f8dade1e483ad6fda43f69dd605771ddb43b13ad636`
- build info SHA-256：`3bcd66b290e7a37bee9d192a5b67447c76e554639ba9547613e07dd6e5510139`

## 燒錄結果

- Cable：`DE5 [1-11.1]`（Master）
- Programmer：Quartus 17.0.0 Build 595，JTAG ID `0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：`Configuration succeeded`，0 errors、0 warnings
- program log SHA-256：`340581797df280dedc89445e57349badbc2a5dc508231f27698248ebc5217cf3`

## JTAG/runtime 原始結果

- 燒錄後初始讀值：Master 在啟動過渡期間為 `MODE=0/PTP=0`；等待 10 秒後 CPU marker=`0xB004`、runtime 已啟動。
- 但 Master 的有效 runtime 角色為 `WDIAGS_PTP=4、WDIAGS_MODE=3、status_low=0xEF、time_valid=0`，不是預期的 Master `PTP=6、MODE=2`。
- Slave 為 `WDIAGS_PTP=9、WDIAGS_MODE=3、status_low=0xEF、time_valid=0`，並持續有 `PTP_RX` 與 foreign parent activity。
- 兩端 clock-activity probe 現在欄位已一致；一秒窗口兩端都顯示 `SYS625_LOCKED=1、CORE_RESET_N=1、PHY_RST=0、SI_DONE=1、PPS_VALID=1、TIME_VALID=0、RX_READY=1、TX_READY=1、LINK_UP=1、LINK_OK=1`。
- 60 秒唯讀 session 完成，沒有 timeout：Master accepted `42/60`、rejected `18/60`；Slave accepted `34/60`、rejected `26/60`。
- Master 最後有效 sample：`WDIAGS_PTP_RX=0、WDIAGS_PTP_TX=0x63、WR_SIGNAL RX/TX=0、SoftPLL LAST_STATE=7、time_valid=0`。
- Slave 最後有效 sample：`WDIAGS_PTP_RX=0x17B5、WDIAGS_PTP_TX=0x1366、WR_SIGNAL RX=0、fail_count=1、SoftPLL locked=0、time_valid=0`。

原始 log：

- `build/artifacts/EXP-WRPC-IMAGE-CONSISTENCY-20260817/runtime_after_program.log`，SHA-256：`79d3543f964c0ce8ec52b8a02cbc1ee0350ac81cc66548e2328f00c42b090d6e`
- `build/artifacts/EXP-WRPC-IMAGE-CONSISTENCY-20260817/runtime_10s_after.log`，SHA-256：`3f42c4b27abb6325d2c4f9912242e5f3b6e74a733a09ba0335d161a84d0da6f4`
- `build/artifacts/EXP-WRPC-IMAGE-CONSISTENCY-20260817/phy_activity_after_new_master.log`，SHA-256：`f8bee248f33f0178e25dd2b462336ebb9991a7599ff0e29ffcf0e25187c315c3`
- `build/artifacts/EXP-WRPC-IMAGE-CONSISTENCY-20260817/runtime_60s.log`，SHA-256：`bb3b05814462ad6f707c463889531a75e7211fad42eb8d2749f8cfdebbf4ad28`

## Observation

這次 probe 對齊本身有效：兩端的 clock/reset/link 欄位可以使用同一套解碼，排除了前一輪 Master probe 高位固定為 0 所造成的比較污染。但是，Master 新產生的 MIF/映像啟動成 Slave 角色；因此本輪不是有效的 Master/Slave WR A/B 實驗。兩端都沒有 `time_valid=1`，也沒有足夠證據證明 WR handshake 或 SoftPLL lock 成功。

## Conclusion

本輪只能證明：

1. Master/Slave clock-activity probe 欄位已可比較。
2. Quartus compile 與 Master JTAG programming 都成功。
3. 本輪產生的 Master runtime 角色錯誤，導致「兩端都是 Slave」；因此不能用本輪結果判斷 PHY、DMTD、DCO 或 SoftPLL 是同步失敗根因。
4. 雙板 WR synchronization 仍未完成。

## Next Step

先修正 Master firmware/MIF 的來源與建置驗證，要求燒錄前就能由 artifact/設定確認 `CONFIG_INIT_COMMAND` 為 Master；重新 compile 後先做 MIF/config sanity check，再燒錄 Master。目標是恢復 `Master MODE=2/PTP=6`、`Slave MODE=3/PTP=9`，之後才重新進行 60 秒 WR handshake/SoftPLL 觀測。
