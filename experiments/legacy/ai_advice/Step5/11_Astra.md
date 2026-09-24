# 11 Astra：服務已前進，優先查頻率殘差與frequency↔phase切換

日期：2026-09-16。回覆實作WR／Luna。
F4H source `898b041afa2fcd6ca48a84eb7326eebc419ac4a3`，report `7a8b4d6b`。本文件是下一輪建議，不是已執行結果。

## 1. 結論與人類可讀進度

這輪確實排除了錯誤PHY gate：連線正常，Helper保持鎖定，Main與Helper調鐘交易均持續完成。現在的問題不是完全沒有控制活動，而是Main有活動卻無法完成相位鎖定。

**最值得先驗證的卡點是頻率捕獲與相位保持之間的交接：frequency-lock bit多數成立，但殘留頻差仍接近門檻，且會切回frequency分支，可能無法形成穩定的phase捕獲條件。** 這是優先假設，不是已證明的根因；Main服務吞吐不足、量測偏差與Master背景仍未完全排除。

唯一下一輪：`EXP-S5-F4I-MAIN-FREQUENCY-PHASE-HANDOFF-AUDIT-20260916`。

本輪仍維持production與所有控制參數凍結，只做host取樣／離線判讀。不要直接F4a候選增益、不要改frequency threshold、不要做F5或merge。

## 2. F4H核對與新增數字

完整REPORT已讀，最終raw SHA256核對為：
`ECDA10C94009513D27129F06217B51C600990F663680A4D87AB9B559809B7F84`。
以現有parser讀取整份raw並對100筆MAIN_CORE另做統計：

| 欄位 | 保存樣本的結果 |
| --- | --- |
| MAIN_FREQ_ERROR | 28..65；100筆全正；算術平均46.73；25筆>50 |
| MAIN_PI_X | -7656..7992 |
| MAIN_PI_OUTPUT | 9800..11272 |
| MAIN_PI_CLAMP_SIDE | 100筆皆0 |
| MAIN_STATE | 1有9筆，3有91筆；相鄰保存樣本共9次狀態變化 |
| MAIN_SAMPLE_N | 115770→571057 |

以上包含重複publication，不是全部producer更新的分布，也不是時間加權值。下一輪必須去重並列覆蓋，不能用這100點估完整振盪頻率。

Main trace的state bit0=enabled、bit1=freq locked，所以1/3分別是enabled但freq unlocked／enabled且freq locked。report的97/100來自另一時刻的detector觀測，不能要求它和Main trace的91/100完全一致，也不能混用其位元標註PI_X。

`spll_main.c`先做frequency detector，再選擇：

- frequency未lock：`err = -freq_prelock_gain_boost * freq_error`，目前boost20。
- frequency已lock：使用相位差並按HPLL_N做signed modulo，再送PI。

因此即使PI_X都是合法數值，也不是每一筆都代表相位。frequency-lock detector是帶計數與遲滯的狀態，不表示頻差=0。正的持續殘差與狀態切換值得先查，但還不能只憑這些稀疏點證明cycle slip或detector錯誤。

### 已發現的相干性限制

例：第一筆Main state=1、freq_error=54，PI_X卻是-1000，而非-1080；另有freq_error=47、PI_X=-600。這提示不同producer時刻的欄位可能被一起發布，不能當成PI算式失敗。

`vendor/wrpc-sw/lib/task-diags.c`呼叫Main publisher時，分別直接取得dref/dout、PI trace、sample_n與state；WDIAGS前後epoch一致只保證這次發布內容沒被讀裂，不自動保證所有來源是同一個控制迭代。需audit整個呼叫上下文與IRQ保護，再決定能作何種推論。不要先假定有或沒有中斷保護。

## 3. 要回答的唯一問題

在可信PHY、WR acquisition、Helper鎖定與Main服務前進期間，Main是否能維持frequency-qualified phase觀測段，還是反覆有偏置頻差與frequency分支回返？

可證偽條件：若新資料显示頻差分布不再單邊、長段都維持phase分支、仍然phase不鎖，則「可見的frequency回返是主要阻塞」不被支持，下一步才聚焦phase PI/actuator模型。沒有producer全速事件紀錄不能排除host採樣間短暫回返。

這一輪不宣稱要量出全部phase slip、全頻率detector規則或實體Hz偏差。source／樣本率不足時標UNKNOWN，不靠猜測換算。

## 4. 允許修改與凍結

允許：

1. `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`：F4I模式、減少非必要欄位、Main trace去重與domain標記、時長/coverage、保留F4H正確probe0和F4F Helper CORE。
2. `scripts/experiment/` 新F4I replay與必要共用parser；`scripts/tests/` 新fixture/回歸測試。
3. 本輪 `docs/experiments/exp-step5-softpll-lock/<F4I名稱>/`。

不修改 `spll_main.c`、`task-diags.c`、header或任何production C/RTL；這些僅供read-only source audit。兩板candidate0/0、Main+300/+1/boost20、Helper-2250/-2、guard8s、Slave bootstrap3388、Master bootstrap disabled、全部threshold/timeout/retry/arbiter/mailbox/reset固定。

如source audit確認現有介面无法保證需要的producer-domain資料，本輪須明列缺口；不能擅自加firmware snapshot。需要producer-side被動診斷時，另向使用者提出精確授權需求，不再以host重試取代它。

## 5. 執行規格

### 5.1 先做離線重算，不先build

對F4H raw按Main epoch/sample_n去重，分開統計trace state與detector state，列各自時間。輸出frequency誤差的median/分位數/正負比例/>50比例、PI_X/output/clamp、相鄰可見domain變化、publication重複/停滯及sampling gap。

查清dref_dt/dout_dt的更新規則、TAG_BITS/HPLL_N、phase wrap、frequency detector與phase detector條件、source publication一致性與既有隱含IRQ保護；列source行號。期望frequency公式不符時，先標 `PRODUCER_PAIR_UNPROVEN`，不命名ARITHMETIC_BUG。

不從稀疏modulo phase直接unwrap擬合漂移；除非能證明相鄰點真實相位位移小於半週期，否則phase slope/滑移數=UNKNOWN。正負跨度大本身不代表某個Hz振盪。

### 5.2 一次短資料組的只讀capture

Main重點只讀既有最小組：epoch、sample_n、freq_error、PI_X、PI output、clamp、state、epoch；保留signed raw與各讀取時間。optional kp/ki/limits等靜態metadata於起點讀並標不是同迭代，避免每筆大量讀取拖慢。

同reader保留Helper CORE/locked、direct probe0/WR/generation/reset，以及每約3秒的Main/Helper service、Master背景。不要每筆把全部position/十個L2 word塞入必要契約。需要counter趨勢就逐欄附時間，仍不做跨欄守恆。

Main目標cadence僅是盡量提高有效讀取率，不能假裝JTAG取得完整producer序列。每組有有限重試，epoch不一致拒收；記錄actual interval分布與source publish重複率，不能將同epoch重複點當新样本。

新增兩個層級標記：`PUBLICATION_COHERENT`與`PRODUCER_DOMAIN_COHERENCE`。後者若無證據=UNPROVEN。PI_X分類最多是 `PHASE_CONTEXT_OBSERVED`／`FREQUENCY_CONTEXT_OBSERVED`，不把異步state推論寫成精確producer branch紀錄。

## 6. Pain workflow與停止條件

Laptop source audit/tests→commit/push→Pain exact pull/clean build/program→single reader→Laptop replay/report→push→停止。只stage本輪檔案，保留dirty工作。functional diff覆蓋vendor/wrpc-sw、firmware、quartus、rtl。

固定 `quartus/jtag_runtime_diag`，Master `DE5 [1-11.1]/DE5a_wr_master_jtag`、Slave `DE5 [1-11.2]/DE5a_wr_slave_jtag`；用 `scripts/pain/pain_build_jtag_master.sh`、`pain_build_jtag_slave.sh`、`pain_program_jtag_master.sh`、`pain_program_jtag_slave.sh`。禁rs422。核對SOF SHA256、source/config與probe0身分；不自行斷電/補mode/reinit。

一輪120秒、hard130秒（含entry/retry）；不自動long。capture期間不snapshot owner切換、不drain FIFO、不control write。

- identity/source錯、第二reader、generation/reset新增：立即保存停止。
- 連續3次真正core transport錯、10秒無可信Main core：DATA_UNRESOLVED停止。
- PHY必要位元連續3筆不成立或可信WR terminal/disable：保存背景後停止，不作PI歸因。
- Helper連續3筆失鎖或新資料連續3筆rail：HELPER_REGRESSION停止。
- Main可信producer10秒不前進：MAIN_UPDATE_STALL停止。
- **本輪frequency unlocked是待研究現象，不再因3筆frequency回返提前停止**；繼續在總上限內保存，phase-qualified段相應中斷，不宣告其間為phase控制。
- Main phase未鎖不是安全停止條件；偶然lock僅保存，仍按上限停止。

## 7. 判定門檻與下一個分支

至少20個去重Main publication，跨至少30秒，且有至少3個10秒窗的PHY/WR/Helper有效背景與Main服務進展，才判斷窗口趨勢；未達則INCONCLUSIVE。

- `RESIDUAL_FREQUENCY_WITH_VISIBLE_HANDOFFS`：多個10秒窗frequency中位數保持同號且距0明顯、出現可信分開發布的frequency/phase context回返、phase未lock。報告實際數字，不另發明detector通過門檻。這支持優先研究捕獲/保持交接，但不是已證明因果。
- `PHASE_CONTEXT_PERSISTENT_WITHOUT_LOCK`：有效觀測主要保持phase context，頻差無先前單邊趨勢但相位不鎖；下一份建議才考慮phase PI/actuator可驗證模型或單一控制變因。不能由此排除host漏採樣事件。
- `SOURCE_COHERENCE_LIMITED`：關鍵domain/error pairing無法從source證明，或公式頻繁不符且缺原子producer證據。停止進一步host硬體循環；提交最小producer被動snapshot提案並請授權，不能宣稱需要調gain。
- `UPSTREAM_OR_HELPER_REGRESSION`／`INCONCLUSIVE`：據實列缺口。

若直接證明source契約不足，仍可保存可用的趨勢，但不得硬挑上述控制分類。這不是要求無限診斷；下一次決策必須是現有介面足夠則提出受控控制實驗，不足則明確申請最小診斷修改，而非繼續擴大host讀取。

## 8. Tests、報告與Step5

fixture包含：Main state1/3與detector讀取不同時刻；PI_X不可全部當phase；重複epoch去重；sample_n wrap/歧義；freq閾值附近遲滯；不從modulo跳躍估slip；optional metadata不同代；frequency回返不中止本輪但中斷qualified段；deadline計入所有等待。

報告列F4H重算與新capture分開、source coherence audit、publication/frame有效率、各domain時間支援、誤差/output/服務統計、Master背景、STOP原因、所有UNKNOWN。push後停，下一版12_Astra.md。

Step5仍未通過。必要條件：有效兩板WR session、完整Helper/Main frequency/phase/Main/PSTAT/READY/tracking鏈、至少300秒fresh連續有效證據、無新增reset/delock/transaction failure、strict replay true、至少3次同基準fresh-program重現。120秒diagnostic不等於closure；不改threshold/checker湊PASS；timing未closed及外部clock品質未測必須揭露。沒有可信完整PASS及既定批准，不merge。

## 9. 證據索引

`docs/experiments/exp-step5-softpll-lock/EXP-S5-F4H-PHY-STATUS-SOURCE-FIX-RETEST-20260916/REPORT.md`及其 `raw/attempt-898b041-f4h-jtag-runtime/observer.log`。
`vendor/wrpc-sw/softpll/spll_main.c` 的frequency/phase error選擇、modulo與detector；`vendor/wrpc-sw/lib/task-diags.c` 的Main publisher呼叫；`vendor/wrpc-sw/dev/wdiags.c` 的WDIAGS publication。

本次重算整份raw中Main欄位並核對source，沒有硬體操作、沒有實作控制變更。頻差／交接是比「PI太弱」更具體的優先假設，但尚未取得producer全速因果證據。
