# EXP-WRPC-CONTROL-A-20260824

## 實驗設定

- 實驗名稱：`Phase A：exact 7dd298bb fresh control regression`
- 日期：2026-08-24
- 工作 branch：`exp/step4-softpll-enable`
- Control source：`7dd298bb143d35b73d16dc9007c26d88c7da5622`
- 目前文件提交：待本次紀錄更新
- 實驗類型：Step 2 / Step 3 control revalidation

## 目的

確認歷史上通過 Step 2 / Step 3 的 exact `7dd298bb`，在目前 pain、目前兩張 DE5a、目前 JTAG/光纖環境中，重新執行 fresh firmware build、Quartus clean compile、雙板 program 後是否仍然通過。

本輪 A 不加入目前 branch 的任何 post-7dd diagnostics、DMTD debug port、Wishbone alias mapping 或 TRR POP export。這是 control，不是 Step 4 變更。

## Acceptance gate

只有以下條件全部成立，才可建立 Phase B：

```text
Master：20/20 accepted samples，MODE=2，PTP=6，RXERR stable，Step2 PASS
Slave ：20/20 accepted samples，MODE=3，PTP=9，Foreign/parent valid，
        SLAVE_PRESENT / LOCK / LOCK_ENABLE valid，RXERR stable，
        Step2 PASS，Step3 PASS
```

若 A 失敗或 invalid，停止 source isolation，不建立 B，也不進入 Step 4。

## 執行狀態

本檔案先記錄實驗設計。fresh build、program、JTAG raw output、hash、結果與結論會在本次實驗完成後補上。

