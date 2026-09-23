# 實驗紀錄索引

## Step5 目前 milestone policy

目前 Step5 functional PASS 必須在同一可信、有效 WR session 的連續至少 300 秒
觀測窗同時觀察到以下四項：HPLL/Helper lock、Main frequency lock、Main phase
lock、`PSTAT.locked=1`。Quartus timing closure 不再是宣稱這個 functional
milestone 的必要條件，但仍須如實記錄為獨立的 implementation status。

目前 milestone 與 exact provenance 見
[`exp-step5-softpll-lock/STEP5-PASS-MILESTONE.md`](exp-step5-softpll-lock/STEP5-PASS-MILESTONE.md)。

目前已達成的 300 秒 milestone 是
[`EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/REPORT.md`](exp-step5-softpll-lock/EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/REPORT.md)。
該報告保留四項 lock 的逐週期統計、raw checksum 與 F4L page-accounting
caveat；timing closure 仍獨立追蹤，不會回寫成這個 functional gate 的必要條件。

## Step6 目前 functional milestone

Step6A Global-Time validity/same-PPS consistency 與 Step6B 內部雙板排程觸發
已通過數位功能 gate。最新 run 在兩板相同 `(TAI=1133, cycles=62500000)`
記錄到一次 fire，並有 3 組健康 post-fire samples。這是 8 ns resolution
內部時間標籤一致，不是外部 output-pin skew 的實體量測；該項仍為
`NOT_EVALUATED`。完整證據見
[`exp-step6-global-time/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md`](exp-step6-global-time/EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923/REPORT.md)
與 [`exp-step6-global-time/STEP6-PASS-MILESTONE.md`](exp-step6-global-time/STEP6-PASS-MILESTONE.md)。

Step4 D0 mismatch 早期原始證據已從 Pain 備份去重並歸檔；被排除的中間 SOF/MIF
僅保留雜湊與 provenance，不作為任何 milestone PASS 證據。詳見
[`EXP-WRPC-STEP4-D0-MISMATCH-HISTORICAL-ARCHIVE-20260823-24.md`](exp-step4-softpll-enable/EXP-WRPC-STEP4-D0-MISMATCH-HISTORICAL-ARCHIVE-20260823-24.md)。

Pain 舊 checkout 的 Step5/Step6 pre-pull 保全資料已整併到下列歷史 provenance 封存目錄；這些封存檔只保存原始紀錄與 hash，不新增 milestone PASS：

- [`EXP-S5-PRE-PULL-PROVENANCE-ARCHIVE-20260917`](exp-step5-softpll-lock/EXP-S5-PRE-PULL-PROVENANCE-ARCHIVE-20260917/REPORT.md)
- [`EXP-S6-PRE-PULL-PROVENANCE-ARCHIVE-20260922`](exp-step6-global-time/EXP-S6-PRE-PULL-PROVENANCE-ARCHIVE-20260922/REPORT.md)

2026-09-24 Pain home-directory archive de-duplication recovered nine
previously untracked unique records and identified 272 exact content
duplicates already tracked in Git. Supplemental captures were kept separate
from canonical records where their bytes differ. Cleanup scope and per-file
hashes are recorded in
[`EXP-PAIN-HOME-ARCHIVE-DEDUP-20260924`](EXP-PAIN-HOME-ARCHIVE-DEDUP-20260924/REPORT.md);
milestone SOF/MIF files were not part of this cleanup.

Pain's older Step5 checkout also contained frozen-fit source snapshots and
observer scripts absent from the tracked archive. Byte-identical duplicates
were deduplicated and the source/observer files were preserved with hashes in
[`EXP-S5-FROZEN-FIT-SOURCE-OBSERVER-ARCHIVE-20260924`](exp-step5-softpll-lock/EXP-S5-FROZEN-FIT-SOURCE-OBSERVER-ARCHIVE-20260924/REPORT.md).

每個實驗都要有一份 Markdown 紀錄與一個 artifact 資料夾。紀錄必須填入精確的 Git commit、branch、原始碼、韌體、Quartus 參數、SOF/MIF hash、燒錄結果、JTAG 原始輸出與證據支持的結論。

## 資料夾規則

- `main/`：穩定 baseline 與未標示研究 branch 的歷史建置紀錄。
- `exp-jtag-runtime-observability/`：JTAG runtime observability（執行期可觀測性）研究線。
- `exp-master-9f-observability/`：以 `9f848ec` Master baseline 為基礎的 observability 研究線。
- `exp-restore-c88cc05-baseline/`：恢復 `c88cc05` clean SOF 與驗證 parent signaling 的研究線。
- `exp-<研究名稱>/`：其他 `exp/<研究名稱>` branch 的紀錄。
- `EXP-XXX_TEMPLATE.md`：新實驗模板，不屬於任何 branch。

使用 `scripts/experiment/create_experiment.sh EXP-你的識別碼` 建立紀錄時，腳本會依目前 branch 自動選擇資料夾。若只 compile 而未燒錄，必須明確記錄為 compile-only；燒錄後則要立即補上 programmer log 與 JTAG/runtime 結果，不可把 compile 成功寫成硬體實驗成功。

`legacy_實驗紀錄.md` 是早期歷史文件，保留在 `main/`，不改寫內容。
