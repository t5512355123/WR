# Step6：GitHub 已包含可直接編譯的 source/

`source/` 為本 milestone 既有 `source.tar.gz` 的完整逐檔展開，
不是拿最新 Step7 程式替換 Step6。原始封存、SOF、驗證紀錄不變。
source 由外層 WR Git repository 追蹤，不包含巢狀 `.git/`。

在 Pain 直接進入已下載的 source，依序執行：

```sh
cd /home/b10504072/04_WR/artifacts/milestones/step6_global_time/source
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

前一步成功後才繼續。只要重新編譯 FPGA 而不重建韌體，可單獨執行第二步，
它會使用 `build/firmware/` 內既有的封存 MIF。
編譯成功的新 SOF 位於此 `source/output/DE5a_wr_master_jtag.sof` 與
`source/output/DE5a_wr_slave_jtag.sof`，不覆寫 milestone 頂層的封存 SOF。

此工作目錄可寫；頂層封存檔仍唯讀。不要再次執行舊 `prepare_source.sh`，
那是壓縮封存的舊準備流程，會建立巢狀 Git，不適用於現在已提交的 source/。
此處保留歷史 Step6 腳本及其原有檢查，未把 Step7 控制或腳本替換進來。
需要 Pain 的既有 RISC-V 工具鏈與 Quartus 17.0。
發布 source 不等於重新完成硬體／300 秒驗證；本次沒有建置、燒錄或 JTAG 觀測。

不要在 `source/` 執行任何頂層 milestone 重封／封存腳本。
新 clone 的權限需要設定時，從外層 repo 執行
`bash scripts/milestones/set_published_source_permissions.sh`。
