# White Rabbit 專案遷移計畫

產生時間：2026-08-15
範圍：僅涵蓋 Phase 0-3。沒有移動、刪除、合併或覆寫任何 source tree。

## 1. 安全備份證據

Laptop 備份：
- C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_White_Rabbit_backups\de5a_wr_pre_restructure_20260815_214635.zip
- SHA256: 23ACB94353A238CADE38723848E360FBE6B28EA3864B8621C43288B86059D2A2
- 包含當時的 Laptop snapshot，位置在 project root 外部。

pain 備份：
- /home/b10504072/04_White_Rabbit_backups/de5a_wr_pre_restructure_20260815_2147.tar.gz
- SHA256: aa84661a8765020b892fb8f0e33113ac8fcd728bea2b721bc7775d1b41048a2e
- 包含 `/home/b10504072/04_White_Rabbit`，只排除可重新產生的 db/、incremental_db/ 與 simulation/ 資料夾。
- SOF、MIF、Quartus report、編譯 log、原始碼、vendor、韌體、除錯資料夾與實驗紀錄均已保留。

## 2. Inventory 證據

Laptop root：
- C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_White_Rabbit
- 106 selected files in the final manifest, 2,916,088 selected bytes.
- 當時找不到 Git repository。

pain root:
- /home/b10504072/04_White_Rabbit
- 4,196 selected files in the final manifest, 2,551,225,021 selected bytes.
- 完整 root 約為 4.6G。
- 當時找不到 Git repository。
- 大型產生資料夾保留原位，沒有刪除。

詳細證據：
- 01_laptop_inventory.md and laptop_manifest.tsv
- 02_pain_inventory.md and pain_manifest.tsv

## 3. 精確相對路徑比較

- SHA256 相同：59
- 相對路徑相同但 SHA256 不同：9
- 只有 Laptop：38
- 只有 pain：4,128

詳細證據：
- comparison.tsv
- 03_version_comparison.md

重要觀察：
- week02/v01/DE5a_wr_master.vhd：精確 SHA256 相同。
- week02/v01/DE5a_wr_slave.vhd：精確 SHA256 相同。
- week02/v01/DE5a_wr_master.sdc：精確 SHA256 相同。
- week02/v01/DE5a_wr_slave.sdc：精確 SHA256 相同。
- week02/v01/DE5a_wr_master.qsf：差異只在找到的 LAST_QUARTUS_VERSION assignment。
- week02/v01/DE5a_wr_slave.qsf：差異只在找到的 LAST_QUARTUS_VERSION assignment。
- Laptop 沒有完整的 pain 端 vendor/wrpc-sw tree、韌體 MIF set、RS422 基準 project 或 pain 端 Quartus output artifact。

## 4. 目前已知可用的基準候選版本

目前板卡恢復的基準版本是 pain 端 rs422_uart_diag build，因為最近一次已驗證的燒錄操作使用了以下輸入：

Master：
- Source top：/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_master_rs422.vhd
- QSF：/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_master_rs422.qsf
- SDC：/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_master_rs422.sdc
- SOF：/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/output_files_master_rs422/DE5a_wr_master_rs422.sof
- Quartus programmer checksum：0x3088011E

Slave：
- Source top：/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_slave_rs422.vhd
- QSF：/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_slave_rs422.qsf
- SDC：/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_slave_rs422.sdc
- SOF：/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/output_files_slave_rs422/DE5a_wr_slave_rs422.sof
- Quartus programmer checksum：0x308FFC95

韌體 MIF：
- /home/b10504072/04_White_Rabbit/week02/v01/firmware/wrc_de5a_master.mif
- SHA256: 0d7e79f0a33d82b5afaf850e19c169bb88ea479a58029f9c19b60de561ccb5f2
- /home/b10504072/04_White_Rabbit/week02/v01/firmware/wrc_de5a_slave.mif
- SHA256: 9a9c23628ef235c6cb24376c039120bf06b2dac5d213374fc591e6f5992d1c19

基準版本證據：
- Master 與 Slave 燒錄都回報 Configuration succeeded。
- 先前的完整 Quartus log 回報 0 errors。
- 恢復後的板卡檢查在兩片板上都保留 low16 probe 0x82CF：link_up=1、link_ok=1，沒有 RX/TX encoding error。
- 此基準版本已知可用於 FPGA 設定與 PHY/PCS link，但尚未證明 White Rabbit 時間同步。time_valid、pps_valid、SoftPLL lock、TRACK_PHASE 與次奈秒 PPS alignment 仍未證明。

這是暫定的基準候選版本，當時尚未成為 Git main commit。

## 5. Source/generated/artifact 分類

正式原始碼候選：
- Top-level VHDL/Verilog、QPF/QSF/SDC、TCL、shell/Python script、韌體原始碼/設定、wr-cores 與 wrpc-sw 原始碼。

產生檔案：
- db/, incremental_db/, simulation/, Quartus temporary database files.
- 除非是編譯所需的精確 Quartus 產生輸入，否則應保留在 Git 外部。

里程碑 artifact：
- SOF、MIF、map/fitter/STA report、編譯 log、probe log 與 metadata。
- 這些檔案應由受控的 collection script 複製到 artifacts/EXP-XXX 資料夾，不要手動散落保存。

歷史實驗：
- jtag_wb_diag、clock625_jtagwb_diag、simplewa、DCO、SFP I2C、runtime probe、loadprobe、RS422、nosfpmatch、staging 與相關除錯資料夾。
- 先保留；不要自動刪除或合併。

## 6. 衝突與尚未決定事項

1. 當時兩台機器都沒有 Git repository，因此沒有 commit、branch 或正式原始碼身份。
2. Laptop 與 pain 的結構不同，Laptop snapshot 無法重現 pain 當時的 build。
3. root QSF 的差異只有 LAST_QUARTUS_VERSION metadata，但這不能證明所有除錯 QSF 都等價。
4. pain 包含多個世代的韌體 MIF 與除錯 SOF；正確的韌體/原始碼配對必須依照實驗紀錄與編譯 log 選擇，不能依 mtime 判斷。
5. pain 端 vendor 與 wrpc-sw tree 是必要的 build input，Laptop snapshot 中缺少或不完整。
6. 目前板卡基準是 pain 端 artifact；只有在將原始碼、MIF、QSF、SDC、report 與 probe 證據成套整理後，才能放入新的 Git repository。
7. 時間同步仍是技術瓶頸，但本遷移階段不得變更 WR algorithm、PHY、PTP、SoftPLL、DMTD、port、lane、pre-emphasis、role 或 PPS 行為。

## 7. 已建立 staging repository

非破壞性的 staging repository 位於：

- Laptop: `C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_WR`
- pain working snapshot: `/home/b10504072/04_WR`
- initial baseline commit: `47e705cb2d3a1ecb031962426240d911399ac44d`

這個 commit 包含正式 Quartus source path、vendored WR source、韌體設定、遷移證據、實驗模板、script，以及指定的基準 MIF/SOF/probe 紀錄。原始專案與兩份重整前封存均未變更。

## 8. 審查後的後續階段建議

Phase 4：
- 在獨立 staging location 建立新的正式原始碼 repository（已完成；目前 Laptop 資料夾是 `04_WR`）。
- 在基準 snapshot 複製並驗證前，不要在既有 project root 初始化 Git。

Phase 5：
- 將 pain 端基準原始碼與必要的 vendor/韌體輸入複製到 staging repository。
- 在 migration manifest 保留原始路徑與 hash。

Phase 6：
- 新增可重現的 Master/Slave 韌體建置 script，並在 Quartus compile 前驗證精確的 MIF SHA256。

Phase 7：
- 新增固定的 Quartus 17 build script；缺少 MIF 時必須失敗，並收集 compile、Fitter 與 TimeQuest identity。

Phase 8：
- 新增實驗模板與 artifact collection script。
- 每個除錯版本完成有證據支持的分類前，先保留在 legacy/archive。

Phase 9：
- 將精確 commit clone 到 pain，在不直接修改原始碼的情況下建置，並將功能輸入與 report 和基準版本比較。

Phase 10：
- 在判定遷移完成前，執行 clean-checkout 可重現性驗證。

## 8. 明確的安全決策

在遷移計畫完成審查前，不要刪除、更名、合併或覆寫任何現有 Laptop 或 pain 專案。目前證據支持將 pain 基準版本複製到新的 staging repository，不支持用 Laptop snapshot 取代 pain 專案。
