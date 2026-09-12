# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-RESEED-BIAS63252-COLD-UPSTREAM-BLOCKED-20260912

## 判定

**Step 5：NOT RUN（upstream blocked）**

本輪完成 cold power-cycle、fresh clone、fresh build 與 programming，但沒有形成可用的 Step5 observer window。不能把本輪當作 reseed-bias 的 pass 或 fail，也不能據此宣告 Step5。

## 實驗目的

在同一個通電週期內的 reseed-bias warm run 受到可能的外部 SI5340 殘留狀態影響，因此先實體斷電，再用同一個 source commit 重新 build/program，驗證 cold-start 的 upstream 是否可用。

## 版本、build 與 programming

- Branch：exp/step5-softpll-lock
- Source commit：4059ea1（4059ea1698ac4cbf239b178024225ea2a8176a49）
- Functional source：包含 helper_reseed bias=63252、bootstrap=3388、Helper Kp=-150、Ki=-1
- Master build：PASS，timing_closed=NO
- Slave build：PASS，timing_closed=NO
- Master SOF SHA256：77f251a382a8b8f56c852465fef8ccb02459853d6a850b98bd600cac3a1d38ef
- Slave SOF SHA256：4f6ef75681c763c91c90eee89965446704ef65fb8e00b0e212d6052564fb14c7

實體電源循環後，兩端均重新 programming：

1. Master：PASS
2. 等待 45 秒
3. Slave：PASS
4. 等待 120 秒並做 preflight
5. 再做一次 Master -> 45 秒 -> Slave warm recovery

## Preflight 結果

cold initial 與兩次 settled/recovery snapshot 都未達到 Step1：

    Master WDIAGS_PTP=6 MASTER
    Master core_tm_link_up=0
    Master core_link_ok=0
    Master PTP_RX delta=0
    Master RXERR delta=0
    Master Step4A event chain=PASS

    Slave Step1=blocked
    Slave Step2=invalid or upstream not ready
    Slave Step4B=blocked by upstream prerequisite
    Slave LOCK_ENABLE=0

因此沒有合法的 Step4B active window，也沒有執行 Step5 observer。

## Interpretation

這輪證明的是 cold power-cycle 後，當下 Master PHY/WR link 沒有建立；它沒有證明 reseed bias=63252 的控制效果。雖然 Master PTP state 仍為 MASTER、事件計數會增加，但沒有 PTP RX 與 physical link，不能把它當成完整 WR runtime ready。

由於同一 source 在前一個 3388 cold run 曾成功進入 Step4B，而本輪在 cold start 後仍為 core link down，下一步應先把這個 upstream startup reproducibility 問題獨立處理；否則任何 Helper/Main lock 結論都會混入 PHY/endpoint 狀態。

## 原始資料

- Raw archive：EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-RESEED-BIAS63252-COLD-UPSTREAM-BLOCKED-20260912-raw.tgz
- Raw archive SHA256：38d58705c6cf391be3ca1baf0f19ce720ca20a6179f47058c48f65e7c52f5bb8
- 同目錄 raw/ 保存 cold build、program 與三次 preflight/recovery logs。

## 下一步

保留目前 source，不再修改 Step5 控制參數；先以既定的 Master/Slave recovery 流程取得可重現的 Step1–4B active window。取得後，才重跑同一個 reseed-bias=63252 image 的 3600-sample observer，並把結果與 3388/Kp=-150 baseline 比較。
