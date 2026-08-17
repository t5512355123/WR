# 實驗紀錄：歷史成功 Master SOF A/B

## Experiment ID / 日期

- Experiment ID：`EXP-WRPC-MASTER-9F-HISTORICAL-SOF-AB-20260817`
- 日期：2026-08-17（Asia/Taipei）
- 實驗分支：`exp/master-9f-observability`
- 映像來源 commit：`302ffc1`（歷史 clean-9f Master diagnostic build）
- 本次紀錄提交不代表硬體映像來源改變；燒錄檔使用已保存 artifact。

## 實驗名稱

`歷史成功 9f848ec Master SOF 與目前 observability SOF 的不改 source A/B`

## 這次想驗證什麼

上一個實驗使用目前分支重新編譯的 Master SOF，雖然 compile/program 成功，但 runtime 讀到 `MODE=3、status=0xEF`。本次只燒錄歷史上實際達到 `marker=B004、MODE=2、PTP=6、status=0xFF` 的保存 SOF，驗證問題是否由最新 Master top-level observability 編譯映像造成。

## 相較 baseline 唯一修改

只替換 FPGA 燒錄檔；不修改 source、firmware、startup command、Slave、PHY、clock、JTAG script 或 role API。

## Build / image provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- 歷史 build artifact：`/home/b10504072/04_WR/artifacts/EXP-WRPC-MASTER-9F-CLEAN-OBSERVABILITY-20260817/master.sof`
- 歷史 source/build commit：`302ffc1`
- Master startup command：`vlan off;ptp stop;mode master;ptp start`
- Master QSF SHA-256：`9bae9b2f2d1894d75f4e2a51621ca1052b62044c94d038ef96841a1a943e206d`
- Master SDC SHA-256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA-256：`b85fc3cad62ec3ea6a1bd16e8c7a55b104e25f0fab855a92fd0217ad85f079a0`
- Master SOF SHA-256：`383c1c65ce7a08ba98358f8b52a5492d70b816d87c2071f0f254c7f5589f3b93`

## 燒錄結果

待燒錄後立即補入 programmer 原始輸出、cable、JTAG ID、checksum、結果與 log hash。

## JTAG/runtime 原始結果

待燒錄後使用既有 read-only `read_wb_runtime.tcl`、`read_clock_activity.tcl` 與 `read_wb_timeseries_session.tcl`，不寫入 WR 設定。

## Observation

待補入實測結果。

## Conclusion

待補入；只能根據 A/B 的實際燒錄與 runtime 證據判斷。

## Next Step

若歷史 SOF 恢復 Master 判準，固定該映像並回到 Slave；若仍為 MODE=3，優先查 runtime/board/JTAG mapping，而不是修改 Master role。
