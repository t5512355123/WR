# EXP-WRPC-STEP2-DCO-RESTORE-20260819

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP2-DCO-RESTORE-20260819`
- 日期：2026-08-19（Asia/Taipei）
- Git branch：`exp/restore-c88cc05-baseline`
- 功能修改 commit：`a427ed3f61a54a704c46cf1e0f650ef591f35de1`
- 實驗狀態：待 fresh firmware、clean Quartus、雙板燒錄與 JTAG 驗證

## 實驗名稱

`恢復已驗證 DCO 單週期請求握手，重新建立 Step 2 fresh HEAD 候選`

## 這次想驗證什麼

確認最新 HEAD 在不改變 Master/Slave role 命令、PHY、Simple Word Alignment、WR clock/reset、PPSI/PTP 或 SoftPLL 演算法的前提下，能否重現 Step 2：

- Master：`MODE=2`、`PTP=6 (PPS_MASTER)`。
- Slave：`MODE=3`、`PTP=9 (PPS_SLAVE)`。
- 兩片 CPU marker=`B004`、`fault=0`、PHY/link 健康、MiniNIC 與 PPSI PTP RX/TX 持續增加。
- Slave 建立 foreign master，且以 source-defined mapping 解碼為 `foreign_count=1`、`best_index=0`。

這一輪不要求 `time_valid=1`、`PSTAT.locked=1` 或 SoftPLL closed loop；那些屬於後續 Step 3～5。

## 相較前一個 fresh HEAD baseline 的唯一修改

只修改：`quartus/jtag_runtime_diag/si5340a_controller_dco.v`。

- 移除 `runtime_start_hold` 對 `bus_start` 的額外保持。
- 恢復已驗證 baseline 的單週期 `bus_start = static_start_pulse || runtime_start`。
- 保留 DCO 唯讀 debug probe；bit 52 固定為 0，避免既有 JTAG decoder 失配。

沒有修改：

- Master/Slave startup role command。
- `g_use_simple_wa => true`。
- unique MAC。
- WR signaling、PTP、servo、SoftPLL 演算法、PI、lock threshold、DDMTD polarity。
- PHY、QSFP、SI5340 register algorithm；本輪只是恢復既有 runtime request handshake。

## 來源與建置規劃

本輪必須由 exact commit `a427ed3` 之後的最新 branch HEAD，在 pain 隔離 checkout 重新完成：

1. firmware fresh build，重新產生 Master/Slave MIF。
2. Quartus 17 clean compile，重新產生 Master/Slave SOF。
3. 只燒錄這次 fresh build 的 SOF，不使用 historical `c88cc05` SOF。
4. programming 後立即保存完整 programmer output。
5. 等待 30～60 秒後執行 JTAG snapshot 與 time-series。

以下欄位待建置後補入：

- build HEAD、Master/Slave MIF SHA-256。
- Master/Slave QSF、SDC SHA-256。
- Master/Slave SOF SHA-256。
- Quartus version、compile log 與 timing 結果。
- programmer checksum 與原始 programming log。
- JTAG snapshot、30～60 秒 time-series 原始檔與 SHA-256。

## 目前結論

尚未燒錄，因此目前只能說 source-level recovery candidate 已建立，不能宣稱 compile、programming 或 Step 2 通過。

## Next Step

在 pain 的 `/home/b10504072/04_WR_step2_head` 以 exact commit 建置，完成 clean compile、雙板 programming，並依 Step 2 acceptance gates 記錄結果。若 role 或 foreign master 仍失敗，保留本次失敗證據，不再擴大修改範圍。
