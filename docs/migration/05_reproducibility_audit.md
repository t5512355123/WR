# 可重現性稽核

## 正式原始碼來源

- Laptop repository：`C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_WR`
- GitHub repository：`git@github.com:t5512355123/WR.git`
- pain working clone：`/home/b10504072/04_WR`
- 初始 migration-audit commit：`2fb75aafe0e2c03c6a20bab8d5a14ccddb7d4f6a`
- 最終稽核時的本機與 pain working tree：clean

## 建置證據

正式的 pain clone 產生了兩份韌體 image 與兩份 Quartus SOF。Quartus Prime 17.0 Build 595 對 Master 與 Slave 都回報 `Full Compilation was successful` 且 0 errors。完整 log 與 report 位於 pain `/home/b10504072/04_WR/artifacts/EXP-REPRO-BUILD-20260815/`。

記錄建置產生的 image hash 如下：

| Image | SHA256 |
|---|---|
| Master MIF | `a664396b3d908d43d0810fa85f76dd2437dde10b1f8c3ed97514ecb304f8e29c` |
| Slave MIF | `fca9e4aebfdf49674de2af31824f2d19bb422d305fcc2a0808495f515ccb7ade` |
| Master SOF | `ea66406592d0734e7547d60ab88d6416c86bc4ef4fdfa4e4e90a330c19de1214` |
| Slave SOF | `19fac5b4fe9d2c867f052683adb31b2d266900a52fe185b78330b15318ba8b21` |

後續的 build-identity 與 timing-wrapper 驗證記錄在 pain
`/home/b10504072/04_WR/artifacts/EXP-REPRO-BUILD-TIMING-20260815/`，commit 為
`0a8f44afa5b26111a1103903968bf173e210ee92`。其中的 `build_info_master.txt` 與
`build_info_slave.txt` 包含 Quartus 版本、SOF hash、Fitter 狀態、timing slack 與 unconstrained-path 數量。

本文件屬於後續 repository history；最終 repository commit 記錄在 `STATUS.md` 與 Git log。上方的 artifact build commit 仍是產生這些 SOF 的精確原始碼身份。

## Timing 解讀

Compile success 不等於 timing closure。記錄的 TimeQuest report 如下：

| Revision | Worst setup | Worst hold | Worst recovery | Worst removal | Unconstrained clocks | Input paths | Output paths | Timing closed |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Master | -3.812 ns | 0.039 ns | -1.975 ns | 0.298 ns | 3 | 1992 | 83 | NO |
| Slave | -3.103 ns | 0.030 ns | -1.839 ns | 0.326 ns | 3 | 2001 | 83 | NO |

這些是保留設計的觀察結果，不是本次遷移任務修改 WR 功能的理由。Timing closure 仍應作為獨立的技術調查。

## 乾淨 checkout

從最新 commit 的 GitHub clone，Master 與 Slave 韌體以及 Quartus 編譯都完成。另一份精確 artifact build commit 的乾淨 checkout 也重新建置了兩份韌體。WRPC 原始碼會嵌入 `__DATE__` 與 `__TIME__`，因此即使功能性原始碼不變，不同次執行也預期會得到不同 image hash。

## 功能基準比較

路徑變更僅限於新的 repository layout 與固定 MIF 位置。保留的 probe mapping、QSFP-A lane 0 選擇、clock period、Master/Slave role 與 pre-emphasis 設定都沒有變更。
