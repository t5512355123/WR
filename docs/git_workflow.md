# Git 工作流程

## 正式原始碼來源

Laptop repository 是主要的編輯 checkout：

`C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_WR`

GitHub repository 是 Laptop 與 pain 共用的版本傳輸端點：

`git@github.com:t5512355123/WR.git`

pain 的工作 clone 用於 Quartus 17 與韌體建置：

`/home/b10504072/04_WR`

舊專案與歷史建置資料已移至 `/home/b10504072/04_White_Rabbit_backups/` 保存，不是正式原始碼 checkout。SOF、MIF 與建置證據則保留在 pain `/home/b10504072/04_WR/artifacts/`。

## 分支規則

- `main` 包含已知可用的基準版本與可重現性變更。
- 每個功能性研究使用 `exp/<short-name>`。
- 不要建立 `final`、`final2` 或 `new` 這類含義不清的分支。
- 功能性實驗在記錄 artifact metadata、建置 log、SOF/MIF hash 與執行期證據前，不得合併到 `main`。

## 一般變更流程

1. 從乾淨的本機 `main` 或明確命名的實驗分支開始。
2. 進行一項範圍清楚的變更，並在 `docs/experiments/` 記錄原因。
3. 使用 repository script 在 pain 建置韌體與 Quartus project。
4. 將輸出收集到新的 `artifacts/EXP-<id>/` 資料夾。
5. 燒錄板卡前，記錄精確 Git commit、QSF/SDC/MIF/SOF hash、Quartus 版本與執行期結果。
6. 將 commit push 到 GitHub，再讓 pain clone fast-forward 到相同 commit。
7. 只燒錄實驗紀錄指定的 SOF。舊 SOF 與 log 保留在原本的 artifact 資料夾。

## 建置身份

Quartus build wrapper 會寫入 `build/build_info_master.txt` 與
`build/build_info_slave.txt`。這些檔案將 SOF 對應到 Git commit、branch、top-level source、QPF/QSF/SDC、韌體 MIF、Quartus 版本、Fitter 結果、timing slack 與 unconstrained-path 數量。

`Full Compilation was successful` 只代表 compiler 完成，不代表 timing closure、White Rabbit link-up 或時間同步成功。

## 復原規則

如果實驗失敗，請停止實驗、保留 terminal output 與 artifact 資料夾，並回到先前記錄的已知可用 commit 與 SOF。不要覆寫之前的實驗資料夾。
