# EXP-WRPC-STEP4-DMTD-STATE-20260820

## 實驗基本資料

- 實驗日期：2026-08-20
- 實驗分支：`exp/step4-softpll-enable`
- 燒錄來源 commit：`e48393f841ee0e7ed96590bf7b471d8155a5c29e`
- 觀測腳本修正 commit：`ebe3e997bd94c38a6d64ace8af92be5b62fcc605`
- 實驗名稱：Step 4 SoftPLL deglitcher state 與 sequence 唯讀診斷
- 實驗性質：唯讀觀測；沒有修改 SoftPLL 控制行為、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340 演算法

本次實際燒錄的 SOF 是由 `e48393f` fresh build 產生。`ebe3e99` 只修正 JTAG Tcl 在讀值為 `TIMEOUT` 時的防呆顯示，修正發生在燒錄後，沒有重新編譯或改變 FPGA 行為。

## 想驗證什麼

Step 4 只確認：進入 WR lock enable 後，SoftPLL 是否真的離開 disabled/idle，並讓 DDMTD/tag、helper/main servo 與 correction/DCO request 路徑開始活動。

本輪特別觀察：

```text
WRS_S_LOCK
  -> locking_enable()
  -> spll_init()
  -> SoftPLL sequence
  -> DDMTD/deglitcher state
  -> tag/request/grant/TRR
  -> helper/main update
```

## 相較 baseline 唯一修改

相較前一個已燒錄版本，本次 `e48393f` 只加入 DDMTD deglitcher 的唯讀 state/reset shadow：

- `0x001002DC`：reference state、feedback state、兩個 DMTD reset-active bit。
- 這些訊號只同步到 Wishbone diagnostics，不回饋原本的 DMTD、tagger 或 SoftPLL state machine。

觀測腳本後續在 `ebe3e99` 加入 `TIMEOUT` 防呆，避免對非數值字串做位元運算。

## Build 與 provenance

- Quartus：17.0.0 Build 595
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`e642d4ffd8998e78c2df2e7a6c348056d8d4a81712aff6326ac4ed23bd9b23ec`
- Slave MIF SHA256：`c0eaf842f6a99f4408833f0fa060b0c9ca6412defa0f75a1915d70f93bfdff4d`
- Master SOF SHA256：`a0b62504aed2fef25ab4ca041961db6fd217ab410bc2e2806aa0f4a39c8fd6ad`
- Slave SOF SHA256：`bbe05c2b315c955d18b04772223cd3eb8a12dd3f68b4420a046545d692b9c00f`
- Master compile：PASS，`TIMING_CLOSED=NO`，worst setup `-0.148 ns`
- Slave compile：PASS，`TIMING_CLOSED=NO`，worst setup `-0.359 ns`

完整 build log、build info、MIF hash 與 SOF/MIF hash 清單保存在本資料夾。

## 燒錄結果

### Master

- JTAG cable：`DE5 [1-11.1]`
- Programmer checksum：`0x30A2896C`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：0 errors、0 warnings

### Slave

- JTAG cable：`DE5 [1-11.2]`
- Programmer checksum：`0x30A45AB1`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：0 errors、0 warnings

原始輸出：

- `program_jtag_master_state_20260820.log`
- `program_jtag_slave_state_20260820.log`

## JTAG runtime 結果

完整原始輸出：

- `jtag_step4_state_fixed_20260820.log`
- `jtag_step4_state_fixed_timeseries_20260820.log`
- `jtag_runtime_state_20260820.log`

### CPU、PHY、Endpoint 與封包活動

- Master：`reset=0`、`fault=0`、`im_valid=1`、marker `0xB004 seen=1`；`MODE=2`、`PTP=6`；PTP RX/TX=`0x000000FC/0x0000022A`；MiniNIC TX/RX=`0x000002E3/0x00000191`。
- Slave：`reset=0`、`fault=0`、`im_valid=1`、marker `0xB004 seen=1`；觀測當下 `MODE=3`、`PTP=8`、`FOREIGN_META=0x03000001`；PTP RX/TX=`0x000000A7/0x00000000`；MiniNIC TX/RX=`0x0000007F/0x000000D5`。
- status probe 的 raw 結果保存於 runtime log；本輪沒有看到 CPU fault 或 RX error 累積證據。

這些結果支持 firmware、Endpoint/MiniNIC 與部分 PTP path 在運作，但不等於 SoftPLL 已 lock，也不等於 `time_valid=1`。

### SoftPLL sequence 與 deglitcher

| 欄位 | Master | Slave |
|---|---:|---:|
| `LOCK_ENABLE` counter | `0` | `4` |
| `SPLL_STATE` | `0x00020009` | `0x00030009` |
| mode bits | `2`，free-running master | `3`，slave |
| sequence low 8 bits | `9`，`SEQ_CLEAR_DACS` | `9`，`SEQ_CLEAR_DACS` |
| DMTD state（主要觀測） | `0xA`：ref/fb=`GOT_EDGE/GOT_EDGE`，reset=`0/0` | `0xA`：ref/fb=`GOT_EDGE/GOT_EDGE`，reset=`0/0` |
| helper update count | `0` | `0` |

`SPLL_STATE` 的 sequence/mode mapping 來自目前 source：

- `SEQ_DISABLED=7`
- `SEQ_READY=8`
- `SEQ_CLEAR_DACS=9`
- `SPLL_MODE_FREE_RUNNING_MASTER=2`
- `SPLL_MODE_SLAVE=3`

因此，Slave 的 `LOCK_ENABLE=4` 證明 `wrpc_spll_locking_enable()` 曾被呼叫；`SPLL_STATE=0x00030009` 進一步顯示 SoftPLL 已初始化為 Slave mode，但目前仍停在 `SEQ_CLEAR_DACS`，還沒有證據顯示它進入 `SEQ_START_HELPER`、`SEQ_START_MAIN` 或 `SEQ_READY`。

### Event-chain time-series

10 次 time-series 中：

- DMTD event counters 為非零且 `seen=1`，但在觀測窗口沒有形成可持續的新增 event。
- `TAG_PENDING`、`TAG_GRANT`、`TAG_VALID`、`TRR_WRITE` 皆未顯示持續活動。
- `HELPER_UPDATE_COUNT` 維持 `0`。
- deglitcher 主要讀值為 `0x0000000A`；Master 有一次讀到 `0x00000000`，因此保留為一次觀測變化，不把它解釋成完整 state transition。

## Observation

1. 本次 fresh HEAD 的雙板 compile 與 programming 都成功，且 raw JTAG 可讀；所以問題不是 Quartus 產檔或 JTAG 燒錄失敗。
2. Slave 累積的 `LOCK_ENABLE=4` 與 `SPLL_STATE` mode=`3` 支持 `locking_enable()` 到 `spll_init()` 這一段確實曾經執行。
3. 主要 sequence 停在 `SEQ_CLEAR_DACS`，沒有觀察到進入 helper/main 啟動或 `SEQ_READY` 的證據；DMTD 只看到早期 event/state，沒有對應的 tag/request/servo 持續活動。
4. 目前觀測腳本已能把 `TIMEOUT` 顯示為 `NA`，不再把腳本解碼錯誤混成硬體錯誤。

## Conclusion

- Fresh firmware build：PASS。
- Fresh Quartus clean compile：PASS，但 timing 未 closed。
- 雙板 fresh SOF programming：PASS；兩片 configuration succeeded，0 errors、0 warnings。
- CPU/Endpoint/MiniNIC 基本 runtime：有證據顯示正在活動。
- Step 4 SoftPLL Enable：**NOT PASS**。

目前證據把第一個未觀察到活動的節點優先收斂到：

```text
locking_enable()/spll_init() 已發生
        ↓
SoftPLL sequence 應離開 SEQ_CLEAR_DACS
        ↓
目前尚未看到進入 SEQ_START_HELPER/SEQ_START_MAIN/SEQ_READY
```

這是「第一個沒有被證據支持的 transition」，不是已證明的根因。不能只依此結果宣稱 DAC、DDMTD polarity、arbiter、SI5340 或 SoftPLL 演算法本身故障，也不能宣稱已 lock。

## Next Step

1. 維持目前 bitstream 與 SoftPLL functional code 不變，做 read-only source audit，核對 `sequencing_fsm()`、`spll_update()`、timer tick、tag IRQ 與 `SEQ_CLEAR_DACS -> SEQ_START_HELPER` 的必要條件。
2. 讀取目前已有的 `INIT_COUNT`、`CLEAR_DACS_COUNT`、`LAST_INIT_TICS`、`LAST_CLEAR_TICS`、`CURRENT_TICS`，確認 sequence 是否只初始化一次、timer 是否持續前進。
3. 只有在 read-only 證據明確指出單一 functional variable 後，才另開獨立實驗；本輪不修改 PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 control。
