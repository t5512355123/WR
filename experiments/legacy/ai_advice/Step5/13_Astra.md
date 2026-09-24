# 13 Astra：相位誤差大多在帶外；提議Slave Main單一Kp受控對照

日期：2026-09-16。基準F4J source `5f55c383c11c2214b44e9649b5bf06bb67ce7c75`，report `4f6e13ea`。
本文件僅為建議，不代表已修改或執行控制實驗。F4J被動快照維持原樣，不擴充schema。

## 1. 現在真正知道的卡點

Main確實走進phase分支，也真的呼叫phase detector；不是host把不同時刻資料拼錯、不是detector完全沒跑。Helper與PHY/WR背景有效，但phase誤差大多仍在容許範圍之外，lock count因此無法累積到1000。

本次讀完整F4J REPORT與formal verdict，核對去重producer CSV全部64筆及producer counter source，計算同generation第一筆到最後一筆的增量：

| producer累積counter | 差值 |
| --- | ---: |
| TOTAL_UPDATES | 455284 |
| FREQ_UPDATES | 20275 |
| PHASE_UPDATES / PHASE_DETECTOR | 435009 |
| PHASE_IN_BAND | 59088 |
| PHASE_OUT_BAND | 375921 |
| FREQ_TO_PHASE / PHASE_TO_FREQ | 各33 |

相位帶內比例 `59088/435009 ≈ 13.58%`；約95.55%更新走phase分支。這比raw host的18/125採樣比例更適合描述該producer-counter窗口。兩方向33次也说明host只看到1筆frequency branch不代表只切換一次。

64筆unique latest-frame中：freq_error25..69／平均46.453125；PI_X -8089..7830；PI output10531..12262；phase_count_after100..146（只是採樣到的範圍，不能冒稱producer歷史最高146）。因此問題是phase capture/保持效果不足，不是已證明detector門檻程式錯誤。

`ld_update` 帶內加計數、帶外減至floor，不能把稀疏資料解讀成「1000個連續好點」規則。低帶內比例支持counter難以向上累積，但不是每次迭代順序的完整重建。

**仍未證明**：PI增益一定太小、actuator速度足夠、沒有量化limit cycle、Master參考品質完全正常。正服務delta只證明liveness，不是服務速率裕度。Step5仍未完成。

## 2. 唯一下一個候選實驗

`EXP-S5-F4K-SLAVE-MAIN-KP-ONLY-300-600-ABA-20260916`。

唯一functional變數：Slave Main的Kp，由+300改為+600；Ki固定+1，frequency prelock boost固定20。Master Main固定+300/+1/20，Helper固定-2250/-2，其餘全部不變。

這是保守的倍增擾動，用來檢驗「增加比例校正能否改善phase帶內占比／回返」的方向性，不是根據現有資料推導出的最適值。**它會同時改變Slave frequency與phase分支的比例作用**，因兩者共用PI；不可宣稱只改phase gain，更不可將結果全歸因於phase分支。

不使用既有candidate=1（它一次改Kp/Ki/boost為1300/3/4），不掃多組增益，不同時調Ki或門檻。

## 3. 明確的授權界線

F4J許可只涉及被動診斷。本文件**明確提議新的控制實驗，但不把它視為已获使用者授權**。Luna先向使用者確認：

「是否同意只把Slave Main Kp由300改600，Ki/boost與所有其他控制不變，做300→600→300三臂對照？每臂依原流程build/program，保留F4J快照。」

未同意前可做read-only source audit、離線分析／測試規格，不可改production或部署candidate；停止為 `PENDING_SINGLE_KP_APPROVAL`。不要再重跑同樣的被動觀測替代決策。

## 4. 取得同意後的允許修改範圍

- `vendor/wrpc-sw/softpll/spll_main.c`：僅在CONFIG_WR_NODE現有control配置中，以明確role-specific編譯常數設定Kp；原算法、分支、診斷位置不動。
- `firmware/configs/de5a_slave_identity.h`：新增獨立Main Kp experiment override，A=300、B=600；不得切既有candidate旗標。
- `firmware/configs/de5a_master_identity.h`：如需要明確定義同一override，固定300；Master有效控制設定必須不變。
- `scripts/tests/` 配置隔離／回歸、`scripts/experiment/` F4K比較replay、本輪docs。
- host observer只允許輸出真實Kp/image/arm metadata；讀取、schema、判定算法、cadence不得因B臂改變。

先確認identity生成流程與實際preprocessed結果，不能直接改被建置覆蓋的generated header。無override時保持300；candidate與override同時啟用應明確拒絕建置，避免1300/3/4漏入。若需更大build系統修改才能隔離Slave，停止提出最小diff，不擴張。

禁止：PI common、Ki、boost、threshold/lock/delock samples、anti-windup、bias/shift/range、frequency/phase分支、tag/wrap、gain scheduling、DAC順序、Helper、Master功能、timeout/retry、bootstrap、arbiter、mailbox、RTL、reset、snapshot內容。所有F4J被動診斷保持一致。

## 5. 實驗設計：一個變數、三個有界arm

A1=Kp300新baseline；B=Kp600；A2=回到Kp300。三臂使用同一F4J診斷、相同部署/啟動程序、相同observer与比較腳本。這是一次ABA對照，不是三個不同調參實驗。

每臂：Laptop commit/push→Pain exact pull/clean firmware與Quartus build/program→10秒schema smoke→120秒正式窗（hard130秒）→raw回Laptop與該臂report/push。不得在Pain改碼或runtime送gain命令。Master→Slaveprogram順序相同，記錄program/capture delay，禁止自行斷電。

僅使用 `quartus/jtag_runtime_diag`、DE5 [1-11.1]/`DE5a_wr_master_jtag`與[1-11.2]/`DE5a_wr_slave_jtag`，既有 `scripts/pain/pain_build_jtag_master.sh`、`pain_build_jtag_slave.sh`、`pain_program_jtag_master.sh`、`pain_program_jtag_slave.sh`。禁rs422。

保存source/ELF/MIF/SOF SHA256、兩板有效gain設定、F4J schema與timing。A2須確認functional configuration回到A1；不可假設不同build位元級相同。與舊F4J比較只作背景，正式效果以這次A1/B/A2判斷。

不採warm runtime手調，不額外等一個臂較久。正式窗从同一明確程序事件計時；startup未達條件不偷延長以求lock。

## 6. 比較指標與判定預先固定

Primary：phase detector的producer累積 `ΔIN_BAND / ΔDETECTOR`，只用同init_generation、有效counter端點且有可追溯PHY/WR/Helper背景的相同長度窗口。另列phase-active比例，避免靠少執行phase取得好看的占比。

Secondary：兩方向handoff增量/秒、frequency誤差producer快照分布、phase count採樣分布、phase/PSTAT lock持續證據、PI clamp/DAC flags、Main/Helper服務進展與failed counter。host sparse maximum不冒稱全速maximum；clamp採樣全0不證明永不飽和。

離線預先定義至少30秒/20個unique producer樣本與3個有效10秒背景窗；不足的arm不可判控制效果。

實務方向門檻（診斷用，不是Step5門檻）：B的帶內比例至少比A1、A2各高10個百分點，且phase-active比例不比任一A低超過5個百分點、handoff率與Helper/PHY/WR安全指標沒有退步，才標 `KP_INCREASE_DIRECTION_SUPPORTED`。這些是預先選定的工程篩選規則，不是統計顯著性聲明。

若A1/A2本身帶內比例差超過10個百分點或startup/session條件不一致，標 `BASELINE_NOT_REPRODUCIBLE`，不挑有利的A比較。B無改善則 `KP_DOUBLING_NOT_SUPPORTED`，不自動改成900/1300或調Ki。B改善也不自動採用B或merge，先審核。

真正full phase lock若出現，記錄且優先揭露，但120秒仍不足300秒closure；以 `LOCK_OBSERVED_NOT_CLOSED` 表示。

## 7. 安全停止與回復

每臂smoke未過schema／producer一致性就停止整個對照，不部署下一個candidate。正式窗：identity/role設定錯、第二reader、reset/generation新增、WR terminal、3筆PHY/Helper退步、連續3次transport錯或10秒無新合法producer資料即停。3筆新producer顯示非零clamp（baseline未見）亦停為CLAMP_REGRESSION。

frequency回返是量測，不單獨停止。交易失敗counter新增、明顯IRQ/producer停止則停止，不調timeout補救。不放寬任何lock gate。

若B因資料不足/性能或clamp退步而停止，先保存報告；只有連線與programming前提正常，且使用者的ABA同意包含回復部署，才按A2流程回到300。若有硬體/PHY/reset異常，不盲目重燒復原，停止請使用者確認。A2不得視為已證實回復，必須觀测並記錄。

三臂完成或提前停止後，全部raw/replay/report push，停止並向Astra回報，下一版14_Astra.md。不自動加長、更換參數或下一輪掃描。

## 8. 離線測試与交付

必測：Master仍300、Slave A300/B600，兩板Ki1/boost20、candidate0/0；preprocessed正確；沒有對Helper/RTL/common PI差異；F4J fixture/schema不變；同generation counter wrap與去重；ABA不同時間窗口不能混算；invalid臂不得納入primary。

保存 `docs/experiments/exp-step5-softpll-lock/<F4K名稱>/` 下A1/B/A2分目錄、manifest、配置diff、user-approval記錄、raw hash、producer counter支援窗口、comparison與STOP原因。只stage本輪檔案，保留其他dirty工作。

## 9. Step5與merge

Step5仍需有效WR session中的完整Helper/Main frequency/phase/Main/PSTAT/READY/tracking鏈，至少300秒fresh連續有效證據、無新增reset/delock/transaction failure、strict replay true、至少3次同基準fresh-program重現。不得降threshold/checker湊PASS；timing與外部clock品質未驗證需揭露。

目前只提議一個受控Kp方向試驗，不代表已找到最適增益或根因。`STEP5_PASS=NO`、`MERGE_APPROVED=NO`。

來源：F4J REPORT、`analysis/formal/verdict.json`、`main_producer_unique.csv`，以及 `spll_main.c` producer counter累積邏輯、`spll_common.c::ld_update`。本次未部署硬體、未修改production。
