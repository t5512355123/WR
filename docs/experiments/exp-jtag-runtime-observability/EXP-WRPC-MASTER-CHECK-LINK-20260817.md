# EXP-WRPC-MASTER-CHECK-LINK-20260817

## 實驗基本資料

- 實驗日期：2026-08-17
- 實驗名稱：既有 check-link 任務套用 Master role 驗證
- Git branch：`exp/jtag-runtime-observability`
- Git commit：`4cfbd71`（在既有連線任務套用Master角色）
- 目的：不增加 task table 項目，讓既有 `wrc_check_link()` 第一次執行時套用 Master role。

## 相較於 baseline 的唯一修改

- 移除 `force-master` 新 task。
- 在既有 `check-link` job 加入一次性 `wrc_ptp_set_mode(WRC_MODE_MASTER)` / `wrc_ptp_start()`。
- `CONFIG_FORCE_MASTER_AFTER_INIT` 下的 `wrc_ptp_set_mode(MASTER)` 使用 non-blocking 分支。
- Slave、PHY、QSFP lane、DMTD、PTP state machine 與 JTAG observability 未修改。

## 編譯與映像 provenance

- Quartus：17.0.0 Build 595 04/25/2017 SJ Standard Edition
- Master MIF SHA-256：`9ef816d9278622629f8ec1c92e93ee9f67fac44e32076eeca7617d2ecc35091d`
- Master SOF SHA-256：`2b066c3d23694073eda4233d800594c807f5d8cabd2701f3a6ff8dc13e17b329`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Quartus 結果：Fitter successful，Full Compilation successful，0 errors / 272 warnings；`timing_closed=NO`。

## 燒錄結果

- 目標：`DE5 [1-11.1]`（Master）
- JTAG ID：`0x02E660DD`
- Programmer checksum：`0x30A31DBA`
- 結果：Configuration succeeded；Quartus Programmer 報告 0 errors / 0 warnings。
- 原始紀錄：`artifacts/EXP-WRPC-MASTER-CHECK-LINK-20260817/program_master.log`

## JTAG/runtime 原始結果

燒錄後立即於 2026-08-17 13:00:34 讀取。

### Master（DE5 [1-11.1]）

- `cpu_marker=B00B`、`WDIAGS_TEMP=B002`、`reset=0`、`fault=0`。
- `WDIAGS_MODE=0`、`WDIAGS_PTP_RX=0`、`WDIAGS_PTP_TX=0`。
- `PC=0x000053A4`，對應 `timer_delay`。

### Slave（DE5 [1-11.2]）

- `cpu_marker=B004`、`WDIAGS_MODE=3`。
- `WDIAGS_PTP_RX=0x1CFE`、`WDIAGS_PTP_TX=0x1C01`。

原始紀錄：`artifacts/EXP-WRPC-MASTER-CHECK-LINK-20260817/runtime_after_program.log`。

## Observation

1. Master 仍未離開 B002，check-link role activation 沒有執行機會。
2. Slave 可正常執行，表示本次 failure 仍集中在 Master early initialization。
3. 與 17ac382 的 B004 A/B 比較顯示，新增的 non-blocking role 變更仍可能改變 Master firmware 啟動行為。

## Conclusion

本實驗只支持以下結論：

> `4cfbd71` 編譯與燒錄成功，但 Master 停在 B002，尚未驗證 role activation；本次不能宣稱 WR synchronization 成功。

## Next Step

只撤回 `wrc_ptp_set_mode()` 的 non-blocking 分支，保留既有 check-link 呼叫，重新做 compile/burn A/B。若恢復 B004，便可確認 non-blocking 分支是 B002 的最小觸發因素；之後再以不改既有 `wrc_ptp_set_mode()` 的方式處理 role 啟動。
