# Step7：GitHub 已包含可直接編譯的 source/

`source/` 為本 milestone 既有 `source.tar.gz` 的完整逐檔展開，
保留當時的程式、scripts、dashboard、韌體、SOF 與觀測紀錄。
頂層唯讀封存檔、SHA256SUMS、PACKAGE.json 均不改動。

此頁是新增的操作方式，取代頂層 README 中「只能解到外部工作目錄」的限制。
**只有 `source/` 是可寫建置工作區，頂層封存仍唯讀。**
不需要再解壓，也不用建立巢狀 `.git/`。

```sh
cd /home/b10504072/04_WR/artifacts/milestones/step7_physical_measurement/source
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

前一步成功後才繼續。若只要使用既有 MIF 重新 compile，可單獨執行第二步。
新 SOF 存放於此 `source/output/DE5a_wr_master_jtag.sof` 與
`source/output/DE5a_wr_slave_jtag.sof`，不改 milestone 頂層的 `master.sof`／`slave.sof`。
燒錄前停止其他 JTAG reader；建置／編譯需要 Pain 的 RISC-V 工具鏈與 Quartus 17.0。

不要在此 source 執行封存／重封腳本；尤其舊 `seal_read_only.sh` 會遞迴把 source
一起設唯讀，不適用於這次新增的可編譯工作區。應改從外層 repo 執行：

```sh
cd /home/b10504072/04_WR
bash scripts/milestones/set_published_source_permissions.sh
```

該命令保護 Step6/Step7 頂層封存檔，保留兩份 source 的寫入權限，
不修改其他 milestones 或受保護 archive。
發布 source 不代表新的實體精度或 TIME_VALID 300 秒 PASS；本次沒有燒錄或硬體觀測。
