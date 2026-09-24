# EXP-REPRO-BUILD-TIMING-20260815

## 目標

在 Quartus build wrapper 加入可重現性 metadata 欄位後，確認最終建置身份並收集 timing 證據。

## 變更

本實驗只變更建置與文件。WR 功能原始碼、pre-emphasis、QSFP lane、clock constraint、Master/Slave role 與 probe mapping 都沒有變更。

## 建置證據

- Git commit：`0a8f44afa5b26111a1103903968bf173e210ee92`
- 主機：`pain`
- Quartus：Prime 17.0 Build 595
- Master 韌體：PASS
- Slave 韌體：PASS
- Master Quartus：`Full Compilation was successful`，0 errors
- Slave Quartus：`Full Compilation was successful`，0 errors
- Master SOF：`9a779de65eb0df89de28194e869bbda99b26ba6603ec4af2c539f8e805248d1b`
- Slave SOF：`1849a8a1a446df738be2b6b258c387bc6141d5c8b9f1ea9d2d199b98c5a002a5`

## Timing 證據

| Revision | Setup | Hold | Recovery | Removal | Timing closed |
|---|---:|---:|---:|---:|---|
| Master | -3.812 ns | 0.039 ns | -1.975 ns | 0.298 ns | NO |
| Slave | -3.103 ns | 0.030 ns | -1.839 ns | 0.326 ns | NO |

負值 setup 與 recovery slack 被記錄為既有技術條件，不會被默認改判為 timing closure 成功。

## 結論

目前的建置流程會產生足夠的身份資料，可以將 SOF 追溯回 Git commit、MIF、QSF、SDC、Quartus 版本與 timing report。本實驗不宣稱新 bitstream 已燒錄，也不宣稱 WR 時間同步已完成。
