# 實驗紀錄索引（重整前歷史快照）

本文件保存 repository restructuring 前的實驗索引與當時的 Step5/Step6 分類。它是歷史快照，不取代目前根目錄的 [`experiments/README.md`](../README.md)、`STATUS.md` 或 `MILESTONES.md`。連結依現行 `experiments/` 分類更新；原始實驗報告內容不改寫。

## Step5 當時的 milestone policy

當時 Step5 functional PASS 必須在同一可信、有效 WR session 的連續至少 300 秒觀測窗，同時觀察 HPLL/Helper lock、Main frequency lock、Main phase lock 與 `PSTAT.locked=1`。Quartus timing closure 不屬於這個 functional milestone 的必要條件，仍獨立記錄。

當時 milestone 與 exact provenance 見 [`exp-step5-softpll-lock/STEP5-PASS-MILESTONE.md`](exp-step5-softpll-lock/STEP5-PASS-MILESTONE.md)。

## Step6 當時的 functional milestone

當時 Step6A Global-Time validity/same-PPS consistency 與 Step6B 內部雙板排程觸發已通過數位功能 gate；記錄的最新 run 在兩板相同 `(TAI=1133, cycles=62500000)` 觸發，並有 3 組健康 post-fire samples。這是 8 ns resolution 內部時間標籤一致，不是外部 output-pin skew 的實體量測；該項仍為 `NOT_EVALUATED`。歷史證據見 [`../step6/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md`](../step6/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md) 與 [`../step6/STEP6-PASS-MILESTONE.md`](../step6/STEP6-PASS-MILESTONE.md)。

Step4 D0 mismatch 早期原始證據曾從 Pain 備份去重並歸檔；被排除的中間 SOF/MIF 僅保留雜湊與 provenance，不作為 milestone PASS 證據。詳見 [`exp-step4-softpll-enable/EXP-WRPC-STEP4-D0-MISMATCH-HISTORICAL-ARCHIVE-20260823-24.md`](exp-step4-softpll-enable/EXP-WRPC-STEP4-D0-MISMATCH-HISTORICAL-ARCHIVE-20260823-24.md)。

Pain 舊 checkout 的 Step5/Step6 pre-pull 保全資料已整併至下列歷史 provenance 封存目錄；這些封存檔只保存原始紀錄與 hash，不新增 milestone PASS：

- [`EXP-S5-PRE-PULL-PROVENANCE-ARCHIVE-20260917`](exp-step5-softpll-lock/EXP-S5-PRE-PULL-PROVENANCE-ARCHIVE-20260917/REPORT.md)
- [`EXP-S6-PRE-PULL-PROVENANCE-ARCHIVE-20260922`](../step6/EXP-S6-PRE-PULL-PROVENANCE-ARCHIVE-20260922/REPORT.md)

2026-09-24 Pain home-directory archive de-duplication recovered nine previously untracked unique records and identified 272 exact content duplicates already tracked in Git. Supplemental captures were kept separate from canonical records where their bytes differ. Cleanup scope and per-file hashes are recorded in [`EXP-PAIN-HOME-ARCHIVE-DEDUP-20260924`](EXP-PAIN-HOME-ARCHIVE-DEDUP-20260924/REPORT.md); milestone SOF/MIF files were not part of that cleanup.

Pain's older Step5 checkout also contained frozen-fit source snapshots and observer scripts absent from the tracked archive. Byte-identical duplicates were deduplicated and the source/observer files were preserved with hashes in [`EXP-S5-FROZEN-FIT-SOURCE-OBSERVER-ARCHIVE-20260924`](exp-step5-softpll-lock/EXP-S5-FROZEN-FIT-SOURCE-OBSERVER-ARCHIVE-20260924/REPORT.md).

## 當時的實驗資料夾規則

- `main/`：穩定 baseline 與未標示研究 branch 的歷史建置紀錄。
- `exp-jtag-runtime-observability/`：JTAG runtime observability 研究線。
- `exp-master-9f-observability/`：以 `9f848ec` Master baseline 為基礎的 observability 研究線。
- `exp-restore-c88cc05-baseline/`：恢復 `c88cc05` clean SOF 與驗證 parent signaling 的研究線。
- `exp-<研究名稱>/`：其他 `exp/<研究名稱>` branch 的紀錄。
- `EXP-XXX_TEMPLATE.md`：新實驗模板，不屬於任何 branch。

當時使用 `scripts/experiment/create_experiment.sh EXP-你的識別碼` 建立紀錄時，腳本會依目前 branch 自動選擇資料夾。若只 compile 而未燒錄，應明確記錄為 compile-only；燒錄後則補上 programmer log 與 JTAG/runtime 結果，不把 compile 成功寫成硬體實驗成功。
