# 05 Astra：F4b control 判讀與下一個唯一實驗

日期：2026-09-15。回覆「實作WR」任務的 F4b 診斷問題。
審查 source：`a1980bff30231376a3182486fd786d906876c2d4`，分支 `exp/step5-softpll-lock`。
本文是建議，不是已執行的實驗，也不授權 merge main。優先於舊建議中尚未依 F4b 結果更新的下一步。

## 1. 結論

**F4b 支持 Helper 在本輪觀測窗口內有持續服務、低殘差且保持鎖定；Step5 仍未完成。下一步回到 Slave Main 的「服務→相位控制→detector」邊界，但先不啟用 F4a candidate，不改 Master bootstrap。**

建議唯一實驗：`EXP-S5-F4C-MAIN-PHASE-SERVICE-CAUSE-AUDIT-20260915`。若另日執行，用實際日期。

本輪唯一變因是診斷可見性，production functional delta 必須為零。先回答 Main 是否真的持續收到服務及更新相位 detector，才決定 F4a 調參或另一個仲裁修正。Helper 優先服務的成功並不能證明 Main 沒被拖慢；Main frequency lock bit 也不能代替 Main 新量測與新交易。

## 2. F4b 證據及必要勘誤

Luna 提供的 upstream PASS、clean build/program、identity macro 0/0、reset stable，作為本輪已驗證前提。另核對本機 raw 與 replay，不推論未測的 Master 根因。

| 證據 | 可以判定 | 不可延伸成 |
| --- | --- | --- |
| Helper measurement 6000/6000、RMS 107.5892、max abs 466、actual threshold 2000 之外為零、rails 零 | 本窗口 Helper 誤差與輸出表現良好 | 全系統 clock 品質、外部 jitter 或所有啟動皆穩定 |
| frame 5949/6000；可判讀 Helper locked，final=1；count=1000 | 支持觀測期間保持鎖定；count 飽和後不再上升正常 | 補齊 51 筆無效 frame，或證明每個未採樣時刻都無失鎖 |
| SPLL_DELOCK_COUNT=0、reset delta=0 | 相應 counter 覆蓋的事件未增加 | 未查 writer 語意就認定它涵蓋所有 transient Helper/Main 失鎖 |
| DCO/FINC/FDEC 與正常請求、完成活動 | Helper liveness 已有實機支持 | 無條件公平仲裁、Main liveness、實體 I2C readback 保證 |
| Main frequency=1、phase/Main/PSTAT=0、full-chain=0 | 最後仍未完成相位／完整鎖定 | 直接證明 PI 增益太低、detector 錯，或 Master bootstrap 必須修改 |

### 時間不是 sample 數

raw 的 `sample=120 elapsed_ms=16790` 與 `sample=6000 elapsed_ms=845143` 分別代表約 **16.790 s、845.143 s** 的 first-to-last sample 窗口。檔名的 120／6000 是筆數，不是秒數。請更正本輪報告的「120-s／6000-s」描述，保留原檔名與原始資料。

### 計數器不能跨不同覆蓋區間相減

smoke observer 的 post-bootstrap baseline delta 是 request=1608、completed=1607；replay 全部相鄰有效配對則是 request=1621（119 個 delta）、completed=861（66 個 delta）。long replay 是 request=82859（5999 個 delta）、completed=50427（3839 個 delta）。它們不是同一組起訖與時間覆蓋。

因此 **82859−50427 不是未完成 backlog，也不是 dropped requests**。部分無效 position 之外，還須核對 request 計的是 target 更新、admission 還是 transaction，以及 coalescing、counter 位寬／wrap。只有同語意、同窗口才能做守恆。POSITION_ACCOUNTING PASS 表示通過已實作 invariant，不是全部 6000 筆都具 position 證據。

## 3. 為何不直接 F4a 或 F5？

現行 `spll_main.c` control 是 kp=+300、ki=+1、frequency boost=20；candidate 是 +1300/+3/4。切 candidate 雖可稱單一設定組，實際同時改比例、積分與頻率捕獲增益，不能單獨辨識相位停滯原因。

更重要的是：目前提供的 F4b 資料主要量 Helper，沒有新鮮的 Main PI 輸入、積分、輸出、phase detector 計數與 Main 交易的共同時間證據。Helper 修好後，應把量測焦點移到 Main，不必重做整套 Helper 植物辨識，但也不應用 Helper RMS 推算 Main 增益。

F5 會改 Master 的啟動工作點並引入第二個控制系統變因。本輪 upstream 已 PASS，提供的證據沒有直接指出 Master bootstrap 是下一個失敗邊界。只有後續發現 Master reference／WR 狀態先出問題，才把 F5 列為下一輪候選。

## 4. F4C：Luna 可執行規格

### 4.1 凍結功能參數

- 保留 `a1980bff` normal HPLL residual admission／arbiter order，不再移動分支。
- 兩板 `DE5A_SLAVE_ONLY_MAIN_PI_CANDIDATE=0/0`；Main +300/+1、boost 20。
- Helper -2250/-2、現有 shift/bias/anti-windup/輸出範圍不變；threshold=2000、lock_samples=1000。
- Slave bootstrap=3388、方向與其餘 generic 原樣；Master bootstrap disabled；Helper phase guard=8 s。
- Main frequency threshold=50、lock_samples=50、delock floor=10；phase threshold=1200、lock_samples=1000、delock_samples=100。
- WR timeout/retry、DCO 量化步幅／cooldown／範圍、tag/phase 算法、reset、PHY、SI5340 設定一律不變。
- 以 source/preprocessed build 與 runtime metadata 驗證實際設定，不相信舊 observer 字串（現有 Main observer 還有寫死 guard=60 s 的舊標籤）。若 HEAD 已變，先逐項比較，不覆蓋別人改動。

### 4.2 允許修改檔案

優先僅用現有 Main trace：

1. `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`：模式／單位標籤、Main coherence/freshness、時間上限、服務關聯與失效原因。
2. `scripts/experiment/` 的本輪 replay 與 `scripts/tests/` 相應測試；不得放寬既有 Step5 pass 判定以求過關。
3. `docs/experiments/exp-step5-softpll-lock/<本輪名稱>/`：manifest、report、raw 與分析。

若現有 trace 不足以判斷 phase detector，允許以下檔案的**純診斷新增**：`vendor/wrpc-sw/softpll/spll_main.c`、對應 `spll_main.h`、`softpll_ng.c`、`vendor/wrpc-sw/dev/wdiags.c` 及實際使用的診斷宣告 header（先找實際路徑，列入 manifest）。不得改演算法回傳值、控制分支、增益、門檻或更新頻率。RTL 功能與兩板 identity 不在本輪修改範圍。

先完成 bank/owner/writer audit。Main trace 與 Helper PI snapshot 有重疊所有權；**只開一個 reader，不啟動 Helper PI snapshot**。Main coherence 至少需 same producer update ID／generation，而不只是 host publication epoch；若宣稱來自同次控制更新，必須確實在 producer 更新邊界保存，不能把異步讀取的幾個值拼起來。先測試 telemetry 擾動、編譯／memory size，再進硬體。

### 4.3 必須回答的四個問題

1. **Main 是否運算？** 保存 enabled、真正 `sample_n`／update delta、tag-pair 有效性、freq/phase branch、WR/seq、generation。publication 在跳但 Main update 不跳，算 stale／未運算，不算控制樣本。
2. **Main 是否獲得執行調鐘？** 保存 Main target/applied/residual（如已有可信欄位）、L2 Main pending/start/completed/failed/max wait 與 Helper 同類背景。註明各欄時間與有效範圍；沒有 demand 不能判飢餓，update count 也不是交易數。若需求持續且 start/completed 不前進，先查 admission／service，不改 PI。
3. **相位誤差與 PI 是什麼？** 保存真正傳入 `pi_update`／`ld_update` 的 signed phase error、積分前後、unclamped/clamped output、clamp side、freeze 狀態、實際 kp/ki/shift/bias。frequency error 不能冒充 phase error；值域與 wrap 依程式實際 mask/HPLL_N 核對。
4. **detector 為何不達標？** 保存 phase detector update 次數、lock_cnt、locked、threshold、lock_samples/delock floor；最好增加 producer-side in-band/out-of-band 累積次數，避免 host 漏採樣。現行 `ld_update()` 是帶上下限的增減計數，**不是「連續 1000 個好樣本，遇一個壞樣本就歸零」**。離線 replay 必須重現實際規則；稀疏 host samples 不足以精確 replay 每次 detector 更新，缺 producer 證據就標 UNKNOWN。

### 4.4 離線測試與操作流程

測試至少覆蓋：Main disabled 零值不計收斂、publication 新但 producer stale、phase signed/wrap、counter wrap 與缺值中斷、不同窗口禁止計數相減、detector 門檻內外及 floor/saturation、時間上限不使用 samples 代替 seconds、無效 frame 中斷 strict 連續證據。

Laptop 修改→測試→commit/push；Pain pull 同一 commit→完整 build/program→preflight→single reader；raw 回 Laptop 寫報告→push→停止請 Astra 審查。不在 Pain 改 source，不自動執行 F4a/F5，不自行斷電。僅 stage 本輪檔案，不夾帶已有 dirty/untracked 實驗資料。Main/Slave source、firmware/MIF/SOF hash、identity、build timing 結果均記錄。

## 5. Smoke／long 的明確門檻

下列為 F4C 新訂診斷操作門檻，不是把舊樣本數重新命名成時間。

### Smoke：120 秒實際 elapsed，硬上限 130 秒

- upstream preflight 不成立、image identity 不符、存在第二 reader：不開始。
- 正式開始後新增 reset/generation、transport 連續三次失敗：立即停止並保存證據。
- Helper 在三個連續有效 frame 顯示 unlock，或連續三個有效新量測達 rail：停止，標 BASELINE_REGRESSION，不繼續 long。
- Main 無新 update 達 10 秒：標 MAIN_NOT_PROGRESSING，保留 service/WR 狀態後停止；不是 PI 不收斂。
- Main 核心一致且新鮮的有效率需至少 95%；不足則修診斷，不進 long。不要求 position 每筆有效，也不得因失效就填前值。
- 120 秒內沒有 phase lock 不算 smoke 失敗，只要 Main 持續更新且服務／phase 因果資料可信，可進一次 bounded long。

### Long：600 秒實際 elapsed，硬上限 610 秒

延用上述安全與資料停止條件。原 F4b 已看過約 845 秒，沒有必要再用「6000 筆」誤當 100 分鐘等待。每 30 秒輸出 Main 更新率、phase in-band 比例／count 變化、PI clamp 比例、Main demand/service 及 Helper guardrails。

若 WR 已失敗或 disabled，保存第一個失敗前後證據後停止，標 WR_SESSION_INVALID；後續內部 lock 不算有效 closure。600 秒未鎖就結束、分類，不延長 timeout／重跑直到成功。

判讀分支：

- Main residual 持續，無 start/completion：優先 DPLL admission/service；下一輪不做 F4a。
- Main 持續服務與更新、phase error 不收斂且 PI 有飽和／振盪：取得新鮮定量證據後，才提 Slave-only F4a 控制組／候選組比較；Master 保持 control，threshold 不改。
- producer 顯示 detector 正常獲得帶內樣本，但 count 不符合原始 `ld_update`：先排除 reinit、writer、telemetry，再以最小測試定位 detector 缺陷；不直接降低門檻。
- Main/Helper 內部鎖定而 WR 不前進：轉查協定 deadline/calibration；只有 Master reference 問題被直接觀測才考慮 F5。
- 資料缺關鍵欄或混代：INCONCLUSIVE，明列缺口，不猜 PI 根因。

## 6. Step5 PASS 與 merge

F4C diagnostic PASS 只表示能定位邊界，不能等於 Step5 PASS。功能驗收至少需要：

1. 有效兩板 WR session，Helper/Main frequency/Main phase/Main locked、PSTAT、SEQ_READY/tracking 同時成立；不是只有最後一筆。
2. 至少 300 秒連續有效且新鮮的 full-chain 證據（沿用現有 300 s 指標）；invalid/stale/generation change 或超出事先宣告採樣間距的 gap 中斷區間，不插值補齊。這仍是觀測層證據，不能冒稱量到每個硬體 cycle。
3. 無新增 reset/delock/transaction failure，Main/Helper producer 都持續前進；誤差、飽和比例與服務統計完整保存。
4. strict replay true，至少三次同基準 fresh-program 重現；cold boot 與 warm program 分開記錄。未做 cold boot 不寫成做過。
5. timing 未 closed 另列 implementation caveat，不宣稱完整硬體品質／外部 jitter 已通過。不得修改 pass checker 或 lock threshold 來湊 PASS。

目前 `STEP5_COMPLETE=NO`、`MERGE_APPROVED=NO`。即使後續功能驗收通過，也先回報並依使用者既定審核程序取得 merge 同意。

## 7. 證據位置與審查限制

- 本轮根目錄：`docs/experiments/exp-step5-softpll-lock/EXP-S5-F4B-ARBITRATION-CONTROL-20260915/`。
- `analysis/replay/verdict.json`：sample/validity/RMS、strict false、不同 counter 的 delta_samples。
- `raw-transfer/extracted/raw/f4b-control-observer-smoke-120.log` 與 `f4b-control-observer-long-6000.log`：elapsed_ms、observer summary。
- `vendor/wrpc-sw/softpll/spll_main.c`：control/candidate、phase detector 呼叫條件與參數；`spll_common.c`：實際 lock counter 演算法。
- `vendor/wrpc-sw/dev/wdiags.c`：Main/Helper snapshot owner；Main observer：舊 metadata 與跨組讀取限制。

本次核對保存的 replay、raw 端點與摘要和相關 source，未重新跑硬體，也未宣称逐個 cycle 重建整輪。raw 此刻仍為未入庫資料，Luna 應完成本輪報告／證據保存；本建議 commit 只提交本文件，不代為提交其未完成工作。
