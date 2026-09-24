# EXP-WRPC-STEP4-FRESH-HEAD-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-FRESH-HEAD-20260820`
- 日期：2026-08-20（Asia/Taipei）
- Branch：`exp/step4-softpll-enable`
- Git HEAD：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- 實驗類型：exact HEAD fresh build、雙板燒錄與 Step 4 runtime audit
- 功能變因：沒有修改 White Rabbit functional RTL、PTP、SoftPLL、PHY、SI5340 或 DCO 行為；唯一操作變因是以 exact HEAD 重新產生 firmware/MIF/SOF 並燒錄

## 這次要驗證什麼

確認最新 branch HEAD 是否能在 clean firmware build、Quartus clean compile、fresh SOF 與雙板 program 後，重現 Step 3 並觀察 Step 4 事件鏈：

```text
WRS_S_LOCK
  -> locking_enable
  -> SoftPLL channel enable
  -> DMTD event
  -> tag/TRR/IRQ
  -> helper update
  -> main correction/DCO request
```

本階段不把 `PSTAT.locked=1` 或 `spll_locked=1` 當成必要條件；但必須看到 SoftPLL 已離開 disabled/idle，且 tag、TRR、helper 與 correction path 有持續活動。

## Build provenance

- pain checkout：`/home/b10504072/04_WR`
- pain build checkout：exact detached HEAD `51864b8`
- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- 編譯流程：Master/Slave firmware build，接著兩個 Quartus project 各執行 `quartus_sh --clean` 與 `quartus_sh --flow compile`

| 項目 | Master | Slave |
|---|---|---|
| Project | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| MIF SHA256 | `4eb3febc3f2a53f1e53ccac3b237118f89909f8dc4cc1cd0a90fb433dd79e21f` | `648bd967b38d05d7a705f9abbd98302bd637a271b9dcde1542f87a71ae3f972f` |
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| SOF SHA256 | `817fb471d9c144da21f473dbba64238a6799871e0f19e42a340eb851efa8b92a` | `0345fe837dc70a9e8c345b14011eadcff6cf9f9154800521bc7be9ef2a4de9fa` |
| Programmer checksum | `0x30A0C7B1` | `0x30A27099` |
| Fitter | Successful | Successful |
| Compilation | Full Compilation was successful | Full Compilation was successful |
| Timing closed | `NO`, worst setup slack `-0.158 ns` | `NO`, worst setup slack `-0.179 ns` |

韌體與編譯 metadata 原始檔：

- `build_info_master_20260820.txt`
- `build_info_slave_20260820.txt`
- `firmware_master_hashes_20260820.sha256`
- `firmware_slave_hashes_20260820.sha256`

## 燒錄結果

### 第一次命令嘗試

第一次命令把 `-o p;/path/to/file` 的分號交給遠端 shell 解讀，Quartus 回報：

```text
Programming option string "p" is illegal
bash: ...DE5a_wr_master_jtag.sof: Permission denied
```

該次沒有成功執行 programming operation，不能視為硬體燒錄結果。修正 shell quoting 後重新執行。

### 正確燒錄

Master：

- Cable：`DE5 [1-11.1]`
- Device：`10AX115N2F45@1`
- `Configuration succeeded -- 1 device(s) configured`
- `0 errors, 0 warnings`
- checksum：`0x30A0C7B1`

Slave：

- Cable：`DE5 [1-11.2]`
- Device：`10AX115N2F45@1`
- `Configuration succeeded -- 1 device(s) configured`
- `0 errors, 0 warnings`
- checksum：`0x30A27099`

原始 programmer output：

- [Master programmer log](./program_master_20260820.log)
- [Slave programmer log](./program_slave_20260820.log)

## Step 3 regression snapshot

燒錄後的 `read_wb_runtime.tcl` 顯示：

### Master

- `EP_MAC=02:00:22:33:44:01`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- `WDIAGS_PTP_RX=0x18`
- `WDIAGS_PTP_TX=0x33`
- CPU reset/fault/im_valid：`0/0/1`
- marker：`0xB004`, seen=1

### Slave

- `EP_MAC=02:00:22:33:44:02`
- 初始 `WDIAGS_PTP=8`，等待後進入 `WDIAGS_PTP=9`
- `WDIAGS_FOREIGN_META=03000001`
- `WDIAGS_PTP_RX`、`WDIAGS_PTP_TX` 非零
- CPU reset/fault/im_valid：`0/0/1`
- marker：`0xB004`, seen=1

因此 fresh HEAD 沒有破壞 Step 2/3 的 Endpoint、MiniNIC、PTP、Master/Slave role 與 Foreign Master discovery。

## Step 4 JTAG 原始結果

### 30 秒 runtime-context

Master 多數樣本：

- `LOCK_ENABLE=0`
- `OCER=1`, `RCER=0`
- `TAG_VALID=0`, `TRR_WRITE=0`
- `REF=0`, `TAG=0`, `IRQ=0`, `HELPER_UPDATE=0`
- `CURRENT_TICS` 持續增加

Slave 多數樣本：

- `LOCK_ENABLE=4`
- `OCER=1`, `RCER=1`
- `SPLL_STATE=00030009`
- `TAG_VALID=0`, `TRR_WRITE=0`
- `REF=0`, `TAG=0`, `IRQ=0`, `HELPER_UPDATE=0`
- `CURRENT_TICS` 持續增加

少數 mailbox 欄位出現孤立異常值，因此只採信跨樣本持續的趨勢，不用單一異常列做結論。

### 20 秒 HPLL/helper correlation

Slave：

- `UCNT` 大致由 `0x09` 增至 `0x10`，但夾有少數不可信的 `0` 或 `0x10000001`
- `TAG_VALID=0`, `TRR_WRITE=0`, `REF=0`, `TAG=0`, `IRQ=0`
- `HELPER_UPDATE_COUNT=0`
- `DAC_HPLL=0x01000000`, `DAC_MAIN=0x01000000`
- `DCO_DEBUG=0x0000000000000220`, `STEP=0`

Master：腳本假設存在 Slave 的 instance 8，因此回報 `No In-System Sources and Probes instance was found`；Master 的 mailbox runtime snapshot 仍可正常讀取，故不能把這個腳本 mapping 問題當成 Master 功能故障。

### 20 秒 direct DMTD

`read_step4_dmtd_minimal.tcl` 設定為 `trr_r0_read=disabled`，不消耗 TRR FIFO。觀察結果：

- Master `CURRENT_TICS` 持續增加，但 `REF_EVENTS=0x001C930B`、`FB_EVENTS=0x009E93C3` 幾乎固定，last tick 也幾乎固定。
- Slave `CURRENT_TICS` 持續增加，但 `REF_EVENTS=0x062E0278`、`FB_EVENTS=0x0621777B` 幾乎固定，`REF_STATE=0`、`FB_STATE=0`。
- `RCER=1`、`OCER=1` 並沒有伴隨新的 DMTD events。

### 追加：DMTD clock activity 與極簡 20 秒重測

為了區分「DMTD offset clock 沒有輸入」與「clock 有輸入但沒有形成 deglitch event」，在同一份 fresh SOF、沒有重新燒錄的前提下，先執行 instance 7 的 clock activity 唯讀觀測，再執行只讀 10 個欄位的極簡 DMTD confirmation。

clock activity 的 1 秒差分顯示兩張板的 `QSFPB_REFCLK/DMTD` 計數都在變化，且 `PHY_READY=1`、`RX_LOCK_DATA=1`：

```text
Master: REF 17242 -> 48237, DMTD 64787 -> 30215, RX 64474 -> 29932
Slave : REF 59142 -> 24510, DMTD 41941 ->  7279, RX 58848 -> 24217
```

16-bit counter 會 wrap，因此起點大於終點不代表沒有活動；這些數值支持 `QSFPB_REFCLK` 在取樣期間有活動，不能把「沒有 DMTD clock」當成已證明根因。

極簡 20 秒 confirmation 只讀 `CURRENT_TICS`、DMTD event counter、last-event ticks、DMTD state、reset bits、RCER/OCER、REF/FB tag counter，並停用 `TRR_R0` 讀取。結果是：

- Master：`CURRENT_TICS` 持續增加；`REF_EVENTS` 約固定在 `0x001C930B`、`FB_EVENTS` 約固定在 `0x009E93C3`；主要樣本 `REF_STATE=2`、`FB_STATE=0`、reset bits=0，tag counters 沒有持續增加。
- Slave：`CURRENT_TICS` 持續增加；`REF_EVENTS` 約固定在 `0x062E0278`、`FB_EVENTS` 約固定在 `0x0621777B`；主要樣本 `REF_STATE=0`、`FB_STATE=0`、reset bits=0，tag counters 沒有持續增加。
- 個別列的 `REF_EVENTS`、`RCER` 或 `TAG_REF` 出現跨欄位樣式的跳變，與既有 JTAG mailbox cross-read noise 一致；不把孤立列當作功能活動證據。

這次重測把第一個可觀察的 inactive boundary 保守收斂為：

```text
QSFPB_REFCLK 有活動
    -> dmtd_with_deglitcher / dmtd_event_sys 沒有 sustained new event
    -> tags_p / TRR / IRQ / helper / DCO 沒有 sustained activity
```

仍不能由此單獨判定是 DDMTD polarity、deglitch threshold、reset/resync、reference clock relationship、PHY 或 SI5340 的根因。

原始 JTAG output：

- [runtime snapshot](./jtag_runtime_snapshot_20260820.log)
- [30 秒 runtime-context](./jtag_step4_runtime_context_30s_20260820.log)
- [20 秒 HPLL/helper correlation](./jtag_step4_hpll_helper_20s_20260820.log)
- [20 秒 direct DMTD](./jtag_step4_dmtd_minimal_20s_20260820.log)
- [1 秒 clock activity](./jtag_clock_activity_20260820.log)
- [追加 20 秒極簡 DMTD 重測](./jtag_step4_dmtd_minimal_20s_retest_20260820.log)

追加 raw log SHA256：

| 檔案 | SHA256 |
|---|---|
| `jtag_clock_activity_20260820.log` | `01FECBF6D0107AA7F10C1486AB56380FA09E81A9FAED33A967E8D6671D138EA8` |
| `jtag_step4_dmtd_minimal_20s_retest_20260820.log` | `E0527802334C417C8E7CA7AE32DCB7AECB49354FC2BA9C83FB41712FDA6571DE` |

## Observation

目前 fresh HEAD 已排除「historical SOF 與最新 source/script 不一致」這個主要疑問。最新影像可以：

1. 正常啟動 CPU、Endpoint、MiniNIC、PTP。
2. 讓 Slave 找到 Foreign Master，並進入 `WDIAGS_PTP=9`。
3. 在 Slave 看到 `LOCK_ENABLE=4`、`RCER=1`。

但在 20～30 秒觀測中：

```text
DMTD event counter 不增加
    -> tag_valid 不形成連續活動
    -> TRR write / IRQ 不形成連續活動
    -> helper correction / main correction / DCO step 沒有證據
```

因此「SoftPLL enable call 已發生」與「SoftPLL 已開始以 DMTD feedback 工作」必須分開描述。

## Conclusion

本次 Step 4：**NOT PASS**。

證據真正支持的結論是：

- Step 2/3 fresh HEAD runtime 基本重現成功。
- Slave 的 SoftPLL enable 路徑至少留下 `LOCK_ENABLE=4` 與 `RCER=1`。
- 但 fresh image 的 direct DMTD event counter 沒有持續增加，且 Slave 仍在 `REF_STATE=0/FB_STATE=0`；目前第一個可證明的 inactive boundary 是 `dmtd_with_deglitcher -> dmtd_event_sys`，尚未進入可供 tag/TRR 消費的持續事件流。
- 尚不能只根據這些 register 宣稱根因是 DDMTD polarity、reference clock、threshold、PHY 或 SI5340；這些仍是假設。

## Next Step

在不改 PI、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法的前提下：

1. 先完成 source-only audit，對照 `dmtd_with_deglitcher.v`、`wr_softpll_ng.vhd`、top-level DMTD reference/feedback clock wiring 與已知成功 image 的 source/provenance。
2. 確認 DMTD reference 與 feedback clock 是否真的有 activity、reset 是否解除、兩邊是否使用正確的 125 MHz/62.5 MHz domain。
3. 若 source audit 找不到差異，再設計一次只改一個硬體觀測/clocking functional variable 的 A/B；變更前先 commit，並重新走 clean firmware build、Quartus clean compile、雙板 program 與本格式實驗紀錄。
4. 本次不合併 `main`，也不開始 Step 5 lock/convergence 修改。
