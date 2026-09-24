# 06 Astra：F4C 未開始——先辨識 WR 啟動 gate 與 session 狀態

日期：2026-09-15。回覆實作WR／Luna。優先於 05 的「直接進 F4C」操作次序；05 的功能凍結與 Step5 驗收條件仍有效。

審查基準：source `5ba40f84cc4275f9a707bd847ac9809b267f7637`；報告 commit `e286b996`。本文件沒有執行硬體操作，不代表新的實驗結果。

## 1. 人類可讀的進度

前一輪 F4b 已讓輔助控制迴路 Helper 在觀測窗口內穩定運作；主要時鐘 Main 的相位還沒鎖住。這次原本要查 Main，但在開始前就被「兩板是否還在有效 WR 協定中」的檢查擋下，所以沒有新的 Main 好壞證據。

編譯、燒錄與通訊讀取成功，不等於 WR 握手完成。一般 PTP 可以繼續交換封包，WR 擴充協定卻已失敗。下一步先看懂這段啟動／退出過程，不改控制參數。

**判定：F4C NOT_STARTED；Step5 NOT_COMPLETE；目前不能安全當作有效 F4C session 直接進 smoke/long。** 可以執行專用只讀 gate 診斷；讀取失敗狀態是為了診斷，不是繞過 F4C gate 宣告可測。

## 2. 兩次 preflight 實際說了什麼？

| 時點 | 保存的 Slave 證據 | 正確解讀 |
| --- | --- | --- |
| 初次 | PTP=8 UNCALIBRATED；parentIsWRnode=1、parentCalibrated=1；RX LOCK count=1、TX SLAVE_PRESENT count=1；WRS_S_LOCK；LOCK_ENABLE=3 | 已進入 WR 鎖定程序，當時不是完全沒啟動。PTP 未校準不等於 PHY 壞掉；但整個 Step2 gate 仍未給 PASS |
| 60 秒後 retry | PTP=9 SLAVE、封包前進；parentIsWRnode=0、parentCalibrated=0；WRS_IDLE next=IDLE，reader 標 POST_STEP3_TIMEOUT；LOCK_ENABLE=4；保留 LOCK/SLAVE_PRESENT count=1 | 一般 PTP 活著，但本次 snapshot 不支持有效 WR session；存在 timeout／退出的歷史訊號 |

這次 Step3 擋住的直接證據是 parent flags 與 WR session 狀態，**不是先前「last TX 已變成 LOCKED 而 gate 只認 SLAVE_PRESENT」的同一案例**。不要套用舊 root cause。

Step2/Step3 在不同時點各 PASS，不能合併成同一時刻全 PASS。Step2 後來 PASS 也不能單獨解讀為整體進度改善。兩個稀疏 snapshot 無法決定 parent flags 清除與 timeout 的先後，也無法判 Master 或 Slave 誰先失敗。

現行 `read_wb_runtime.tcl` 對 PTP=8 已標 INFO，故不要只憑 UNCALIBRATED 就猜 Step2 INVALID 的唯一來源；需列出每個輸入及 `merge_status` 的聚合結果。WR_FAILURE 中列出的巨大 failure_count 亦須先核對 producer packing／位寬，不作真實重試次數使用。

## 3. 下一個唯一工作包

`EXP-S5-F4D-UPSTREAM-GATE-SESSION-AUDIT-20260915`（另日執行改實際日期）。

唯一問題：**目前 gate 反映真正 WR session 已退出、正常啟動中間態，還是 reader 聚合／欄位所有權問題？**

不修改 PLL、PI、timeout、threshold、arbiter、production C/RTL、identity、bootstrap、reset 或校準流程。不把 PTP=9 或歷史 LOCK count 當作新放行條件。不為了湊 PASS 放寬 gate。

### 3.1 Laptop 先離線審查

1. 讀本輪 REPORT、manifest、兩份 preflight raw，建立每個 gate 子條件表：raw、解碼、預期、PASS/INFO/INVALID、聚合函式及 source 路徑。保留 initial/retry，禁止跨 snapshot 合成狀態。
2. 核對 Step2 的 `merge_status`／INFO 傳播與所有其餘欄位；Step3 的 parent flags、WR state、failure shadow；核對 current 與 sticky history 語意。RAW 不存在或來源不明就 UNKNOWN。
3. 核對 `scripts/jtag/read_step5_startup_timeline_first_divergence.tcl` 現有欄位與本映像相容性。它已有兩板 PTP/WR、parent、failure/disable、PLL/event 與 frame bracket，可重用，不必另造整套框架。
4. Main trace、S_LOCK trace 的共用 bank 需核對 owner/magic；不能因為回傳合法 hex 就信任重疊 trace。只取有確認來源的 core 狀態，無法確認的輔助欄位輸出 UNAVAILABLE。不要啟動任何 snapshot owner 切換。

允許修改：上述 timeline observer 的只讀輸出／有界退出；必要時 `scripts/jtag/read_wb_runtime.tcl` 僅增加 gate 子條件輸出，不改 acceptance；`scripts/experiment/` 本輪 replay；`scripts/tests/` 對應 tests；本輪 docs。若發現 gate 真正語意錯誤，先以 fixture 證明並報告，**本輪不直接修改 PASS 規則**。

測試包括：UNCALIBRATED+S_LOCK；PTP_SLAVE+WR_IDLE+failure；parent 清除但舊訊號仍保留；不同時點 PASS 不合併；bad hex／frame 不一致；sticky failure 在 capture 起點已有；counter wrap；deadline 到期不能因重試延長。測實際 decoder，不另複製一套理想規則。

### 3.2 保存現場，不預設再次 fresh-program

本輪優先在仍運行的 `5ba40f84` 映像上只讀，不要因報告寫了「下一輪 fresh-program」就立刻抹去現場。確認兩板 board ID、映像 provenance、build/program hash、generation，現場若已被其他工作改動，停止為 SESSION_IDENTITY_UNKNOWN，不自動補燒錄。

Laptop 的 host-only 診斷若有改動，先 commit/push，再由 Pain pull 同一 observer commit。分開記錄 `observer_commit` 與 `image_source_commit=5ba40f84`，不可把新的 host commit 寫成已燒錄的新映像。**此工作包建議只讀重用映像；若使用者要求每輪必須重新編譯燒錄且不允許此例外，先請使用者確認，不擅自省略或以 fresh-program 取代現場保存。**

不下 mode 命令、不 reset/reinit、不 power cycle、不重新 program、不寫控制暫存器、不觸發 Helper PI snapshot。JTAG/WB 的必要 read-request transport 握手可使用，但先確認不發出功能控制寫入。只開一個 reader；兩板由同一 session 依序取樣，不宣稱兩板同 cycle。

### 3.3 有界 capture

重用 timeline CLI 的 trial_id、空 board_filter（兩板）、duration_ms=120000、early_gap_ms=1000、late_gap_ms=2000。正式執行前依目前腳本確認實際參數位置；不要盲貼其他工具的 CLI。

從 capture 開始最多 120 秒，外層 watchdog 硬上限 130 秒，只允許一輪。每個 request/retry 亦須有有限 timeout；不以 sample_count 當秒數。若已讀到 session 終止狀態，可按下列條件提早停止。

每筆保留兩板：host start/end、frame begin/end、generation/reset、PHY/link、mode/PTP、RX/TX delta、parent/foreign、WR current/next、RX/TX signal raw、failure/disable/lock-result 的 raw 與可信解碼、LOCK_ENABLE/SPLL_INIT、Helper/Main/SEQ/PSTAT、DMTD/TAG/TRR/IRQ/helper update 的前進情況。

核心 gate frame 必須有一致性與來源檢查，未確認 fresh 的值不得用作事件時間。記錄 first observed 與 capture-start-already-set 分別；開頭已 timeout，只能說「觀測前已發生」，不能編造自開機到 timeout 的秒數。

### 3.4 停止條件

- 身分不符、第二 reader、generation/reset 新增：立即保存並停止。
- 真正 transport timeout/無法解析連續三次：停止 TRANSPORT_INVALID；不拿它診斷 WR。
- frame 不一致可在既定 request 預算內有限重試；10 秒仍無兩板可用核心 frame，停止 FRAME_UNRESOLVED。不得跨無效 gap 補值。
- 同一 generation 取得三組連續有效觀測，均顯示 WR 已 idle/disabled/failure，並有可信 failure/disable 歷史：提前停止 SESSION_ALREADY_TERMINATED。保存 parent 與 PTP，不繼續等它自然恢復，也不重發 mode。
- 狀態仍在合法 acquisition：最多跑到 120 秒，輸出 ACQUISITION_WINDOW_OBSERVED 或 INCONCLUSIVE，不加長 timeout。
- 若同 session 出現三組連續有效的既定完整 upstream PASS 且無 current failure/disable：標 GATE_RECOVERED_OBSERVED，保存證據後結束本工作包。**不在本輪自動接 F4C smoke/long**；回報審核，以免把舊 PASS 當後續仍有效。

## 4. 結果分類與後續

1. `SESSION_ALREADY_TERMINATED`：確認現在不適合 F4C。下一輪候選是另行安排固定啟動流程，在 Slave programming 結束即啟動 timeline，捕捉第一次 WR divergence；不是再等 60 秒反覆 preflight。新 startup 是後續獨立工作包，需遵循使用者操作授權，不由本輪自動啟動。
2. `GATE_SEMANTICS_MISMATCH`：只在 raw 合法、producer 語意明確、fixture 重現聚合錯誤時成立。提出 host gate 最小修正與回歸測試，再審核；不能由此宣告 Step4B/Step5 PASS。
3. `ACQUISITION_WINDOW_OBSERVED`：保存 S_LOCK/event 前進，尚不把 acquisition 判硬體失敗。下一份建議再決定是否可用「診斷 acquisition window」進 F4C；它與 functional-ready/closure gate 必須不同名稱，不偷換 PASS。
4. `GATE_RECOVERED_OBSERVED`：下一輪 F4C 啟動前仍須在同 session 即時重驗；本次較早的 PASS 不是永久通行證。
5. `INCONCLUSIVE`／identity/transport/frame 問題：明列缺口，不改控制器、不反覆重燒。

## 5. 收尾與驗收

文件存 `docs/experiments/exp-step5-softpll-lock/<F4D實驗名稱>/`：REPORT、manifest、raw、gate_conditions.csv、timeline、fixture 結果、SHA256。報告必須區分「歷史已進過 S_LOCK」「當下 WR 有效」「一般 PTP 活著」，並列明未執行 F4C samples。Laptop commit/push 僅本輪檔案後停止，詢問 Astra 下一版；不能夾帶既有 dirty changes。

F4D PASS 只表示已用可信資料分類 gate／session，與 PLL lock 無關。Step5 仍遵循 05：有效 WR session、fresh full-chain 持續區間、strict replay、可重現性，不能以 build PASS 或讀取 PASS 替代。`STEP5_COMPLETE=NO`、`MERGE_APPROVED=NO`。

## 6. 可追溯來源

- `docs/experiments/exp-step5-softpll-lock/EXP-S5-F4C-MAIN-PHASE-SERVICE-CAUSE-AUDIT-20260915/REPORT.md`、`manifest.json`。
- 同資料夾 `raw/wr-step5-f4c-preflight-5ba40f84.log`、`raw/wr-step5-f4c-preflight-retry-5ba40f84.log`。
- `scripts/jtag/read_wb_runtime.tcl`：Step2 INFO/merge、Step3 parent/message/state/failure gate。
- `scripts/jtag/read_step5_startup_timeline_first_divergence.tcl`：現有只讀兩板時間軸、輸入參數與 frame/WR 欄位。

本次只審查保存資料、source 並撰寫建議。兩次 snapshot 支持「曾進 S_LOCK、後來觀測到 WR 已退出」；確切因果先後仍未測得，不能把推論寫成已重現的根因。
