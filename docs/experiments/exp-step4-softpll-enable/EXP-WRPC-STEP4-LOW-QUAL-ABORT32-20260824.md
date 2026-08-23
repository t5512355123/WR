# EXP-WRPC-STEP4-LOW-QUAL-ABORT32-20260824

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP4-LOW-QUAL-ABORT32-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- 診斷 source commit：`126dda8550db3f8de33c9e37303e4a16aa730350`
- 狀態：等待 pain fresh build、雙板燒錄與實機量測

## 想驗證什麼

上一輪已確認 Slave REF/FB 的 sampled transition 持續增加，但 deglitch FSM 停在
`WAIT_STABLE_0`，`WAIT_EDGE_ENTRY` 在 T0/T1 視窗皆沒有增加。本輪只回答：

> LOW qualification 是否已開始累積，卻在達到 threshold 前反覆被 HIGH sample 中斷？

## 相較上一輪的唯一修改

- 保留既有 LOW qualification abort 條件不變：
  `state = WAIT_STABLE_0 && stab_cntr != 0 && clk_sampled != 0`。
- 將既有 LOW qualification abort 診斷計數器由 16-bit 擴成 32-bit。
- 透過唯讀 JTAG alias 分別讀回 REF/FB 完整計數器：
  - `0x00100250`：REF LOW qualification abort count
  - `0x00100254`：FB LOW qualification abort count
- 保留 `WAIT_EDGE_ENTRY`、accept 與 downstream event 計數器，以便同一視窗比較。

本輪沒有修改 WR role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、
lock threshold、DCO、SI5340、PHY functional RTL 或 WRPC firmware functional behavior。

## Build 與 Artifact Provenance

尚待填寫：

- Quartus version：
- Master MIF SHA256：
- Slave MIF SHA256：
- Master QSF SHA256：
- Slave QSF SHA256：
- SDC SHA256：
- Master SOF SHA256：
- Slave SOF SHA256：
- Master timing summary：
- Slave timing summary：

## 燒錄結果

尚未燒錄。完成後必須記錄兩片板卡的 programmer checksum、configuration 結果與錯誤數。

## JTAG / Runtime 原始結果

尚待執行：

1. Step 1～3 focused regression barrier。
2. Step 4 T0：10 samples × 500 ms。
3. 等待 10 秒。
4. Step 4 T1：10 samples × 500 ms。
5. Runtime dashboard。

## 判讀規則

- `WAIT_EDGE delta = 0` 且 `LOW_ABORT32 delta > 0`：LOW qualification 正在反覆開始又被中斷。
- `WAIT_EDGE delta = 0` 且 `LOW_ABORT32 delta = 0`：沒有觀測到「累積到一半被中斷」，下一步才檢查 counter 是否根本無法有效累積或 threshold reach 條件。
- 累計值非零只代表歷史曾發生；本輪 sustained activity 必須以 T0/T1 delta 判斷。
- Quartus timing failure 只能列為 caveat，不能在沒有直接證據時宣稱為根因。

## Observation

尚待實機量測。

## Conclusion

尚未形成結論。

## Next Step

由本輪實機結果與 reviewer 覆核後決定；禁止同時修改多個 functional variable。
