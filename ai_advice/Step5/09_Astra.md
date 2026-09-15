# 09 Astra：Helper短讀取可用，回到Main服務與相位的同窗觀測

日期：2026-09-15；回覆實作WR／Luna。
報告基準 `e4aa80635473162b8f2917bd3ab4508637209da4`；有效映像／observer `e550e57d11493b18ff30728e3a295b63dc87cfa4`。
本文只提出下一輪，不表示已執行或批准merge。操作順序優先於08，production凍結與closure規則延續。

## 1. 人類可讀的結論

這輪解決的是「看不清楚」，不是已經把時鐘鎖住。Helper的完整資料在讀取途中一直更新，前後不是同一版，所以被正確拒收；縮成必要的三個欄位，就能持續取得一致的新資料。

因此不必繼續強求完整讀取全部成功，也不該把先前0筆有效量測當成Helper故障。現在應將可讀的Helper核心資料接回Main觀測，問：Main持續運算時，調鐘服務是否前進，而相位是否仍未鎖住？

**唯一下一輪：`EXP-S5-F4G-COMPACT-HELPER-MAIN-SERVICE-WINDOW-20260915`。** 另日執行改實際日期。host-only/read-only/單reader，維持所有控制參數，不調PI、不做Master bootstrap、不改arbiter。

## 2. 全文與raw核對結果

已讀完整REPORT（包含失敗attempt1與有效attempt2），對最終raw全部768行執行現有replay，重算478個attempt，並另以raw hex核對51個accepted CORE的epoch前後相等、偶數及output合法。SHA256吻合：

`43282D7B79A2BC847F9F41D3CF45CDF438A1F0D87A587757BBC1F44B53B1637D`

- 103個交替cycle：FULL52個cycle/416 attempts，全為EPOCH_CHANGED；CORE51個cycle/62 attempts，51 accepted、50 fresh，跨度116909 ms。
- FULL有81次同時算式不符，但epoch也改變，不能當成producer算錯。
- profile transport/parse均無錯；attempt1的inactive probe錯誤獨立保存，不能併入有效硬體結論。
- CORE三欄成功不表示FULL其他欄位同代。FULL仍未通過，不能將CORE填補為FULL valid。
- reset/terminal觀測未增加，仍不能宣告Step5。

### 需要明確揭露的兩項限制

1. **OWNER_UNVERIFIED**：現行程式將此旗標固定為1，全部478 attempts皆如此，但accepted判斷未使用它。這不自動推翻epoch/raw讀取結果，卻表示「來源所有權完整驗證」不是F4F已完成的事。下一輪先查source writer與owner；不得只把旗標改成0。
2. **Master背景品質**：replay的59筆background中Slave26筆valid，Master33筆均含transport_error（報告指出position probe部分timeout）。不能用整體background invalid直接推論Master WR失敗，也不能因reset/terminal為0就把Master全部欄位當可靠。下一輪拆開CORE_STATE_VALID與OPTIONAL_POSITION_VALID。

另注意「FULL 11-word／十欄」在報告、舊reader與本輪profile描述不完全一致，應以最終profile實際RAW_FIELDS及read次數列出，不靠名稱推導耗時。這不影響416次epoch改變的實測結論。

## 3. 可證偽假設與非目標

假設：在Slave合法acquisition、Helper核心新鮮且保持鎖定的區間，Main producer與其服務完成計數持續前進，但相位仍不能鎖定。

若Main無新樣本、交易完成不前進、Helper先失鎖、WR session退出或資料無法驗證，均限制／否定這個假設。即使假設成立，也只表示「有服務且仍未鎖」，不等於PI已證明錯誤，更不等於服務速度足夠、延遲有界或無飢餓。

本輪不要求FULL成功、不做FULL/CORE交替、不新增production snapshot。避免將慢速JTAG讀取硬拼成同cycle全域快照。

## 4. Laptop允許修改與先行source audit

允許檔案：

- `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`：明確F4G模式，重用F4F CORE reader、F4E Main core、低頻Master core；各品質欄位獨立。
- `scripts/experiment/` 新F4G replay與必要共用parser；`scripts/tests/` 新測試及既有reader回歸。
- `docs/experiments/exp-step5-softpll-lock/<F4G名稱>/`。

禁止修改production C/RTL/header、identity、PI/gain/boost、threshold、timeout、bootstrap、arbiter、mailbox功能與reset。functional diff必須包含 `vendor/wrpc-sw`、`firmware`、`quartus`、`rtl`。

先列 `helper_source_contract.md`：映像commit、WDIAGS base/offset、epoch與error/update/output所有writer、publication barrier、owner/overlay、其他覆寫條件、runtime身分依據。讀 `wdiags.c`、實際呼叫者及header。將「SOURCE_CONTRACT_VERIFIED」「RUNTIME_IMAGE_VERIFIED」「DYNAMIC_OWNER_VERIFIED」分開，沒有動態owner標記就寫NOT_AVAILABLE。若source可證該模式下無其他writer且image可信，可用SOURCE_BACKED_CORE這個有限契約；不能宣稱完成動態owner驗證。若競爭writer不能排除，先停止OWNER_UNRESOLVED，不跑硬體湊樣本。

L2各counter亦列source語意：位寬、reset、何時遞增、是否只代表logical completion、讀取是否保證單word一致。無法驗證read atomicity時，輸出raw並降級，不能因hex合法就作守恆式。

## 5. 明確的最小觀測契約

### 分組，不設大一統GROUP_VALID

1. `HELPER_CORE_VALID/FRESH`：epoch→error/update/output→epoch；保留原嚴格檢查與全部拒收raw。不是FULL，沒有tag/frequency/accept counters就NOT_MEASURED。
2. `MAIN_CORE_VALID/FRESH`：F4E已核對的最小epoch組、真正producer sample_n、PI_X/output/clamp/state。detector shadow仍是另一組，不能用它替Main組宣告同代。
3. `WR_CORE_VALID`：兩板role/link/generation/reset/current WR/disable及Slave Helper/Main狀態。Master optional position不影響其core狀態有效性，真正core讀取錯才算core transport fault。
4. `SERVICE_COUNTER_VALID`：逐word讀取L2 Main/Helper start/completed/failed，各自帶host起訖；pending/max-wait作背景，不將十個probe全部合法等同全組原子。

Main/Helper各自producer前進是freshness；host序號與publication新不等於控制樣本新。

### 同窗的定義

固定10秒host分析bin，保存每一read的start/end，不補值、不插值。每個bin至少包含2個新鮮Main core與2個新鮮Helper core；這些是時間關聯，**不是同sample或同cycle因果**。

服務counter對每個欄位，以同generation的可信before/after讀取計算自身delta，列其自己的實際起訖與跨度，並標與bin是否重疊。位寬wrap需按source及可支持的最大速率驗證，歧義則INVALID；不能直接相減不同支持區間的start/completed。若各counter無共同覆蓋或read有歧義，SERVICE_WINDOW=UNKNOWN，不填零。

新契約名 `COMPACT_PROGRESS_WINDOW_V1`，列出使用的欄位、品質、時間涵蓋。**不要修改F4E舊strict service checker以便它突然通過**；新增獨立判定，清楚指出它不證明request→admission→ACK每步因果。

不能只因瞬間pending=1且某bin完成0就宣稱飢餓；需持續、可信需求證據及足夠覆蓋。無需求資訊只可說本窗口未觀測到服務進展。

## 6. 部署流程與target

Laptop修改/測試→commit/push→Pain exact pull、clean build/program→單reader→raw回Laptop、replay/report→push→停止。

僅使用 `quartus/jtag_runtime_diag`：

- Master `DE5 [1-11.1]`、`DE5a_wr_master_jtag`：`scripts/pain/pain_build_jtag_master.sh`、`pain_program_jtag_master.sh`。
- Slave `DE5 [1-11.2]`、`DE5a_wr_slave_jtag`：`scripts/pain/pain_build_jtag_slave.sh`、`pain_program_jtag_slave.sh`。

確認mailbox、52..61、SOF路徑/SHA256、image/observer commit、source/config。禁止rs422替代，不自行斷電、補mode或reinit。capture期間僅既定只讀transport握手，不trigger Helper PI snapshot或drain FIFO。

參數原封不動：candidate0/0；Main+300/+1/boost20；Helper-2250/-2；guard8s；Slave bootstrap3388；Master bootstrap disabled；其他threshold/retry/quantization保持映像基準。timing未closed單列。

一個process/single-reader，正確啟閉並同步active probe context（保留e550e57d修正）。Slave依序讀Helper CORE、Main CORE、必要L2與WR core；Master每約3秒由同reader讀core。不重做FULL。記錄實際採樣耗時，不為了達固定cadence放寬epoch。

## 7. 窗口、入口與停止

整輪120秒，hard130秒，包含entry waiting與retry，不自動600秒long。

transport/identity確認後可開始診斷core。兩個連續可信Slave frame顯示active acquisition、Helper=1、Main enabled/frequency=1且無current terminal後，才標phase-qualified window。phase=0不是拒收原因。完整upstream gate仍不改；Master WAIT_HELPER保留為背景，不當ready。

- identity/target不符、第二reader、generation/reset新增：立即保存停止。
- 真正核心transport錯連續3次，或10秒無可用Main/Helper core：DATA_UNRESOLVED停止。optional position錯不算核心transport錯。
- owner/source契約無法驗證：離線階段停止，不自行改production。
- 可信current WR terminal/disable：最多2個確認frame後停止SESSION_ENDED，起點sticky歷史另列。
- entry後Helper連續3個有效frame失鎖、或3個新core輸出rail：HELPER_REGRESSION；Main frequency連續3筆失去則FREQ_REGRESSION，停止相位診斷。
- Main producer可信且10秒不前進：MAIN_UPDATE_STALL，保存counter背景後停止。
- L2資料不足不觸發假服務故障；到120秒若不能形成window就UNKNOWN，不加長重跑。
- 偶然lock只保存，不延長、不宣告Step5。

## 8. 判定及可推進的下一步

至少3個合格10秒bin、Main/Helper各至少20個fresh樣本，才做本輪窗口趨勢判定；這是診斷資料最低覆蓋，不是lock門檻。未達列INCONCLUSIVE。

- `MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK`：合格窗口中兩個producer前進，Main可信completed delta多個窗口>0，phase未鎖。可把「完全無Main服務」降為不支持；仍不能保證服務速度足夠。下一版才根據phase誤差、clamp/更新率決定是否需要控制模型或單一增益實驗。
- `MAIN_DEMAND_SERVICE_GAP_SUSPECTED`：有持續且可信需求而服務無進展；若需求或counter語意缺失，不能用此標籤。下一版查service，不改PI。
- `HELPER_OR_SESSION_REGRESSION`：Helper/WR先出問題，保存時序與不確定度；不直接猜Master bootstrap。
- `SERVICE_EVIDENCE_UNRESOLVED`：Main/Helper可讀但service read契約不足，停止歸因；不得將有效core升格全鏈已驗證。
- `LOCK_OBSERVED_NOT_CLOSED`／`INCONCLUSIVE`：依證據如實標示。

不要求在這一輪選出production修正。完成後回報Astra，下一版10_Astra.md；不自動執行另一輪。

## 9. 測試與交付

fixture必測：CORE不能升FULL；source verified與dynamic owner分離；active probe lifecycle；Main/Helper不同epoch不拼同cycle；10秒bin覆蓋不足；counter wrap/歧義/不同區間禁止相減；Master optional錯而core有效；core真錯觸發停止；producer stale；deadline包含retry。測實際執行parser，不只測重寫的理想模型。

本輪docs保存manifest、source contract、raw/hash、逐組attempt、bins.csv、counter_support.csv、replay/tests、STOP原因與哪些結論UNKNOWN。保留dirty工作，只stage本輪檔案。push完成即停止。

Step5必要条件仍為：有效WR session、完整Helper/Main frequency/phase/Main/PSTAT/READY/tracking鏈、至少300秒fresh連續證據（invalid/stale/大gap中斷，不補值）、無新增reset/delock/transaction failure、strict replay true、至少3次同基準fresh-program重現。未做外部clock品質不宣稱jitter/絕對精度；timing caveat揭露。`STEP5_PASS=false`，不merge。

## 10. 證據路徑

`docs/experiments/exp-step5-softpll-lock/EXP-S5-F4F-HELPER-MEASUREMENT-CONTRACT-AUDIT-20260915/REPORT.md`、`manifest.json`。
最終raw：同目錄 `raw/attempt-e550e57d-f4f-jtag-runtime/tmp/observer.log`。
replay：`scripts/experiment/step5_f4f_helper_contract_audit.py`；source reader：`scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`。

本次全文讀報告、整份raw透過replay逐record核對並重算，未把全部raw逐行直接貼出；沒有硬體操作或控制修改。
