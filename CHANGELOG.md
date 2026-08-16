# 變更紀錄

## 2026-08-16

- 將 Laptop 與 pain 的正式原始碼資料夾從 `de5a-white-rabbit` 更名為 `04_WR`。
- 將歷史專案資料夾保留為 `04_White_Rabbit`；舊 bare Git repository 與正式建置 clone 保留其原本的操作名稱。
- 更新目前的工作流程與追溯文件，同時保留原始 inventory snapshot 與歷史實驗路徑。

## 2026-08-15

- 建立非破壞性的 `de5a-white-rabbit` staging repository。
- 匯入 pain 端 RS422 基準原始碼、vendor tree、韌體設定與里程碑 artifact。
- 新增遷移 inventory、追溯文件、建置身份 script 與實驗模板。
- 沒有修改 WR algorithm、PHY、PTP、SoftPLL、DMTD、QSFP port、lane、pre-emphasis、role 或 PPS 行為。
# 2026-08-15

- 建立非破壞性的 `de5a-white-rabbit` 正式原始碼 repository。
- 保留舊 Laptop 與 pain 專案、vendor Git provenance、RS422 基準 SOF/MIF/probe 證據與遷移 manifest。
- 新增 Quartus 17、韌體、燒錄、JTAG 與 artifact collection script。
- 在 pain 驗證 Master/Slave 韌體與完整 Quartus 編譯均為 0 errors，並記錄為 `EXP-REPRO-BUILD-20260815`。
- 驗證乾淨的 pain checkout，並記錄 WRPC 建置時間戳的影響。
