# 12 Astra：停止重複host觀測，申請最小Main producer被動快照

日期：2026-09-16；回覆實作WR／Luna。
F4I report commit `f8cfb3bc`，capture source `a67fee352e57213bc05dc06d5518462d97a54d55`。

## 1. 結論與進展

F4I重現了Main持續運算、單邊頻率殘差、可見frequency/phase回返與phase不鎖。PHY/WR/Helper背景有效，已不應繼續把主要精力放在一般連線或完全無服務。

但目前domain、error、PI、detector可能不是同一次控制更新。F4I自己明列 `PRODUCER_DOMAIN_COHERENCE=UNPROVEN`；64次dref/dout算式通過不會自動讓PI_X與branch具有同迭代因果。

**下一個唯一實驗：`EXP-S5-F4J-MAIN-PRODUCER-HANDOFF-SNAPSHOT-20260916`。** 單一變因為被動診斷可見性，不改控制行為。目的不是再取更多同樣的JTAG點，而是第一次直接保存「這次迭代到底用了frequency還是phase誤差」。

最可能方向仍是殘留頻差與捕獲/保持交接不穩定；尚不足以選PI增益、frequency threshold或強制phase。不要直接啟用F4a、F5，不merge。

## 2. 執行前授權界線——不可跳過

過去工作包凍結production C/RTL。F4J必須改到firmware producer才能補足來源一致性，因此**本建議不是對既有凍結的自動解除**。

Luna現在可執行：read-only source/layout/timing audit、host離線fixture設計、列出最小patch計畫。完成後向使用者確認：

「是否同意僅增加Main被動診斷快照及其發布，不改PI、門檻、控制分支、RTL或reset，並照既定流程build/program一次？」

在使用者同意之前：不編輯production檔案、不build/program新診斷映像、不自行用host重跑代替。本輪只有這一個候選，不附帶第二個控制實驗。若未獲准，保存計畫並停止，狀態 `BLOCKED_PENDING_DIAGNOSTIC_SCOPE_APPROVAL`，不是硬體失敗。

## 3. F4I支持什麼／尚缺什麼

報告及source_coherence_audit全文核對：正式120041 ms、100 publication-valid、去重64、跨118927 ms、12個有效背景bins，frequency error27..66/均48.375/全正，28/64超過50，60個PHASE-context/4個FREQUENCY-context、可見8次交接，phase lock為0。

這些是稀疏publication觀察，不是完整control迭代統計。Task-diags依序讀Main live欄位，與IRQ控制更新可能交错；WDIAGS epoch只保護發布窗。PI自身trace epoch又不涵蓋frequency detector與branch選擇。整個publication可一致，來源仍可能混代。

不從signed modulo相位稀疏點估cycle-slip次數，不把「頻率flag為1」當frequency error=0，不用64個host點精確重放1000次detector累積。

## 4. 取得同意後，允許的最小檔案範圍

診斷-only firmware：

- `vendor/wrpc-sw/softpll/spll_main.c`：在實際Main更新中記錄診斷local/state，尾端發布獨立RAM快照。
- `vendor/wrpc-sw/softpll/spll_main.h`：只允許獨立診斷struct/extern/API宣告；不要擴充既有 `struct spll_main_state`（其共享記憶體ABI有版本要求）。
- `vendor/wrpc-sw/lib/task-diags.c`：有限次seqlock copy已完成RAM記錄，禁止混讀live Main state來補欄。
- `vendor/wrpc-sw/dev/wdiags.c`、`vendor/wrpc-sw/include/hw/wrc_diags_regs.h` 與實際publisher prototype header：只作已審核診斷schema輸出／版本，不改控制register、bus或SDB範圍。
- host observer、replay、tests與本輪docs。

先找到實際prototype header並列入manifest，不猜檔名。若需要RTL/記憶體映射擴張、IRQ mask、新task、排程改變或控制命令才放得下，停止再審核，不擴大範圍。

禁止：改PI共用函式、gain/boost/threshold、frequency/phase分支条件、detector規則、anti-windup、DAC輸出內容/次序、tag/wrap算法、gain scheduling、timeout/retry、bootstrap、arbiter、mailbox、PHY、reset、Master控制模式。Main+300/+1/boost20、Helper-2250/-2、candidate0/0等全沿用。

## 5. Producer快照契約

只對原Main主迴路（核對dac_index=0語意）記錄，不影響其他channel。使用獨立static診斷storage，不改既有shared struct layout。

一次有效Main tag pair迭代中，保存：

1. update_id／init_generation，真實這次freq_error；freq detector更新前後locked/count。
2. **實際執行的branch ID**（在原if/else分支內只寫診斷local，不重新用稍後flag推算）。
3. 傳給PI的最終signed error（after wrap）、本次PI output/clamp；phase detector是否真的被呼叫、更新前後count/locked。
4. 這次是否實際走DAC寫入（freeze有無），以原條件的觀測旗標表示；不新增或阻擋DAC寫入。

在原迭代完成、最後可能return前提交整筆：odd→memory barrier→payload→barrier→even。先審查所有return與gain schedule位置，確保每筆是完成記錄、沒有分支漏發布。不要重跑PI或detector來計算trace。

Task-diags只copy同一個RAM epoch的完整資料，前後epoch相等且偶數才publish。失敗有限重試，超限標invalid而非拿live值填補。WDIAGS另有publication epoch；raw同時含producer update_id與publication epoch，兩者不可混用。

為保證epoch包住64-bit或多word欄位，核對CPU word size與compiler barrier；不使用long IRQ mask。若C語言有signed overflow風險，診斷counter採unsigned且明確wrap。不讓診斷計算改變原數值運算型別。

### 全速事件的最小累積證據

在同一producer位置以32-bit計數保存total updates、frequency-branch updates、phase-branch updates、兩方向branch transition counts、phase-detector updates、phase in-band/out-of-band updates。每個計數只增量，不加高成本統計。

這樣host漏採樣時仍可讀增量；但只證明窗口內事件數，不還原每次事件順序。額外提供latest transition record即可，不建立大型ring buffer或printf。若空間/時序代價超標，先減欄位並報告，不靜默丟掉核心branch/error/update_id契約。

## 6. 發布窗口與schema

先audit現有Main bank、Helper snapshot、S_LOCK、reinit的owner。優先重用既有Main診斷窗口並增加明確新版magic/version；禁止猜測未用位址或讓舊reader把新packing當舊版。

不要建立巨大單次host讀組而重犯FULL問題。可分「latest completed iteration」與「累積事件summary」兩個小profile，各有自己的schema/epoch/producer ID。跨profile沒有同ID就不能拼同迭代；可以各自算可信時間增量。

累積計數profile與latest sample在RAM應有一致來源契約；傳輸可拆窗，但報告需保留每組generation/epoch及時間。Host不得為抓snapshot寫控制request；只讀被動發布。新版reader遇舊schema必須拒收，不fallback猜packing。

## 7. 離線驗證與擾動控制

必測：frequency分支error=-boost*本次freq_error；phase分支signed modulo與本次PI輸入吻合；detector呼叫旗標/count前後符合原規則；IRQ插入task copy時seqlock拒收；跨profile不同ID不拼接；init/reset generation切換、counter wrap；所有return不漏record；freeze不寫DAC時如實記錄。

核心要求：使用相同tag輸入序列比較instrumentation開/關，原Main return、DAC值/寫入順序、PI/lock state逐步相同。覆蓋wrap、capture/phase回返、gain schedule/early return的實際可達路徑。不能只用手寫理想模型替代實際原函式。

記錄新增RAM/ROM、編譯與已具備的update/IRQ速率；先檢查實際機器碼或平台能力評估每次ISR新增成本。沒有時間量測就寫未量得，不宣稱zero perturbation。若無法給出合理bounded成本、memory overflow或明顯事件處理退步，停止，不改排程來補救。

## 8. 部署／capture／停止

僅在同意診斷例外、離線測試與schema審核通過後：Laptop commit/push→Pain exact pull、clean firmware/Quartus build→Master/Slave program→單reader capture→Laptop raw/replay/report→push→停止。

target仍 `quartus/jtag_runtime_diag`：DE5 [1-11.1] Master `DE5a_wr_master_jtag`、[1-11.2] Slave `DE5a_wr_slave_jtag`；使用 `scripts/pain/pain_build_jtag_master.sh`、`pain_build_jtag_slave.sh`、`pain_program_jtag_master.sh`、`pain_program_jtag_slave.sh`。不使用rs422、不自行斷電或補mode。保存firmware/MIF/SOF SHA256與diagnostic-only diff。

10秒smoke只驗schema／producer coherence，再做一次120秒正式窗、hard130秒。smoke失敗不進正式窗；不自動長測或調參。單reader保留Helper CORE、direct probe0、WR、generation/reset與低頻服務/Master背景；不drain FIFO、不Helper PI snapshot。

立即停止：身分/schema錯、第二reader、generation/reset新增、記憶體/溢出/原函式等價測試失敗。capture中3次連續core transport錯、10秒無可信新producer record、3筆PHY/Helper退步、WR current terminal/disable亦停止。frequency回返是待測事件，不因它停止；phase未鎖不延长時限。

## 9. 判定與控制變更之前的最後邊界

診斷coherence PASS最低要求：至少20個新鮮同producer記錄跨30秒、至少3個有效10秒背景窗；所有accepted branch/error/PI/detector欄位通過同ID契約。任何無法解釋的公式/ID不符先判診斷失敗，不判控制bug。

- Producer累積計數證實頻率回返，且同迭代頻差與branch/error符合算法：`PRODUCER_HANDOFF_CONFIRMED`。可對回返前後積分/輸出、頻差門檻與服務延遲提出下一個唯一控制假設；不能直接同輪改gain。
- Producer資料否定host先前domain配對：`PUBLICATION_CONTEXT_MISPAIR_CONFIRMED`，修正歷史因果解讀，不推翻真phase lock=0。
- Producer長段phase更新但detector帶內累積不足：`PHASE_CAPTURE_ERROR_PERSISTS`；下一步討論phase loop/actuator模型，不先怪detector。
- 同迭代帶內count行為違反實際ld_update：先檢查init/gain schedule、trace位置与原函式等價，再判detector根因。
- ISR擾動／schema／owner無法保證：`DIAGNOSTIC_IMPLEMENTATION_LIMITED`，停止，不再以host多讀幾輪替代。

本輪只完成一個producer診斷實驗。結果回報Astra，下一版13_Astra.md；不自動開始PI sweep。

## 10. Step5與merge

診斷PASS不等於Step5。Step5仍需有效WR session、完整Helper/Main frequency/phase/Main/PSTAT/READY/tracking鏈、至少300秒fresh連續證據、無新增reset/delock/transaction failure、strict replay true與至少3次同基準fresh-program重現。不得靠放寬threshold或checker湊PASS，timing與外部clock品質限制單列。無完整證據與既定同意，不merge。

本次讀F4I REPORT及source_coherence_audit，核對Main producer/PI/shared-struct與診斷header source。沒有修改production、沒有build/program；本建議的production診斷例外仍待使用者明確批准。
