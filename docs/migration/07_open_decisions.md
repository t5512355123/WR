# 待決定事項與衝突

以下項目刻意不自動合併或刪除。

## 原始碼衝突

- Laptop snapshot 沒有完整的 pain 端 vendor 與韌體/artifact set。因此在完成 inventory 與備份後，使用 pain snapshot 作為正式基準。
- root Laptop/pain QSF 差異被確認為 Quartus metadata（`LAST_QUARTUS_VERSION`）；正式 project 保留已驗證的 pain 端原始碼，記錄比較結果，不暗中選擇其中一方。
- inventory 時 pain vendor tree 處於 detached 且 dirty 狀態。其 HEAD、remote 與修改內容記錄在 `provenance/vendor_git_state.md`。

## 未合併內容

- `simplewa`、complex word alignment、62.5 MHz、DCO、SFP EEPROM/I2C、runtime probe、load probe、JTAG Wishbone 與 no-SFP-match 除錯版本仍是 `archive/diagnostics/` 下的歷史 snapshot。
- 沒有為了解決上述衝突而修改 WR algorithm、PHY、PTP、SoftPLL、DMTD、QSFP、role、lane、PPS 或 pre-emphasis。

## 技術後續工作

- 目前基準版本有 link/configuration 證據，但沒有時間同步證據。
- TimeQuest report 顯示最差 setup 與 recovery slack 為負值，且有數個 unconstrained path。這應是未來的 timing/constraint 實驗，不是未記錄的遷移變更。
- uRV/wrpc-sw runtime、PPSi state、SoftPLL lock 與校準後的 PPS alignment，仍需要各自建立 commit 與 artifact 的獨立實驗。
