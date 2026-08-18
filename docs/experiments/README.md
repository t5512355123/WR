# 實驗紀錄索引

每個實驗都要有一份 Markdown 紀錄與一個 artifact 資料夾。紀錄必須填入精確的 Git commit、branch、原始碼、韌體、Quartus 參數、SOF/MIF hash、燒錄結果、JTAG 原始輸出與證據支持的結論。

## 資料夾規則

- `main/`：穩定 baseline 與未標示研究 branch 的歷史建置紀錄。
- `exp-jtag-runtime-observability/`：JTAG runtime observability（執行期可觀測性）研究線。
- `exp-master-9f-observability/`：以 `9f848ec` Master baseline 為基礎的 observability 研究線。
- `exp-<研究名稱>/`：其他 `exp/<研究名稱>` branch 的紀錄。
- `EXP-XXX_TEMPLATE.md`：新實驗模板，不屬於任何 branch。

使用 `scripts/experiment/create_experiment.sh EXP-你的識別碼` 建立紀錄時，腳本會依目前 branch 自動選擇資料夾。若只 compile 而未燒錄，必須明確記錄為 compile-only；燒錄後則要立即補上 programmer log 與 JTAG/runtime 結果，不可把 compile 成功寫成硬體實驗成功。

`legacy_實驗紀錄.md` 是早期歷史文件，保留在 `main/`，不改寫內容。
