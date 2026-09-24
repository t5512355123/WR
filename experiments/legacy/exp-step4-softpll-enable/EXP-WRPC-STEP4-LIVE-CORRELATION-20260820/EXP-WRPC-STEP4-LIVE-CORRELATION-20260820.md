# EXP-WRPC-STEP4-LIVE-CORRELATION-20260820

## 實驗資訊

- 實驗名稱：Step 4 SoftPLL 事件鏈即時唯讀相關性觀測
- Experiment ID：EXP-WRPC-STEP4-LIVE-CORRELATION-20260820
- 日期：2026-08-20（Asia/Taipei）
- 研究分支：`exp/step4-softpll-enable`
- 本機 source HEAD：`5ceed6b28b555491deddb1be9ce32a77f6511235`
- pain 當時 checkout：`ebe3e997bd94c38a6d64ace8af92be5b62fcc605`
- 實驗性質：唯讀 JTAG runtime 觀測；本次沒有修改 RTL、firmware、PHY、PTP、WR signaling、SoftPLL 控制參數、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340 行為，也沒有重新燒錄 FPGA。

## 目的

確認 Step 4 的第一個沒有活動的節點，沿著下列路徑觀察同一份正在運作的硬體映像：

```text
DDMTD event
  -> tags_p
  -> tags_req
  -> tags_grant_p
  -> tag_valid / TRR write
  -> SoftPLL IRQ / helper update
  -> main correction / DCO request
```

本輪只回答「目前是否有事件進入這條鏈」，不把沒有 lock 解讀成演算法根因。

## 來源與 provenance

本次 JTAG 所讀取的 FPGA 映像沒有在本輪重新燒錄。根據先前已保存的實驗紀錄，現場映像是由 `e48393f841ee0e7ed96590bf7b471d8155a5c29e` 建立的 fresh SOF：

- Master SOF SHA256：`a0b62504aed2fef25ab4ca041961db6fd217ab410bc2e2806aa0f4a39c8fd6ad`
- Slave SOF SHA256：`bbe05c2b315c955d18b04772223cd3eb8a12dd3f68b4420a046545d692b9c00f`
- Quartus：Intel Quartus Prime 17.0 Build 595
- programmer checksum：沿用前一份 `EXP-WRPC-STEP4-DMTD-STATE-20260820` 的 programming log；本輪沒有重新執行 programmer
- provenance 來源：`EXP-WRPC-STEP4-DMTD-STATE-20260820.md`

因此，本紀錄不能被解讀成 `5ceed6b` 已經產生並燒錄新的 SOF；它是對現場 `e48393f` 映像的後續唯讀觀測。

## 實驗方法

在 pain 執行下列唯讀 Tcl script，沒有寫入 Wishbone 設定，也沒有讀取會消費資料的 `TRR_R0`：

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl
quartus_stp -t scripts/jtag/read_hpll_helper_correlation.tcl 20 1000
quartus_stp -t scripts/jtag/read_step4_runtime_context.tcl 10 1000
```

原始輸出保存在本資料夾：

- `jtag_runtime_live_step4_20260820.log`
- `jtag_hpll_helper_correlation_live_step4_20260820.log`
- `jtag_step4_runtime_context_live_20260820.log`

## Runtime 結果

### Step 1～3 基線沒有在本輪觀測中失效

| 項目 | Master | Slave |
|---|---:|---:|
| MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` |
| `WDIAGS_MODE` | `2` | `3` |
| `WDIAGS_PTP` | `6`（PPS_MASTER） | `9`（PPS_SLAVE） |
| CPU marker | `B004`, seen=1 | `B004`, seen=1 |
| CPU reset/fault/im_valid | `0/0/1` | `0/0/1` |
| `WDIAGS_FOREIGN_META` | `0000FF00` | `03000001` |
| PTP RX/TX | `0x4DE / 0xAD1` | `0x951 / 0x187` |
| MiniNIC TX/RX | `0xDD4 / 0x75B` | `0x6AC / 0xB67` |

這表示 Endpoint、MiniNIC、PPSI/PTP role 與 Slave foreign-master discovery 仍有活動。

### SoftPLL 事件鏈

Slave 的 20 次、每次間隔 1 秒的 correlation 觀測：

| 訊號/計數器 | 觀測結果 |
|---|---:|
| `LOCK_ENABLE` | `4` |
| `SPLL_STATE` | `0x00030009`，mode=3、sequence=9=`SEQ_CLEAR_DACS` |
| `RCER` | `1` |
| `TRR_CSR` | `0x00020000`，TRR empty |
| `REF` | 0（觀測窗口沒有新增） |
| `TAG` | 0（觀測窗口沒有新增） |
| `IRQ` | 0（觀測窗口沒有新增） |
| `TAG_VALID` | 0（觀測窗口沒有新增） |
| `TRR_WRITE` | 0（觀測窗口沒有新增） |
| `HELPER_UPDATE_COUNT` | 0（觀測窗口沒有新增） |
| `HELPER_STATE/ERROR/OUTPUT` | 全為 0 |
| DCO `STEP/HPLL_LOAD/BUSY/ERROR` | `0/0/0/0` |

`CURRENT_TICS` 持續增加，`INIT_COUNT` 在觀測期間沒有形成新的 re-init；這排除了「JTAG 讀取完全停止」這種解釋，但沒有證明 SoftPLL 已進入 helper/main tracking。

另外，runtime context 顯示 Slave 的 `RCER=1`、`OCER=1`、`LOCK_ENABLE=4`，所以 channel enable 與 `locking_enable()` 的歷史執行有證據；缺少的是後續實際 tag/TRR event。

## 結果判讀

### 已經支持的結論

1. Step 1～3 在這個現場映像上仍可觀察到：PHY/Endpoint 基線、MiniNIC counter、PTP RX/TX、Master/Slave role 與 Foreign Master 都存在。
2. Slave 曾執行 SoftPLL enable 路徑，因為 `LOCK_ENABLE=4`、`RCER=1` 且 `SPLL_STATE` mode 為 3。
3. 本次觀測的第一個沒有活動節點是在 `DDMTD/tag source -> tags_p/tags_req` 這一段之前或之中；後面的 TRR、IRQ、helper、main、DCO 沒有輸入事件，因此不能把後段當作第一個 blocker。
4. `SPLL_STATE=SEQ_CLEAR_DACS` 與 `TRR empty` 相互一致：sequence 沒有取得後續 tag 來走完 clear-DAC transition。

### 尚不能宣稱的內容

- 不能只憑這輪證明 DDMTD polarity 是根因。
- 不能只憑這輪證明光纖、Native PHY 或 PTP packet path 故障；Step 1～3 的 counter 與 role 仍有活動。
- 不能宣稱 SoftPLL 已 lock、Slave `time_valid=1` 或 Step 4 PASS。
- 不能把現場 `e48393f` 的結果標成 `5ceed6b` fresh SOF 的結果。

## Step 4 Gate

| Gate | 結果 | 證據 |
|---|---|---|
| SoftPLL channel enabled | PARTIAL/PASS（僅 enable 證據） | `LOCK_ENABLE=4`, `RCER=1` |
| sequence 離開 disabled/idle | FAIL | Slave 仍為 `SEQ_CLEAR_DACS=9` |
| DDMTD/tag/TRR/IRQ 有持續活動 | FAIL | 20 秒窗口 counters 無新增 |
| helper/main servo 有活動 | FAIL | `HELPER_UPDATE_COUNT=0`，main 未開始 |
| correction/DCO request 有活動 | FAIL | `STEP=0`, `HPLL_LOAD=0`, `BUSY=0` |
| Step 4 overall | **NOT PASS** | 第一個 blocker 收斂到 tag event 沒有進入 SoftPLL event chain |

## 下一步

1. 先保留本輪映像與紀錄，不用 `5ceed6b` 的文件 commit 假裝成現場 SOF provenance。
2. 下一個硬體實驗仍應只改一個 functional variable，並在 programming 前先 commit、clean firmware build、`quartus_sh --clean`、fresh Quartus compile，保存 MIF/SOF hash、programmer log 與 JTAG raw log。
3. 進行下一個 A/B 前，先確認是否允許重現歷史上 `g_softpll_reverse_dmtds=true` 的單一 Slave 變因；目前本 Step 4 規範仍禁止為追 lock 任意修改 DDMTD polarity，因此本紀錄不把它當作已批准的修正。
4. 在得到同一映像的 tag source 活動後，才繼續判斷 helper arithmetic、lock detector 與 DCO request；在此之前不修改 PI gain、lock threshold、DCO gain 或 SI5340 演算法。

