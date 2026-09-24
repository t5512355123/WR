# 08 Astra：Main 正在更新；先查 Helper 量測契約，不調 PI

日期：2026-09-15。回覆實作WR／Luna。
F4E report：`6851841aac5d7c6ee01624b434f9c9169bc410ff`；observer/image：`7851e760756a8e7021178e1358de017ae2cf2313`。
本文件僅為下一輪規格，優先於07的實驗次序；不代表已執行硬體實驗。

## 1. 給人類的進度摘要

現在可以確認主要時鐘控制程式 Main 不是完全沒工作：它持續處理新樣本，但相位仍未鎖住。下一個問題是「它給出的調鐘要求有沒有得到足夠服務、輔助迴路當時是否正常」。本輪用來回答這個問題的 Helper 同步量測全部失效，所以還不能將相位不收斂歸因於 PI。

**唯一下一輪：`EXP-S5-F4F-HELPER-MEASUREMENT-CONTRACT-AUDIT-20260915`。** 若另日執行，改實際日期。只改 host reader／replay，查清0/39量測失效的原因，並嘗試取得嚴格的最小Helper資料組；production C/RTL與控制參數完全凍結。

不直接F4a，不做F5，不改arbiter，不延長等待來碰運氣。Master仍在WAIT_HELPER是未排除背景，但不是Master bootstrap有錯的證明。

## 2. F4E 判讀的範圍

- raw39、strict Main core36、fresh producer35，支持Main持續產生新樣本。
- detector-stable30、phase in-band3、phase lock0，支持保存的相位觀測未達鎖定；3/30只是稀疏host觀測比例，不是所有detector更新的帶內率。
- PI_X=-7123..7641，clamp非零0/39：在採樣點沒看見clamp；不能排除採樣間飽和，也不能由正負範圍推斷固定振盪頻率或控制方向。
- Helper coherent0/39、position27/39、L2格式有效39/39、strict service windows0：沒有足夠資料支持服務公平性、交易完整性或Helper→Main因果。L2合法hex不是全組同時鎖存。
- reset/generation無變化，單次transport invalid不等於整輪傳輸故障。Master背景20筆无terminal，不等於Master reference品質已驗證。

保留 `PHASE_CONVERGENCE_NOT_REACHED` 作milestone描述，但不能將它寫成「已確認服務正常，僅剩PI」。F4E diagnostic_pass只代表其report定義的分類成功，未滿足07假設中對服務的完整證據要求。

原始檔案 SHA256 已核對為 `8C63AA2E579B6F4C50AF206008C72A793A1EDABA4E5F89FAF68C409FF680C1C4`。不混入早期scope/catch錯誤attempt。

## 3. 可證偽的假設

現有 `read_helper_measurement()` 順序讀epoch、十個payload word、epoch，共12次WB讀取，最多8次attempt；任一條件不合格即拒收，最後只回傳INVALID。可能原因包括：epoch持續改變、odd/sentinel、wrong mapping/owner、算式/值域不符或transport失敗。

**待測假設：長資料組與live publisher更新競爭，是0/39的重要原因。** 目前尚未證明。F4F必須保留逐attempt拒收理由，能明確否定此假設：例如前後epoch穩定卻算式不符、固定錯位址或transport錯誤占主因。

不准只增加重試次數或取消epoch檢查。不准將短資料組通過寫成原十欄全組通過。

## 4. Laptop 離線工作與允許檔案

只允許：

- `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`：Helper read diagnostics與F4F明確模式；維持其他模式行為。
- 可新增一個共用的host Helper reader/decoder檔案，須放 `scripts/jtag/` 並在manifest列出；參考 `read_step5_coherent_closed_loop_trajectory_audit.tcl`，不可直接假定它對本映像相容。
- `scripts/experiment/` 本輪replay、`scripts/tests/` tests、本輪docs資料夾。

不得修改production C/RTL、header mapping、firmware或兩板identity；讀source做audit可以，寫入不行。

先比對目前reader與歷史能讀到Helper的reader：CPU base/offset、signed/unsigned、word width、transport、epoch、sentinel、writer/owner及合法值域。對照 `vendor/wrpc-sw/include/hw/wrc_diags_regs.h`、`vendor/wrpc-sw/dev/wdiags.c::wdiags_write_wr_spll_helper_measurement_debug` 和實際呼叫者，確認epoch覆蓋與更新率；不能只核對欄位名稱。

functional diff稽核須包含 **`vendor/wrpc-sw`**，不能只查`firmware quartus rtl`就宣稱全部production凍結。記錄實際build/preprocessed參數與來源，不靠寫死metadata。

### 4.1 每次attempt輸出

記錄profile、host開始/結束、全部實際raw、epoch_before/after、各欄解析值、各驗證布林與reason flags。至少包含：TRANSPORT_ERROR、PARSE_ERROR、ODD_OR_SENTINEL、EPOCH_CHANGED、ARITHMETIC_MISMATCH、RANGE_MISMATCH、ACCEPTED、OWNER_UNVERIFIED。多個原因可同時保留，不以單一else掩蓋。

失敗raw不可丟棄、不可全改INVALID，不以previous-good填值。有限retry原上限不增加，各request仍有timeout。

### 4.2 固定對照兩個host讀取profile

同一reader在相邻audit cycle交替讀：

- FULL：維持原十欄payload與全部既有條件。
- CORE：epoch→helper_error→producer_update_count→helper_output→epoch。僅在source audit確認這三欄確實由同一epoch保護時啟用；否則CORE_DISABLED並列理由。

CORE的CPU位址依目前source核對，預期error `0x00100B14`、update `0x00100B18`、output `0x00100B1C`、epoch `0x00100B00`。不得盲用預期位址。CORE只宣稱三欄一致，不再提供完整tag/frequency算式通過。不同profile有時間偏差，保存duration，不能當作完全相同瞬間的A/B。

CORE與FULL各自epoch前後相同且偶數、排除sentinel、來源正確、欄位合法才接受。freshness另看producer delta，duplicate/stale不算新控制樣本。FULL各算式檢查原樣保留；CORE未讀的欄位是NOT_MEASURED，不能VALID。

這是單一「host量測契約」實驗，FULL/CORE是預先固定診斷對照，不是控制系統兩個functional變因。

### 4.3 離線測試

執行實際parser/classifier：FULL/CORE穩定成功、epoch改變、odd/sentinel、錯誤字串、signed負數、算式不符、output越界、producer stale、wrap/ambiguous delta、profile間禁止共用payload、deadline含重試、CORE不能升格FULL。所有fixture通過才push。

## 5. Pain部署與capture

遵守Laptop修改/測試→GitHub push→Pain exact pull/clean build/program→單reader capture→Laptop raw/report/replay→push→停止。

正確target固定 `quartus/jtag_runtime_diag`：

| 角色 | cable/top | 腳本 |
| --- | --- | --- |
| Master | `DE5 [1-11.1]` / `DE5a_wr_master_jtag` | `scripts/pain/pain_build_jtag_master.sh`、`scripts/pain/pain_program_jtag_master.sh` |
| Slave | `DE5 [1-11.2]` / `DE5a_wr_slave_jtag` | `scripts/pain/pain_build_jtag_slave.sh`、`scripts/pain/pain_program_jtag_slave.sh` |

禁止rs422及未帶jtag的build替代；驗證mailbox與52..61、actual program路徑、兩板SOF SHA256、image/observer commit。保持Master→Slave既定program順序，不額外等60秒，記錄capture開始延遲。不得自行斷電或補送mode。

參數保留：candidate0/0、Main+300/+1/boost20、Helper-2250/-2、guard8s、Slave bootstrap3388、Master bootstrap disabled；threshold、timeout/retry、arbiter、其他quantization/範圍均不變。

一個process、一個reader，既有只讀transport握手可用；不trigger Helper PI snapshot、不讀取會drain的FIFO、不control write。Slave每個cycle只跑一個profile，交替FULL/CORE；每約3秒由同一reader保存Master current WR/SEQ/Helper/terminal/reset背景。Main/position/L2作低頻背景，不讓它們成為Helper profile是否接受的條件。

不要以「完整Helper量測還沒通過」阻止啟動本診斷，否則循環依賴。入口是正確identity/target、可用transport及可信session core；若觀测到合法acquisition，標明診斷允許，不改Step4B/Step5 gate。失效session可保存短證據但不作phase/service有效窗。

## 6. 上限與停止

總120秒，外層硬130秒，含入口等待、Master輪詢與retry；不自動long或再次燒錄。

- identity/target錯、第二reader、generation/reset新增：立即停止保存。
- 連續3次真正transport錯誤，或10秒沒有可信session core：停止DATA_UNRESOLVED。EPOCH_CHANGED不是transport錯，不用它觸發此條。
- 可信current WR terminal/disable：保存最多2組確認資料後停止SESSION_ENDED；sticky起點已有與新增事件分開。
- Helper coherent判斷失敗正是本輪要測的現象，不因3個INVALID就中止；依總deadline結束。
- 得到可信Helper新資料後，連續3個有效樣本rail或3個可信state顯示失鎖，停止BASELINE_REGRESSION並保存，不改參數。
- 若FULL/CORE都持續失效仍跑到有界結束，分類原因；不放寬接受條件。

## 7. 判定與下一步分支

報告每profile attempt/accepted/fresh數、各reason數、讀取duration分布、valid時間覆蓋、transport錯誤與Master背景。多原因flags總和可能大於attempt數，須註明。

- FULL主要為EPOCH_CHANGED，而CORE至少20個fresh accepted樣本、跨至少10秒：`COMPACT_HELPER_CORE_OBSERVABLE`；支持讀取跨度限制，尚非證明所有FULL失敗只由跨度造成。不宣稱FULL contract通過。
- 前後epoch穩定但算式/位址/值域錯：`READER_CONTRACT_MISMATCH`，以raw+source+fixture定位；這輪只提下輪最小host修正，不改production或gate。
- 大量transport原因：`TRANSPORT_LIMITED`，不推論Helper/PI故障。
- epoch正常但producer不前進：`STALE_OR_IDLE_PUBLISHER`，不要用其誤差描述即時控制。
- 合法live讀取始終無一致窗口：`NO_READ_ONLY_COHERENT_WINDOW`，原樣承認在現有production介面下做不到，下一份建議再討論是否需額外診斷授權；不擅加firmware snapshot。
- 有效度不足或多原因無法分離：`INCONCLUSIVE`。

**本輪主要驗收是查明Helper拒收機制，不要求湊出strict service windows。** 將MAIN_CORE、HELPER_CORE、POSITION、L2各自品質分開。取得Helper CORE也不能直接啟用舊要求FULL的service checker；將來若要定義較小service contract，必須明列必要欄位與同窗口證據。

L2格式有效、Main producer前進不等於Main執行器服務已證明。缺共同觀測窗口，不相減request/completed、不歸因arbiter、不宣稱無飢餓。Master仍未鎖不能用來替代這些缺口。

## 8. Step5 PASS必要條件與交付

F4F diagnostic結果與Step5 verdict分開，預設 `STEP5_COMPLETE=NO / MERGE_APPROVED=NO`。

Step5至少需：有效兩板WR session；Helper/Main frequency/Main phase/Main locked、PSTAT、SEQ_READY/tracking完整鏈在同一可追溯session成立；至少300秒連續fresh有效證據，invalid/stale/過大gap中斷區間；producer持续前進、無新增reset/delock/transaction failure；strict replay true；至少3次同基準fresh-program重現。不能降低threshold或修改checker來達標，不能將內部lock等同外部clock精度/jitter。Timing未closed獨立揭露。

本輪最多120秒，本身不足以完成300秒closure；即使看到lock也只記LOCK_OBSERVED_NOT_CLOSED。merge另需使用者既定批准。

保存於 `docs/experiments/exp-step5-softpll-lock/<F4F名稱>/`：REPORT、manifest、raw/hash、attempts.csv、profile_summary、source_contract表與tests。僅提交本輪檔案；push後停止並詢問Astra，下一版09_Astra.md，不自動進控制變更。

## 9. 證據導航與限制

F4E目錄：`docs/experiments/exp-step5-softpll-lock/EXP-S5-F4E-ACQUISITION-MAIN-PHASE-PROGRESS-20260915/`。
讀取REPORT與最終raw/hash；helper reader source為 `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl::read_helper_measurement`，writer/header為上述檔案。

本次核對保存報告、raw hash與相關source；未重跑硬體、未宣稱逐點重算整份strict replay。對Helper失效的跨度解釋仍是待證偽假設，不能写成已確認根因。
