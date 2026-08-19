# EXP-WRPC-STEP4-RESTORE-DDMTD-20260820

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-RESTORE-DDMTD-20260820`
- 日期：2026-08-20（Asia/Taipei）
- 實驗名稱：恢復 c88 Step 2 預設 DDMTD 取樣方向並驗證 Master role
- Git branch：`exp/step4-softpll-enable`
- 燒錄來源 commit：`31f2b518ae45e7664f3307269a0d050fb5c1f630`
- 前一個實驗 HEAD：`d08cf8b`；前一輪結果見 `EXP-WRPC-STEP4-FRESH-HEAD-RETEST-20260820.md`
- 實驗狀態：**NOT PASS（Step 4 尚未完成）**

## 這次想驗證什麼

current HEAD 在前一輪 fresh program 後出現 Master=`MODE=3/PTP=4`、Slave 未建立完整 WR parent metadata。source audit 顯示 `c88cc05` 成功基準沒有 `g_softpll_reverse_dmtds`，而後續 commit `b927e87` 才在 Master/Slave WR core 加入：

```vhdl
g_softpll_reverse_dmtds => true
```

本輪只驗證移除此一個設定、恢復 WR core 預設 DDMTD 取樣方向後，是否能恢復：

1. Master=`WDIAGS_MODE=2`、`WDIAGS_PTP=6`。
2. Slave=`WDIAGS_MODE=3`、`WDIAGS_PTP=9`。
3. Slave foreign master / parent metadata 是否回到 `0x03000001`。
4. `LOCK_ENABLE`、SoftPLL sequence、UCNT 與 DCO request 是否開始活動。

## 相較 baseline 唯一修改

本機只修改兩個 top-level VHDL 檔案，而且是同一個功能變因：

- `quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd`
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd`

兩檔都移除 `g_softpll_reverse_dmtds => true`，回到未指定此參數的 c88 預設行為。沒有修改 Master/Slave startup command、PPSI/PTP algorithm、WR signaling、SoftPLL algorithm、PI gain、lock threshold、DDMTD algorithm、DCO gain 或 SI5340 control sequence。

## Build provenance

- Build host：`pain`
- Quartus：`Version 17.0 Build 595 04/25/2017 SJ Standard Edition`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master MIF SHA256：`bd5c1603e0b965995fb96107ef60c4c0c4de7d2241b537a0958485f2a0a49fd2`
- Slave MIF SHA256：`324132867cbad0312200c3b373d8ec5eec4969e89ffa46912b642e02d39723f9`
- Master SOF SHA256：`cbcf2455d2c5e140c9f2d1e4f17fb57128b923fd66f100f6091e19a3d33e79dc`
- Slave SOF SHA256：`a4b961bb53f6039b200dd52d9ae7d48d3acb0a15ffe4ec2f659314e7e846268e`
- Master compile：`Full Compilation was successful`，timing closed=`NO`
- Slave compile：`Full Compilation was successful`，timing closed=`NO`

build 與 compile 原始輸出保存在本目錄：

- `master_firmware_build.log`
- `slave_firmware_build.log`
- `quartus_jtag_master_compile.log`
- `quartus_jtag_slave_compile.log`

## 燒錄結果

使用 Quartus 17 Programmer，正確的 programming option 為 `p;/absolute/path/to.sof`。

| 節點 | Cable | Programmer checksum | 結果 |
|---|---|---:|---|
| Master | `DE5 [1-11.1]` | `0x30A5EF0D` | `Configuration succeeded`、0 errors、0 warnings |
| Slave | `DE5 [1-11.2]` | `0x30A4A104` | `Configuration succeeded`、0 errors、0 warnings |

完整 Programmer 輸出：

- `program_step4_dmtd_default_master_20260820.log`
- `program_step4_dmtd_default_slave_20260820.log`

## JTAG runtime 原始結果

燒錄後等待 60 秒，再執行 `scripts/jtag/read_wb_runtime.tcl`。使用現有的 `read_dco_state.tcl` 與 `read_hpll_helper_correlation.tcl` 做唯讀觀察；沒有寫入 JTAG source 或 WDIAGS snapshot 控制。

### Master

| 欄位 | 實測值 |
|---|---|
| CPU reset/fault/im_valid | `0/0/1` |
| boot marker | `B004`, seen=`1` |
| MAC | `02:00:22:33:44:01` |
| `WDIAGS_MODE` | `2` |
| `WDIAGS_PTP` | `6`（PPS_MASTER） |
| PTP RX/TX | `0x80 / 0x80` |
| MiniNIC TX/RX | `0x176 / 0xCC` |
| `WDIAGS_FOREIGN_META` | `0x0000FF00`（Master 不適用） |

### Slave

| 欄位 | 實測值 |
|---|---|
| CPU reset/fault/im_valid | `0/0/1` |
| boot marker | `B004`, seen=`1` |
| MAC | `02:00:22:33:44:02` |
| `WDIAGS_MODE` | `3` |
| `WDIAGS_PTP` | `9`（PPS_SLAVE） |
| PTP RX/TX | `0x121 / 0x69` |
| MiniNIC TX/RX | `0xD9 / 0x168` |
| `WDIAGS_FOREIGN_META` | `0x00000001`，尚未回到 `0x03000001` |
| `WDIAGS_SSTAT` / `WDIAGS_PSTAT` | `0x00000001 / 0x00000001` |
| `WDIAGS_UCNT` | runtime=`0x1`；helper correlation samples `0x2` 至 `0x5` |
| `LOCK_ENABLE` | `0x4` |
| `SPLL_STATE` | `0x00030009` |
| DCO `STEP` | `0` |

### DCO / helper observation

Slave `read_dco_state.tcl` 讀到 `DCO_STATE=0x220`：

```text
rt_state=0 bus_state=0 bus_done=0 ready=1 start=0 enable=0
dpll_load=0 hpll_load=0 error=0 busy=0 steps=0 hold=0
```

10 次、每次間隔 1 秒的 helper correlation 中，`LOCK_ENABLE=4`，`UCNT` 有增加；但 `REF=0`、`TAG=0`、`TAG_VALID=0`、`TRR_WRITE=0`、`HPLL_LOAD=0`、`STEP=0`，且 DCO state 沒有進入 bus transaction。這表示 SoftPLL/servo 入口已有部分活動，但尚未證明 correction request 已進入 SI5340 I2C transaction。

Master 的 DCO probe 在本實驗 bitstream 沒有 instance，`read_dco_state.tcl` 對 Master 顯示 `No In-System Sources and Probes instance was found`；這是觀測腳本對不存在的 Master DCO probe 的訊息，不代表 Master program 失敗。Slave DCO probe 讀取成功。

完整 JTAG 原始輸出：

- `jtag_runtime_step4_dmtd_default_20260820.log`
- `jtag_dco_step4_dmtd_default_20260820.log`
- `jtag_hpll_step4_dmtd_default_20260820.log`

## 同一 bitstream 的後續 focused 唯讀觀察

為了區分單點 snapshot 與持續 runtime 狀態，在同一份已燒錄的 `31f2b51` bitstream 上，再執行 `read_wr_handshake_focused.tcl 20 1000`。這沒有重新燒錄，也沒有寫入控制暫存器。

20 次 sample 的穩定結果：

| 項目 | Master | Slave |
|---|---|---|
| `wr_mode` | `2` | `3` |
| PTP role | `PPS_MASTER=6` | `PPS_SLAVE=9` |
| foreign count/best | `0/255` | `1/0` |
| parent detection / WR config | 不適用 | `0/3` |
| parent flags | 不適用 | `parentIsWRnode=1`, `parentWrModeOn=0`（有一筆 sample 為 1）, `parentCalibrated=1` |
| WR signaling RX/TX | `0x1000/0x1001` | `0x1001/0x1000` |
| WR signaling reject | 有變動，需另行分析 | `0/0` |
| local/next WR state | `0/0` | `0/0` |
| lock result / `spll_check_lock` | `0/0` | `1/0` |
| lock polls / enable count | `0/0` | `953195/4` |
| RCER | `0` | `1` |

因此在 source-defined mapping 下，Slave focused observation 已持續看到 `FOREIGN_META=0x03000001` 的等價欄位；初次 runtime snapshot 的 `0x00000001` 應視為 WR parent diagnostics 尚未完成本輪 refresh 的早期讀值，不能用來否定後續穩定結果。原始輸出：

- `jtag_wr_handshake_focused_step4_dmtd_default_20260820.log`

## Source / runtime 對照

source audit 顯示：

- `state-wr-present.c` 收到 Master 的 `LOCK` 後才會把 `wrp->next_state` 設為 `WRS_S_LOCK`。
- `state-wr-s-lock.c` 進入 `WRS_S_LOCK` 時才會呼叫 `WRH_OPER()->locking_enable(ppi)`。
- DE5a 的 `wrpc_spll_locking_enable()` 會執行 `spll_init(SPLL_MODE_SLAVE, ...)`、開啟 ptracker 並初始化 T24 calibration。

因此 `LOCK_ENABLE=4` 只能證明曾經有 enable 嘗試，不能代替目前 WR state 已進入 `WRS_S_LOCK` 的證據。focused 20 samples 的 Slave `local_state=0/next_state=0`，而 `parentWrModeOn` 僅有一筆 sample 為 1、其餘為 0；目前第一個可觀察 blocker 是 WR signaling 沒有穩定完成 `WRS_PRESENT -> WRS_S_LOCK`，所以後續不應先把問題歸因到 DCO I2C controller。

## Observation

1. 移除反向 DDMTD 設定後，Master 從前一輪的 `MODE=3/PTP=4` 恢復為 `MODE=2/PTP=6`；這支持 `g_softpll_reverse_dmtds => true` 是前一輪 Master role 失敗的優先可疑變因。
2. Slave 仍可進入 `PPS_SLAVE=9`，兩端 CPU、MAC、MiniNIC 與 PPSI PTP counters 都有活動，表示 endpoint、frame path 與 PTP packet path 仍在工作。
3. 初次單點 runtime snapshot 的 `FOREIGN_META=0x00000001` 在後續 20 秒 focused read 中被 source-defined 欄位 `foreign=1/0, detection=0, wr_config=3, parent=1/0/1` 修正解讀為已建立 `0x03000001` 等價狀態；這是讀取時序差異，不是硬體重新燒錄。
4. Slave `LOCK_ENABLE=4` 且 `UCNT` 在唯讀 observation 中增加，支持 SoftPLL enable/servo 入口不是完全 idle。
5. 但是 Slave `local_state=0`、`spll_check_lock=0`，DCO `STEP=0`、`HPLL_LOAD=0`、`BUSY=0`，而 `REF/TAG/TRR_WRITE` 沒有活動；目前不能宣稱 correction/DCO request 已成功送入 SI5340。

## Conclusion

本次實驗為 **NOT PASS**。

證據真正支持的內容：

- exact `31f2b51` fresh source/build/program provenance 成立。
- Master role 已恢復為 `MODE=2/PPS_MASTER=6`。
- Slave role 為 `MODE=3/PPS_SLAVE=9`，CPU、MiniNIC、PPSI counters 有活動。
- SoftPLL 入口有 `LOCK_ENABLE` 與 `UCNT` 活動。

證據不支持的內容：

- 尚未證明 WR signaling 已進入 current HEAD 所需的 `WRS_S_LOCK` / local state。
- 尚未證明 DCO request 進入 I2C bus 或完成任何 DCO step。
- 尚未證明 `PSTAT.locked=1`、`time_valid=1` 或完整 WR timing synchronization。

因此本輪已具備 Step 2 的 Endpoint/MiniNIC/PTP/foreign-master 證據，但不是 Step 4 PASS。第一個後續 blocker 已從「Master role 未進入 PPS_MASTER」收斂為「WR signaling 尚未進入 lock handoff，且 DCO request 尚未出現」。不應在這個證據下直接調整 PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法。

## Next Step

1. 保留 `31f2b51` 作為 Master role 已恢復的 A/B reference，不再重新發明 Master role switching。
2. 先用唯讀資料追查 Slave 為何只有 `FOREIGN_META=00000001`，並對照 source-defined `PARSE_META` / WR signaling reject 欄位；不要先改 SoftPLL 演算法。
3. 在 parent metadata 完整建立後，再以現有 `LOCK_ENABLE`、`SPLL_STATE`、`UCNT`、`REF/TAG/TRR_WRITE` 和 DCO state 判斷 Step 4 的第一個真正無活動節點。
4. 下一次若要燒錄，必須先在本機 commit/push，再由 pain checkout exact commit，並新增一份新的本目錄實驗紀錄。
