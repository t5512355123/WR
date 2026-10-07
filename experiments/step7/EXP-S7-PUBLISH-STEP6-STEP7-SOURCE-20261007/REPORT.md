# Step6／Step7：發布可直接編譯的 source/（2026-10-07）

依使用者要求，在 `step7-physical-measurement` 分支提交兩份完整展開的原始碼：

- `artifacts/milestones/step6_global_time/source/`：3,564 個檔案。
- `artifacts/milestones/step7_physical_measurement/source/`：3,615 個檔案。

本機逐檔位元組比對兩份既有 `source.tar.gz` 均通過。
不是把 Step7 控制程式覆蓋到 Step6；不改壓縮封存、頂層 SOF 或既有驗證紀錄。
兩份 source 不含巢狀 `.git/`，由外層 WR Git repository 追蹤。
初始發布也包含封存的 firmware、build/output 產物、腳本、dashboard 及實驗紀錄，
沒有只放一個空 source 或下載／解包指令。

## 可編譯工作區與唯讀封存的區別

頂層 milestone 封存檔維持唯讀；新 `source/` 為可寫建置工作區。
建置時會更新 source 內的 build/output/log，不修改頂層 master.sof／slave.sof。
更新操作說明放在各 milestone 新增的 SOURCE_USAGE.md，既有封存 README 不改動。
舊 prepare_source／seal 腳本的操作限制，不適用於這次新增加的 Git-tracked source。

腳本沿用各自封存原版，沒有変更 PI、bootstrap、servo 或 RTL。
Step6 的歷史腳本保留原來的檢查；Step7 保留 editable 操作政策。
本次只有展開、比對、發布、路徑／腳本檢查及權限設定；
未實際重新 firmware build／Quartus compile、燒錄、重置、斷電或 JTAG 觀測。
因此沒有追加硬體 PASS 或 TIME_VALID 300 秒驗收。

## Pain 舊 Step6 工作區的保護

Pain 原有 Step6 source 含獨立 Git 與額外 program logs，不能直接覆寫。
已完整搬移保存至：

`/home/b10504072/04_WR_milestone_source_backup.DSt2mp/step6_source`

備份保留舊 Git 歷史、原始碼、產物與未追蹤的操作紀錄；未刪除。
原位置改放本次 GitHub 追蹤的 source。
其他使用者未追蹤檔案保留；不動 `/home/b10504072/04_WR_archive_step6_pass/`。

## 操作

Step7（Step6 請替換第一行的 milestone 名稱）：

```sh
cd /home/b10504072/04_WR/artifacts/milestones/step7_physical_measurement/source
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

編譯輸出為各自 source 下的 `output/DE5a_wr_master_jtag.sof` 與
`output/DE5a_wr_slave_jtag.sof`；不要將它們誤認為 milestone 頂層原始封存 SOF。
不需要重新執行 prepare_source，也不需要建立嵌套 Git。
