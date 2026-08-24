# EXP-WRPC-SLAVE-DIVIDE-ONLY-SOURCE-AUDIT-20260824

## 實驗假設

本次只測試 Slave 的 SoftPLL input divider，目標是判斷 `divide-by-2` 是否影響 Step 4 的 DMTD deglitch acceptance。Master 必須保持 control source 的設定，避免再次把 Master role、PTP startup 或 Step 2 regression 一起改變。

## 唯一 functional 變因

```text
Master: g_softpll_divide_input_by_2 = true  (default/control)
Slave : g_softpll_divide_input_by_2 = false (本次唯一變更)
兩片  : g_softpll_reverse_dmtds = false
```

本次不修改 PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY。Generic plumbing 只用來將 input divider 變成可明確指定的 build-time 參數，預設值仍保持 control 行為。

## 驗證順序

1. exact commit 先完成 firmware build 與 Quartus 17 clean compile。
2. 保存 Master/Slave MIF、QSF、SDC、SOF SHA256 與 programmer checksum。
3. 雙板 fresh SOF program 後，先做 30 samples / 500 ms 的 Step 2/3 focused barrier。
4. 只有 Master 與 Slave 都通過 Step 2，且 Slave 通過 Step 3，才執行 Step 4 T0/T1。
5. 若 barrier 失敗，停止並將 Step 4 標為未測量；不可用該 image 的 Step 4 counter 做結論。

## 預期判讀

若 Master role 與 Step 2/3 保持通過，且 Slave 的 accepted / DMTD event / TAG / TRR / helper counter 出現持續正增量，才能支持 divider 是 Step 4 blocker 的假設。若 Step 2/3 失敗，則只能判定這個 Slave-only build 破壞 regression，不代表 Step 4 假設成立。
