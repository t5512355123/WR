# 07 Astra：有效 acquisition 已出現，下一輪只查 Main 相位進展與服務

日期：2026-09-15；回覆實作WR／Luna。
證據基準：F4D 有效 JTAG-runtime capture，source `e5e9cfb2a42c385d0508668985c07d44b65bd87b`，report commit `60989169`。
本文件是下一轮規格，不是已執行結果。操作次序優先於 05/06；原有功能凍結、證據品質與 closure 規則仍有效。

## 1. 進展與結論

兩台板卡正在嘗試同步時鐘。Slave 的輔助迴路 Helper 在窗口結尾已鎖住，主要迴路 Main 也已開始運算並達頻率鎖定，但相位未鎖住。這表示現在能觀測到更下游的問題，不應再只做一般 preflight、等到全部 ready 才開始查。

同時 Master 還在 `SEQ_WAIT_HELPER`，不能把這個背景忽略，也不能僅憑此就判定 Master 是 Slave 相位未鎖的根因。下一步測量 Slave Main 的新輸入、輸出與調鐘服務，並低頻保存 Master 狀態；不改任一迴路參數。

**唯一實驗：`EXP-S5-F4E-ACQUISITION-MAIN-PHASE-PROGRESS-20260915`。** 另日執行用實際日期。

這是一輪 read-only acquisition 診斷，不是 F4a 調參，不是 F5 Master bootstrap，也不是 Step5 驗收。禁止自動進入功能變更或另一輪實驗。

## 2. 本輪可證明與不能證明的事

- F4D 120199 ms，Master 37/38、Slave 38/38 core-valid；沒有 generation/reset 變化與 terminal streak。支持「保存的窗口內仍在 acquisition」，不保證現在板卡仍處於同一狀態。
- Slave 結尾 `UNCALIBRATED / WRS_S_LOCK / SEQ_WAIT_MAIN`，Helper=1、Main enabled/freq/phase=1/1/0：是可觀測 Main 相位捕獲的入口，不是 upstream full PASS。結尾狀態不能冒充整個120秒皆相同。
- Master `MASTER / WRS_M_LOCK / SEQ_WAIT_HELPER`、Helper=0：應記錄為上游控制背景尚未完成，不由它推算 Main PI 或 bootstrap 值。
- 沒有 Main phase/PSTAT lock，所以 `STEP5_COMPLETE=NO`。F4D_PASS 只表示診斷取得有效 acquisition window。
- rs422 target 缺 mailbox／52..61 probes 的 timeout 是映像介面不相容，不列入本輪硬體故障率，不與有效 raw 合併。

報告中「問題已縮到 Slave phase convergence」應理解為**可見的第一個未完成 milestone**，而非已排除 Master、Main service、reader freshness 或已證明 PI 根因。

## 3. 唯一假設及可證偽結果

待檢驗假設：在 Slave Helper 保持鎖定且 Main frequency-lock 的合法 acquisition 窗口，Main 的新控制樣本與相應服務持續發生，但 phase error／detector 不足以達成 phase lock。

以下任何一項可否定或限制這個假設：Main producer 停止更新；有持續需求卻無服務；資料 stale/混代；Helper 先失鎖；WR session 先退出。不能把這些都命名為 PI 不收斂。

只有得到 Main 新鮮樣本、服務進展及 phase 誤差證據後，才可能在下一版建議討論調參。僅看到 frequency lock bit=1 不足以證明 Main 正在工作。

## 4. 允許修改檔案與凍結範圍

允許 host-only：

1. `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`：新增明確 acquisition 診斷模式／入口分類、單 reader 的 Master context、可靠 mailbox read、時間上限、freshness/停止原因。
2. `scripts/jtag/read_step5_startup_timeline_first_divergence.tcl`：僅在需要抽取或共用已驗證只讀 decoder 時修改；不能同時開第二個 timeline 程序。
3. `scripts/tests/test_step5_f4c.py`、`scripts/tests/test_step5_f4c_observer.py` 與 F4E 新測試；`scripts/experiment/` 本輪 replay。
4. `docs/experiments/exp-step5-softpll-lock/<F4E名稱>/` 的 manifest/report/raw/analysis。

禁止修改 production C/RTL、identity、build target 的功能組成、gain/boost、threshold、timeout/retry、arbiter、bootstrap、reset。兩板 candidate=0/0、Main control +300/+1/boost20、Helper -2250/-2、guard8s、Slave bootstrap3388、Master bootstrap disabled，以及所有其他實際 build 設定原樣。若 runtime 與保存基準不符，停止，不靠改 metadata 遮蓋。

現有 trace 不足以證明某項因果，就輸出 UNKNOWN 並停止該推論；本輪不擴充 firmware instrumentation。

## 5. 正確的 Pain target 與流程

固定 `quartus/jtag_runtime_diag`：

| 角色 | 板卡 | top-level | workflow |
| --- | --- | --- | --- |
| Master | `DE5 [1-11.1]` | `DE5a_wr_master_jtag` | `scripts/pain/pain_build_jtag_master.sh`、`scripts/pain/pain_program_jtag_master.sh` |
| Slave | `DE5 [1-11.2]` | `DE5a_wr_slave_jtag` | `scripts/pain/pain_build_jtag_slave.sh`、`scripts/pain/pain_program_jtag_slave.sh` |

禁止用未帶 jtag 的 `pain_build_master.sh`／`pain_build_slave.sh` 或 rs422 SOF 替代。先核對 QSF/top-level 包含 mailbox 與 probe52..61，再核對實際 program 路徑和兩板 SOF SHA256；Quartus checksum 不是 SHA256。

依使用者既定流程：Laptop 完成 host 修改、離線測試並 push；Pain exact pull、確認乾淨來源→上述 build/program→單 reader capture；raw 回 Laptop→report/replay→push→停止。若事先已獲准重用同一有效映像，可不重燒，但必須區分 observer commit、image source commit 與 session generation；未获准不自行跳過流程。不自行斷電，不改 mode/reinit 以製造入口。

build/program 是觀測前的既定部署步驟，不是 read-only capture 的一部分；capture 開始後不寫任何功能控制。保持既定 Master→Slave program 順序，記錄各自完成時間與 capture 延遲，不額外等固定60秒，也不等 Master Helper lock 才開始記錄。

新建置可能有 fitting 差異：保存 source/config/hash/timing，不宣稱與上一個 SOF bit-identical。Timing closed=NO 仍獨立揭露。

## 6. 非循環的診斷入口

新增輸出 `ACQUISITION_DIAGNOSTIC_ALLOWED`，**不可重寫 STEP4B_ALLOWED 或 STEP5_PASS**。startup core sampling 可在驗證 transport/identity 後立即開始，即使 phase 尚未鎖住。

兩組連續有效觀測需有：兩板身分/角色正確、PHY/link可用、generation/reset 穩定；Slave 位於可信 active WR acquisition 狀態（本輪證據為 WRS_S_LOCK），無 current disable/terminal 狀態；Slave Helper=1、Main enabled=1、freq_locked=1。phase=0 是要研究的現象，不是拒絕診斷條件。

Master 尚在 WRS_M_LOCK/WAIT_HELPER 可以作未就緒背景，不能將其當 WR closure PASS；若 Master terminal/disable，當次兩板 session 的結論必須中止。parent/message/history 欄位照樣保存；彼此矛盾時 ENTRY_UNRESOLVED，不自動忽略。

UNCALIBRATED 不得自動當硬體失敗，也不得放寬成 full upstream PASS。這個專用入口允許看 acquisition，完全不宣告功能 ready。

## 7. 一個 reader、三組資料

重用 F4C Main observer 已有的 Main trace/PI_X、detector shadow、Helper coherent measurement、L2。先核對其 mailbox 協定符合 e5e9cfb2 已驗證的 preload→toggle commit→一致回讀，不能假設不同 reader 的 transport 修復自動相通。

1. **Slave Main 核心**：producer sample_n/update、publication epoch、enabled/freq/phase/locked、真正 PI_X、output/unclamped/clamp、phase count/threshold、frequency error與mode。確認 PI_X 對應 PHASE 而非 frequency/prelock 模式。host sample 不等於 producer sample。
2. **Slave 服務與保護欄位**：Main/Helper pending/start/completed/failed、可用 target/applied/residual、Helper新量測/locked/rails、generation/reset/WR current/disable。counter 必須在同語意且同覆蓋窗口比較，不將不同 delta_samples 相減當 backlog。
3. **Master低頻背景**：PTP/WR/SEQ、Helper lock、Main enable、generation/reset/failure/disable與核心link。同一 reader 序列輪詢，不開第二個 process；各板帶 start/end time，不宣稱同 cycle 或先後小於採樣誤差。

Slave目標約每0.5秒、Master每約3秒一次；記錄實際讀取耗時，這不是強制硬體取樣率。不能為追採樣率犧牲一致性。所有 read/retry 有上限。Main/Helper snapshot bank owner/magic 不明則 INVALID；禁止 Helper PI snapshot、debug FIFO drain 或任何控制寫。

publication 穩定不保證演算法資料同代：Main進度以 producer delta 判斷，保留 ambiguity 修正。phase detector shadow 與PI不是同一 producer sample 就只能作趨勢，不精確 replay 每次 detector 更新。`ld_update` 的增減計數非「1000個連續好點」；稀疏host資料不能冒充全頻率detector輸入。

## 8. 時間上限與停止條件

一次 capture，自第一個讀取開始最多120秒，外層硬上限130秒；所有入口等待、重試與Master輪詢均含在內，不因入口晚出現就重設時鐘。**本輪沒有自動600秒long。**

- 入口前允許有限 core-only 等待；直到120秒仍不符合，`NO_ELIGIBLE_ACQUISITION_WINDOW`，不重燒、不改mode、不重試另一輪。
- 身分/target錯、第二reader、generation/reset變化：立即停止並保存。
- transport真錯誤連續三次，或10秒无可用Main核心資料：`DATA_UNRESOLVED`，停止；不解讀成控制失敗。
- Master或Slave可靠current terminal/disable：保存觸發frame與最多兩個確認frame，在總上限內停止 `WR_SESSION_ENDED`。sticky歷史若起點已存在需另標，不直接當新事件。
- 入口成立後，Slave Helper連續三個有效frame unlock／新量測連續三筆rail：停止 `HELPER_REGRESSION`。Main phase尚未鎖住不觸發停止。
- Main producer在入口後10秒不前進且讀取可信：停止 `MAIN_UPDATE_STALL`，保存服務/WR背景。freq lock連續三筆消失則結束phase-qualified segment並停止 `FREQ_ACQUISITION_REGRESSION`。
- position非原子INVALID不得填值；只要Main核心可用，允許跑到總上限，但涉及position的結論保持UNKNOWN。
- 若所有lock偶然成立，記錄首次觀測與後續至上限，仍不延長、不宣告Step5 PASS。

## 9. 可判定結果

至少20個新鮮Main producer樣本、跨越至少10秒的合格phase segment，才做趨勢分類；此為本輪分析最低覆蓋門檻，不是lock門檻。不足列INCONCLUSIVE。

- `MAIN_SERVICE_BLOCKED_SUSPECTED`：可信持續需求存在、Main start/completed不前進；先查service，不能先改PI。pending/residual不足則不成立。
- `PHASE_CONVERGENCE_NOT_REACHED`：Main持續更新、Main交易確有進展，phase仍未锁；輸出phase誤差範圍／帶內比例、count趨勢、clamp比例及時間覆蓋。這仍不是PI錯誤的證明，可能需更完整測量模型。
- `DETECTOR_CONSISTENCY_UNRESOLVED`：phase誤差與count看似不符但不同代／漏採樣，不能判detector bug。
- `REFERENCE_OR_SESSION_LIMITED`：Master或WR先出現可見失效；只報觀測順序與時間不確定度，不能直接推導Master bootstrap修正。
- `LOCK_OBSERVED_NOT_CLOSED`：僅短暫內部lock，沒有完整驗收。
- `NO_ELIGIBLE_ACQUISITION_WINDOW`／`DATA_UNRESOLVED`／`INCONCLUSIVE`：據實列缺口，不調參、不將缺資料改成零。

Master整段WAIT_HELPER但無terminal，可記錄為持續限制；僅憑此不得歸因Slave相位失敗。F4E診斷成功代表有效區分至少一個上述邊界，不是Step5成功。

## 10. 離線驗證、交付與停止

fixture測試至少包含：PTP8/S_LOCK/Helper1/Main110允許diagnostic而fullPASS保持false；Master WAIT_HELPER不冒充ready；terminal中止；錯誤target/缺mailbox；producer stale/ambiguous delta；phase/frequency domain區分；不同窗口counter不相減；總deadline不因重試延長；Master輪詢仍為單reader。

建議實作時先輸出dry-run schema及fixture結果，再照Laptop→GitHub→Pain流程。若舊CLI只接受legacy/smoke/long，必須明確新增並測試acquisition模式，不借用legacy繞過保護。

report需有參數凍結表、兩板target/SHA256、observer/image commit、program/capture時間、實際秒數、producer有效率、合格segment、停止原因、Master背景與raw索引。只提交本輪檔案，保留其他dirty changes。push後停止並向Astra提問，下一份為08_Astra.md。

Step5仍需有效WR session、完整fresh lock chain的持續窗口、strict replay與重複fresh-program驗證；本輪120秒不足以單獨符合05的300秒closure門檻。`STEP5_COMPLETE=NO`、`MERGE_APPROVED=NO`，不自動merge。

## 11. 證據索引

- `docs/experiments/exp-step5-softpll-lock/EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915/REPORT.md`、`manifest.json`。
- 同目錄 `raw/attempt-e5e9cfb2-jtag-runtime/tmp/wr-step5-f4d-timeline-jtag-e5e9cfb2.log` 與 `analysis/replay-e5e9cfb2-jtag-runtime/`，只使用有效target資料。
- `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl` 的Main trace/detector/PI_X與ambiguity處理。
- `scripts/pain/pain_build_jtag_master.sh`、`pain_build_jtag_slave.sh`、`pain_program_jtag_master.sh`、`pain_program_jtag_slave.sh`。

本次審查以F4D有效紀錄為事實基礎，以現有source確定實作入口；沒有把前輪rs422錯誤、歷史PI猜測或未量得的Master因果當作新證據。
