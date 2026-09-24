# 14 Astra：Kp 倍增沒有顯示改善；下一步量測相位滑移與積分收支

日期：2026-09-16。審核基準：`f090e5e0`，branch `exp/step5-softpll-lock`。
本輪只提供建議與文件，不修改控制、不燒錄、不 merge。本文不是下一輪硬體實驗的授權。

## 1. 給沒有參與專案的人

系統有兩層要完成的工作：Helper 先建立可工作的輔助時鐘，Main 再把本地時鐘與參考時鐘的速度和邊緣位置對齊。目前 Helper 在最新兩個完整觀測窗維持鎖定；Main 也持續運算，不是沒有啟動。但是 Main 的相位誤差大部分時間超出容許範圍，因此還沒有完成 Step5。

最新實驗把比例校正強度 Kp 從 300 加倍成 600，再回到 300。兩次完整觀測都沒有鎖住，相位落在容許範圍的比例都只有約 13.6%。所以現在不值得只靠繼續加大 Kp 猜答案。優先問題是：時鐘邊緣是否一直滑過目標，而控制器的積分校正沒有形成足夠、正確的長期修正？這是待驗證假設，不是已找到根因。

## 2. F4K 到底證明什麼

| 臂 | Slave Kp | 正式觀測 | phase 帶內比例 | phase 分支比例 | 切換次數/秒 | 結論 |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| A1 | 300 | 40.907 秒，WR_S_LOCK_TIMEOUT | 13.6395% | 97.5000% | 0.2511 | 部分窗；不可當有效對照 |
| B | 600 | 120.023 秒 | 13.6511% | 95.9793% | 0.7043 | 有效完整臂，未鎖 |
| A2 | 300 | 120.553 秒 | 13.6142% | 96.1668% | 0.4372 | 有效完整臂，未鎖 |

比例取同 generation 的 producer 累積 counter 端點，不是稀疏 host 樣本投票。B/A2 實際 producer 端點跨度分別 119.264/118.927 秒，不是完全相同的窗口。兩者各 64 個 unique frame、127 個有效觀測；frame/publication error 為 0，Helper 採樣 locked 127/127，PSTAT locked 未出現，無 terminal 或新增 reset。

B 比 A2 只高約 **0.0369 個百分點**，沒有看到預期的至少 10 個百分點改善。B 切換率較高，但不能以單次非同步窗口宣稱 Kp 必然導致退步。

正式 ABA 仍是 `ARM_DATA_INVALID`；`baseline_reproducible=false` 在此表示未建立可用的完整 baseline，不能當作統計證明系統必然不可重現。不能剪掉 A1 terminal 後改判完整 ABA 成功，也不能說「已排除所有 Kp/PI 問題」。能說的是：**現有有效 B/A2 不支持直接採用 Kp600，未見鎖定改善。**

F4J analyzer 的 `DIAGNOSTIC_IMPLEMENTATION_LIMITED` 與 F4K 的 `production_control_unchanged=0` 相容性有關，不等於 snapshot 破損。保留原判定，另列 F4K frame/config/safety gate，不改舊 checker 讓它變綠。錯誤 pre-pull 的 B 資料仍排除。

另有程序問題必須交代：13_Astra 的安全停止規則要求 terminal 後停止對照；A1 report 卻寫繼續 B。請核對並引用當時是否另有使用者繼續授權；若沒有，標記 protocol deviation，不事後補造授權。不要重跑來掩蓋。

## 3. 從 source 得到的更有用問題

`spll_main.c`：frequency detector 的輸入是 `dout_dt-dref_dt`。未 frequency lock 時，PI 輸入為 `-20*freq_error`；frequency lock 後，改用 reference/output tag 差，並折回 14-bit signed phase（-8192..8191）。兩分支共用 PI 和 integrator；改 Kp 同時改兩個分支，不是純 phase-only 實驗。

`spll_common.c::pi_update`：積分提案為 `I_new=I_before+Ki*x`；anti-windup 可能令實際積分增量不同。比例項不會直接增加積分修正能力，因此倍增 Kp 不保證消除持續頻率偏差。

`ld_update`：帶內加一，帶外減到 floor；phase threshold=1200、lock_samples=1000、floor=100。它不是「1000 個連續好點」判定。13.6% 帶內不利於長期向上累積，但 aggregate 比例不能排除曾出現短暫集中好點；必須保留真正 lock event 證據。

一個值得驗證的線索：若相位近似均勻掃過完整 16384 格，落在 ±1200 的幾何比例是 `2401/16384≈14.65%`，與現在約 13.6% 同量級。**這不是均勻分布或 cycle slip 的證明**；選擇 phase 分支、非均勻速度及取樣都會改變比例。現有約 1.9 秒一筆的 latest frame 不能可靠 unwrap，也不能由 freq_error 直接換算實體 Hz。

優先假設：殘餘頻率偏差使相位反覆繞圈；包裹的 phase error 正負可能互相抵消，而少量 frequency 分支的積分修正不足。替代假設包括 actuator 追不上/量化、handoff 擾動、tag 配對或參考品質。尚不能指定其中一個為根因。

## 4. Luna 先做：不碰硬體的最小審核

1. 保留 F4K 最終 A2 配置。核對 source commit、effective Kp/Ki/boost、兩板映像 hash，不把 report commit 當 image source。記錄 A1 與 A2 的 program→smoke→formal 延遲、session entry/terminal 與可得的 deadline 狀態；欠缺資料就標 unknown，不能因 B/A2 沒 timeout 就宣稱問題消失。
2. 使用既有 B/A2 raw 分別產生固定 10 秒 counter-delta 表：in-band、phase-active、handoff、有效背景與 reset。窗口需有合法同 generation 端點；不跨缺失段、不偽造端點、不改 ABA 判定。此分析只定位是否整窗一致，不是新受控效果證明。
3. 畫出實際 Main loop → DAC_MAIN → RTL target → applied position 路徑，核對方向、單位、步長與 source IDs。服務完成有增加只證明有工作，不能證明 actuator 已追上目標；不得把不原子的 probe 拼成同時刻 lag。
4. 確認目前 trace_integrator_before/after 是否能取得同一次 Main producer 的資料。若既有 coherent 資料已足夠，先重用；禁止把不同 epoch 的 integrator 與 branch/error 拼接。

交付 source audit、現有資料能/不能回答的問題、最小 proposed diff。未取得新授權前，到這裡停止。

## 5. 唯一建議的下一個硬體實驗（需另外同意）

候選名稱：`EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE`。
性質：**被動 producer 診斷**，不是調參。目的只回答「phase 是否滑移」與「兩分支實際積分如何累積」。不再重跑相同 F4J latest-frame 而期待得到新答案。

保持 Slave/Main Kp300、Ki1、boost20，Master300/1/20，Helper-2250/-2，既有 guard8s、Slave bootstrap3388、Master bootstrap disabled、candidate0/0。timeout、threshold、lock/delock samples、PI/anti-windup、bias/range/shift、handoff、tag 配對/包裹、gain schedule、DAC writes、RTL/arbitration/reset 全部不動。

### 最小診斷契約，給 Luna 實作

- 僅 Main dac_index=0，在既有實際控制迭代旁觀測。獨立 diagnostic storage，不擴充共享 control struct/ABI，不寫回控制量，不新增 FIFO drain 或第二 reader。
- 每個 phase 迭代記錄既有 signed `err` 的 16-bin histogram（索引 `(err+8192)>>10`），以及 phase 條件下 freq_error 的 signed sum/count/min/max。累積 signed sum 用足夠寬度，避免 C signed overflow；host 才做除法。
- 對**同 generation、連續 update_id、連續 phase branch**的相鄰 err 做差。以 16384 模數計算最短 signed 增量，累積正/負 boundary crossing、signed delta sum、eligible pair count；進出 frequency、init、source change、phase shift/異常配對時斷開序列並計數。先證明相邻真實變化小於半圈才可稱 unwrap；否則只稱 modulo crossing proxy，不能宣稱實體 cycle slip。盡量以同迭代未清除的 tag/既有增量作一致性檢查，不改 pairing。
- 在 `pi_update` 返回後、gain schedule 可能修改狀態前，取既有 trace 的 `I_after-I_before`，按實際 frequency/phase 分支分別累積 signed64；同時累積各分支 `Ki*x` 提案與 clamp/anti-windup 發生次數。generation 起點、端點 integrator 用同一 coherent publication；若中間有 reinit/gain schedule 外部改 I，標 invalid 或顯式記帳，不硬湊恆等式。
- 發布 versioned companion frame，不偷偷重解釋 F4J v1。包含 generation、update_id、source identity、完整 epoch guard。先審核現有 mailbox 容量與 ABI；若需侵入既有契約，先交設計，不自行占位或增加讀取頻率。
- 所有 counter 必須能在不重置 runtime control 的條件下用端點差重建窗口。hist sum=phase updates；branch counts 合計=total；無外部 I 寫入的同代窗滿足 ΔI=sum(actual ΔI_frequency)+sum(actual ΔI_phase)。32-bit CPU 的 64-bit 發布亦需防 tearing。
- 禁止在 IRQ 加 print、浮點、動態配置或除法。新增運算本身可能影響時序；檢查 build、RAM/stack、IRQ/producer 進展。被動不代表零擾動；若背景退步或 overhead 無法界定，診斷無效，不能歸因控制。

離線 fixture 至少涵蓋：固定 phase、正/負 ramp 跨 ±8192、branch gap 不跨接、generation/source 改變、ambiguous unwrap、signed64 正負與發布 tearing、clamp 使 proposed/actual ΔI 不同、counter wrap。驗證 control output 與未插樁版本對相同輸入一致，F4J v1 regression 保留。

## 6. 預先定義如何用結果決策

- 若 phase 呈持續單向繞圈、phase 條件下 freq_error 長期偏同一符號、phase 積分正負抵消：支持「殘餘頻差未被有效拉回」；下一版才評估 Ki-only 或 acquisition 控制的單一改動。不能此輪直接增加 Ki。
- 若 phase/frequency 實際積分方向互相抵消：優先分析 shared-integrator/handoff 與 branch 時間比例。不能只因 frequency 更新少就忽略它的 boost20。
- 若 PI 校正持續累積但實體 applied position/頻差無對應反應：actuator mapping、lag/量化列為下一個獨立診斷；本輪不順便改 RTL。現有非原子 telemetry 不足時結論為 unresolved。
- 若 phase 沒有滑移而集中在固定帶外偏移：上述滑移假設不成立，改查 offset/phase reference/control sign；不調門檻迎合偏移。
- 若新增診斷無法同代/同迭代驗證或 session 再失敗：只報 diagnostic/session failure，不得下 gain 因果結論。

## 7. 執行邊界與停止

Luna 先向使用者說明：只增加上述被動證據、維持 A2 控制，是否同意一次 build/program/capture？新 schema 超出 F4J 原凍結範圍，必須明确同意。此文件或 agent 訊息不替代授權。

同意後遵守 Laptop 改碼/測試/push → Pain exact pull/build/program → raw 回 Laptop 實驗資料夾、replay/report → push → 停止。仍只用 jtag_runtime_diag 正確 Master/Slave cables；10 秒 smoke，120 秒 formal、hard130 秒。不得延長等待鎖定，不自動斷電、不重試刷到成功。

identity/schema 錯、第二 reader、新 reset/generation、WR terminal、交易 failure 增加、3筆 PHY/Helper 退步、連續3次 transport error、10秒沒有新合法 frame 即停止；不靠改 deadline/threshold 修飾結果。保存 program console 與各階段 timestamps。

資料放 `docs/experiments/exp-step5-softpll-lock/<F4L名稱>/`，包括批准記錄、source/config/image manifest、schema、fixture、raw/hash、每窗表與結論。只提交本輪檔案。結束後請 Astra 審核，不自行跑下一個控制候選。

## 8. Step5 判定與來源

`STEP5_PASS=NO`，`MERGE_APPROVED=NO`。Helper 採樣全 locked 與 Main 有運算都不是完整 Step5。保留既有完整 lock/tracking、至少300秒連續有效證據及至少3次 fresh-program 重現標準，不降 checker。Master WNS -0.047ns、Slave -0.268ns，timing 尚未 closed，仍需揭露。

本建議核對 F4K A1/B/A2 reports、`analysis/comparison/comparison.json`，以及 `vendor/wrpc-sw/softpll/spll_main.c`、`spll_common.c`、`include/spll_defs.h`。本輪未重跑 raw decoder 或硬體，不把摘要數值冒稱重新量測。
