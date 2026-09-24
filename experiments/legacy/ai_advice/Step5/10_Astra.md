# 10 Astra：F4G的PHY gate讀錯來源；先做唯一host修正與重測

日期：2026-09-16。回覆實作WR／Luna。
F4G capture `3708d85b576236b1407efb7d50c99a30c0e42996`；report `ac866456193bd93e99066bcea78b110d1049ecd6`。
本建議不代表已執行新硬體實驗。優先於09的下一步；production凍結與完整Step5驗收規格仍保留。

## 1. 人類可讀的進度與明確結論

Main與Helper的控制樣本、調鐘完成計數現在都能持續被觀測，這是進展。但最新「連線全部不可用」不是已證實的實體斷線：**F4G的host reader讀錯了狀態來源。** 它把診斷資料有效旗標當成PHY ready/link位元，因而將全部相位觀測窗擋掉。

下一輪不是繼續查PI，也不是改硬體，而是修正這一處資料來源後重做同樣的有界觀測。Main phase=0、PSTAT.locked=0仍是獨立保存的未鎖定證據，不能因發現reader錯誤就當成Step5已通過。

**唯一實驗：`EXP-S5-F4H-PHY-STATUS-SOURCE-FIX-RETEST-20260916`。**

## 2. 全文與raw/replay核對

已讀完整F4G REPORT、manifest、helper_source_contract。最終raw hash吻合：

`BE9E24DAC855A0E3C0B7858FEAE8FCB5F041D4138CC6EB9505869FD20FAE94D7`

將整份raw交給目前F4G replay逐record重算，得到：134個Helper attempts／92 accepted、Main92/92、WR core123（Slave92、Master31）、L2 word920、service records276、12個fresh bins，classification仍INCONCLUSIVE、diagnostic_pass=false。保存的同欄服務delta支持計數前進，不支持每個request皆被完成或仲裁延遲有界。

全部123筆WR紀錄的 `STATUS_RAW` 只有0或1：Slave90筆為1、2筆為0；Master30筆為1、1筆為0。各筆PSTAT_RAW=1。這與下述錯誤來源吻合：STATUS實際是CTRL資料有效旗標，不是實體PHY。

## 3. 根因：不同介面的位元配置被混用

`scripts/jtag/read_step5_main_frequency_prelock_observability.tcl::f4g_emit_wr_core`：

```tcl
set status [wb_read $hardware_name 0x00100A04]
```

後續把status的bit0/1/2/3/6/7/15解讀成SI_CONFIG_DONE、WR_READY、CORE_TM_LINK_UP、CORE_LINK_OK、RX/TX_READY、CPU_RESET_N。

但 `vendor/wrpc-sw/include/hw/wrc_diags_regs.h` 定義：

```text
WRC_DIAGS_CTRL offset = 0x4
CTRL_DATA_VALID = 0x1
CTRL_DATA_SNAPSHOT = 0x100
```

也就是 `0x00100A04` 是WDIAGS CTRL。它不是PHY status。`PSTAT`在offset0xC，bit0是port link、bit1是locked；PSTAT_RAW=1提供另一項port-link指示，但不能取代直接PHY所有條件。

真正上述PHY位元來自 `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd` 的 `sync_probe(15 downto 0)`，`u_wr_sync_probe` instance index=0，64-bit `WR_SYNC_SLAVE`；Master也必須核對對應top。現有 `read_step5_startup_timeline_first_divergence.tcl` 使用 `set status [probe_read 0]` 後才解碼這組位元。

所以F4G的 `CPU_RESET_N=0` 也只是錯解碼，不可當真CPU持續reset。Main持续更新與reset計數穩定是背景反證，但決定性證據是source mapping。

**已確認的是reader語意錯誤，不是已確認真PHY為1。** 舊F4G沒有保存所需direct probe0狀態，就不能從CTRL=1重建真PHY。不要把舊92筆的PHY_LINK_USABLE批量改1、不要回溯升格phase-qualified、不要改舊INCONCLUSIVE為PASS。

## 4. 唯一允許修正

允許檔案：

- `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl`：F4G/F4H WR core資料來源及相關輸出。
- `scripts/experiment/step5_f4g_compact_progress_window.py`：新增明確source/schema檢查與F4H replay，不偷改舊版資料品質。
- `scripts/tests/test_step5_f4g.py`／本輪新增tests；本輪docs。

不得修改production C/RTL、PI/gain/boost、threshold、timeout/retry、bootstrap、arbiter、mailbox、reset、identity、build target。禁止同時「順便改善」其他控制功能。

### 4.1 Reader具體規格

1. 將原0x00100A04值明確命名 `WDIAGS_CTRL_RAW`，只解碼DATA_VALID／診斷一致性，不作PHY gate。
2. 在既有active source-probe context中讀instance0，保留完整64-bit `PHY_STATUS_PROBE0_RAW`、source ID、role/cable、host_start/end。沿用已驗證`probe_read`，不直接另造transport。
3. 依兩板實際VHDL mapping解碼低位，完整保留bit15 CPU_RESET_N及高32的RX locked-to-data等背景。不可將64-bit整數轉十進位字串再當hex解析。
4. 新增 `PHY_STATUS_VALID` 與`PHY_STATUS_SOURCE=JTAG_PROBE0`；各必要位元與 `PHY_GATE_FAILURE_BITS` 逐項輸出。讀取TIMEOUT/parse錯是UNKNOWN，不是確定link down；UNKNOWN不可通過gate。
5. 先保留09/F4G原本的六個PHY必要條件（SI_CONFIG_DONE、WR_READY、TM_LINK_UP、LINK_OK、RX_READY、TX_READY）不變，只替換正確來源。不要降低位元要求。若audit發現條件本身另有語意問題，列出後停止審核，不同輪再改。
6. `PSTAT_LINK`、`PSTAT_LOCKED`與PHY gate各自輸出；不因PSTAT_LINK=1就代填其他條件。CTRL valid亦不是整組WR原子性的證明。
7. 保留WR state、disable、generation/reset檢查。若資料有效／frame條件不足，WR_CORE_VALID=0，不能因PHY來源修好就放寬其餘條件。

Reader只有這個host來源修正是本輪變因；其他Main/Helper CORE、計數器支持區間、Master背景與採樣模式保持原樣，便於比較。

### 4.2 Tests先通過才部署

- CTRL=1而probe0 link bits=0：不能判PHY usable。
- CTRL=1、probe0六必要bit皆1：按原predicate可判PHY usable；CPU reset等仍各自保存。
- probe0六個必要bit逐一清零：每個case都不通過，原因指到該bit。
- CTRL=0且probe0 ready：物理位元可讀為1，但診斷資料有效性另列，不能偽造WR core有效。
- probe0 timeout、非hex、少位數/格式不符：UNKNOWN，不偽造0或1。
- 64-bit高位非零仍正確解低16與高位；Master/Slave source ID不能串台。
- 舊raw僅含STATUS_RAW=CTRL：新replay標 `PHY_SOURCE_NOT_CAPTURED`，不得回溯升格。
- phase=0仍阻止Step5 PASS；corrected PHY gate只允許diagnostic acquisition，不等於closed-loop。

source mapping表列每個欄位的介面（WB/direct probe）、位址/instance、位寬、mask與producer source。尤其不要再把「同名status」視為同一register。

## 5. Laptop→Pain→capture

Laptop完成host修正/tests/source-diff→push；Pain exact pull→clean build/program；單reader觀測；raw回Laptop→replay/report→push→停止。functional diff包含 `vendor/wrpc-sw firmware quartus rtl`。

正確target固定 `quartus/jtag_runtime_diag`：

- Master `DE5 [1-11.1] / DE5a_wr_master_jtag`，`scripts/pain/pain_build_jtag_master.sh`、`pain_program_jtag_master.sh`。
- Slave `DE5 [1-11.2] / DE5a_wr_slave_jtag`，`scripts/pain/pain_build_jtag_slave.sh`、`pain_program_jtag_slave.sh`。

部署前確認instance0的WR_SYNC身分、mailbox及52..61，記錄source/observer/image commit、SOF SHA256、實際program路徑與timing。禁用rs422。保留Master→Slave流程，不自行斷電、不補mode/reinit。

所有參數沿用：candidate0/0、Main+300/+1/boost20、Helper-2250/-2、guard8s、Slave bootstrap3388、Master bootstrap disabled及其餘threshold/timeout/arbiter/reset原樣。capture期間只有只讀transport，不snapshot owner切換、不drain FIFO。

## 6. 有界觀測與停止

一次120秒，hard130秒，等待入口／retry均計入。保持F4G單reader與CORE/service cadence，Master約3秒背景；不再加另一支PHY reader。

新增啟動smoke：兩板各至少2筆正確instance0/raw/CTRL/PSTAT紀錄，確認decoder來源可追溯，不要求每個PHY bit必須為1才保存診斷。若PHY有效但為0，這是可診斷結果，不是reader故障。

- target/source ID錯、第二reader、generation/reset變動：立即保存停止。
- 核心transport錯連續3次，或10秒無可信Main/Helper/core：DATA_UNRESOLVED停止。
- 連續3筆可信Slave probe0顯示必要PHY bit不成立：保存失敗bit、PSTAT、WR、兩板背景後停止 `TRUE_PHY_GATE_NOT_MET`。不能繼續phase歸因，更不能改gate求過。
- PHY直接讀值與PSTAT/其他資訊矛盾：記錄時間與來源；不足判斷則 `LINK_EVIDENCE_CONFLICT`，不選有利欄位。
- current WR terminal/disable：最多2個確認frame後停止SESSION_ENDED，sticky起點已有另列。
- 合格入口後Helper连续3筆unlock/rail，Main frequency连续3筆失去、或Main producer10秒不前進：按09條件停止並保留證據。
- Phase尚未lock本身不提前停止；跑至120秒，不延長、不自動long。

phase-qualified仍要求可信WR acquisition、正確PHY usable、Helper locked/fresh、Main enabled/frequency/new producer、無terminal/reset。只修來源，不能用歷史PASS拼接入口。

## 7. 判定與真正下一步

- `PHY_SOURCE_FIX_CONFIRMED`：新的probe0來源正確且新gate隨真實位元判定；只是reader修正驗證，不是Step5。
- 若真PHY必要條件不成立：根據具體bit與兩板背景定位下一個只讀PHY問題，不調Main PI。
- 若PHY成立而WR失敗：報告WR/session邊界，不用PI誤差覆蓋它。
- 若至少3個合格10秒bin、Main/Helper各至少20fresh樣本、Main服務多窗確有進展但phase仍未lock：可支持 `MAIN_SERVICE_PROGRESS_WITHOUT_PHASE_LOCK`，並列phase誤差／detector趨勢、clamp、更新率、每個counter實際支持窗口。它排除的只是完全沒有服務，不是證明服務速率足夠或PI增益錯；下一份建議才選控制方向。
- gate/source修正後仍資料不足：INCONCLUSIVE，列缺口，不回頭放寬checker。

本輪不增加新的production變因，也不直接開始PI sweep。完成後詢問Astra，下一版11_Astra.md。

## 8. 報告勘誤及驗收

新增勘誤指出F4G `PHY_LINK_USABLE=0` 由WB CTRL錯套probe0 decoder而來，不能再稱為已證實「runtime物理連線down」。保留舊raw／hash與原replay結果，另建corrected-source schema，不覆寫原始證據。原Main phase/PSTAT未鎖與Step5未通過仍保留。

本輪資料夾存REPORT、manifest、mapping表、tests、raw/hash、新舊decoder fixture比較、per-bit gate統計、bins與counter support。僅stage本輪檔案，push後停止。

Step5仍需有效兩板WR session、完整Helper/Main frequency/phase/Main/PSTAT/READY/tracking鏈、至少300秒fresh連續有效證據、無新增reset/delock/transaction failure、strict replay true、至少3次同基準fresh-program重現。120秒診斷不能滿足300秒closure；不降低threshold或改checker湊PASS。timing未closed揭露，未測外部clock品質不宣稱jitter/絕對精度；merge另需既定批准。

## 9. 證據索引

- `docs/experiments/exp-step5-softpll-lock/EXP-S5-F4G-COMPACT-HELPER-MAIN-SERVICE-WINDOW-20260915/REPORT.md`、`manifest.json`、`helper_source_contract.md`。
- 同資料夾 `raw/attempt-3708d85-f4g-jtag-runtime/observer.log` 及 `analysis/replay-3708d85-f4g-jtag-runtime/`。
- `scripts/jtag/read_step5_main_frequency_prelock_observability.tcl::f4g_emit_wr_core`（錯誤來源）。
- `vendor/wrpc-sw/include/hw/wrc_diags_regs.h`（CTRL/PSTAT語意）。
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd::sync_probe/u_wr_sync_probe`；Master同target對應mapping須驗證。
- `scripts/jtag/read_step5_startup_timeline_first_divergence.tcl`（probe0正確來源先例）。

本次全文讀報告/manifest及相關source，完整raw經replay逐record核對，未操作硬體或實作reader修正。PHY来源錯誤已有source證據；實際PHY狀態仍需新的正確讀取。
