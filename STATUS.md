# DE5a White Rabbit 目前狀態

最後更新：2026-08-17

本文件描述 `exp/jtag-runtime-observability` 研究分支的現況。`main` 仍保留穩定 baseline，不在本次文件更新中修改。

## Git 與可追溯性

- 研究分支：`exp/jtag-runtime-observability`
- 目前已燒錄並完成觀測的操作：Master 維持 `5e816ea` image；Slave 最新燒錄為 `b490a5d`
- 目前工作樹：已完成 Slave DCO load toggle CDC 的 compile、燒錄與 60 秒 JTAG 觀測
- 最新文件與實驗紀錄：`docs/experiments/EXP-WRPC-DCO-CDC-SLAVE-20260817.md`
- GitHub：`git@github.com:t5512355123/WR.git`
- pain 工作副本：`/home/b10504072/04_WR`
- 所有新建置都必須從 GitHub fetch/checkout 明確 commit 後執行。

### 2026-08-17 raw helper 飽和唯讀觀測

- 使用現有 bitstream、同一 JTAG session 讀取 BEGIN/END raw registers，沒有寫入控制暫存器。
- Master/Slave 的 `TAG_VALID`、`TRR_WRITE`、`TAG_SOURCE`、`REF`、`FEEDBACK` 都在 1 秒內增加，表示 raw tag path 有活動。
- Slave `HELPER_ERROR=+150000`、`HELPER_OUTPUT=5`；Master `HELPER_ERROR=-150000`、`HELPER_OUTPUT=0xFFFB`，兩端都在 helper 邊界且 `PSTAT.bit1=0`。
- 這次沒有改變硬體、沒有重新 compile、沒有燒錄；完整紀錄：`docs/experiments/EXP-WRPC-HELPER-SATURATION-OBS-20260817.md`。
- 下一個單一變因候選是修正 SI5340 runtime page/register 序列；在 compile、hash、燒錄與 runtime 證據完成前，不把它寫成已證明根因。

### `5e816ea` SI5340 runtime page/register A/B

- 只把 runtime I2C 序列改成 `page 3 -> 0x39 -> page 0 -> 0x1D`，Master/Slave 均以 Quartus 17 compile、fit、燒錄成功。
- Master SOF checksum：`0x30A4AB2F`；Slave SOF checksum：`0x30A38097`。
- 60 sample runtime session 中，Slave raw tag/TRR counters 持續增加，但 `HELPER_ERROR=-150000`、`HELPER_OUTPUT=0xFFFB`、`PSTAT.bit1=0`、`time_valid=0`；最後 sample 僅 `pps_valid=1`。
- 結論：page/register 修正本身不足以完成同步；完整紀錄：`docs/experiments/EXP-WRPC-SI5340-PAGE-20260817.md`。
- 下一個單一變因改查 DAC load request 的 clock-domain crossing，不能與 PHY 或 DMTD wiring 同時修改。

### `b490a5d` Slave DCO load toggle CDC A/B

- 只修改 Slave top：`clk_sys_625` 的 DCO load pulse 先轉為 toggle/held-data，再同步到 `CLK_50_B2J`；Master 不修改、不重燒。
- pain 以明確 commit `b490a5d` 編譯成功：Full Compilation successful，0 errors、271 warnings；timing_closed=NO。
- Slave SOF SHA-256：`30b9e62380508e111b011cd8d0d74a2ab029313c65b65af398918b5952762be4`；programmer checksum：`0x30A245FB`；configuration succeeded。
- 燒錄後 60 秒 JTAG：Slave tag/IRQ counters 持續增加，但 `HELPER_ERROR=-150000`、`PSTAT.bit1=0`、`SSTAT=1`、`time_valid=0`；沒有完成同步。
- 結論：本輪未觀察到 CDC 修正改善 SoftPLL；下一步先增加 DCO transaction/ACK/step 的唯讀觀測，不直接再改 PHY。
- 完整紀錄：`docs/experiments/EXP-WRPC-DCO-CDC-SLAVE-20260817.md`。

最近一次有效燒錄的 source 變因是 `9f848ec` 的 Master 啟動命令修正；`18614cf`、`f4b7e79` 是前一輪唯讀診斷，`d82cf9c`、`5a4def7`、`dba7d9b`、`2f1389c`、`6bff5d1`、`44ca8cf`、`b23a452`、`98c9ddb`、`3218b55`、`99bbc3c`、`7467e46` 與 `bae06ff` 都只追加實驗紀錄、Git 治理或唯讀觀測工具，沒有修改已燒錄的 WR 功能。

### Slave 重新初始化實驗

- 在 Master 已正確進入 `WDIAGS_MODE=2/PPS=6` 後，只重新燒錄既有 Slave SOF，沒有重新 compile 或修改 source。
- Slave SOF checksum：`0x309FCFD1`；configuration succeeded、0 errors、0 warnings。
- Slave 重新進入 `WRS_S_LOCK`，但約一分鐘後以 `WDIAGS_RESTART=0x02020001` 回報 `WR_SLAVE/WRS_S_LOCK` 失敗。
- Slave `PSTAT.locked=0`、`time_valid=0`；Master 維持 status `0xFF`。
- 結論：啟動順序/狀態殘留會影響 handshake 是否重新開始，但目前真正未通過的是 Slave SoftPLL lock。
- 完整紀錄：`docs/experiments/EXP-WRPC-SLAVE-REINIT-20260817.md`。

### `9f848ec` Master 啟動流程實驗

- 只修改 Master `CONFIG_INIT_COMMAND`，移除會阻塞啟動流程的 `sfp match`。
- Master build 成功，MIF SHA-256：`9829fb3e346d16a25865698a033eb883a54c1e7e52c00238165dac680f62b6ff`。
- Master SOF checksum：`0x30A3010A`；只燒錄 Master，configuration succeeded。
- 兩次 JTAG 讀值均為 Master `WDIAGS_MODE=2`、`WDIAGS_PTP=6`、status `0xFF`。
- Slave 仍為 `WDIAGS_MODE=3`、`WDIAGS_PTP=9`、status `0xCF -> 0xEF`；`UCNT/CKO` 有活動，但 `PSTAT.locked=0`、`time_valid=0`。
- 結論：Master 角色啟動問題獲得局部修正，但雙板 WR 時間同步尚未完成。
- 完整紀錄：`docs/experiments/EXP-WRPC-MASTER-INIT-20260817.md`。

### `5483669` 實際燒錄後狀態

- Master SOF checksum：`0x30A0A429`；Slave SOF checksum：`0x30A5A091`。
- Master 曾送出 `LOCK`；Slave 成功收到 `LOCK` 並回送 `SLAVE_PRESENT`。
- Slave sticky 診斷為 `fail_role=2`、`fail_state=2`、`fail_count=1`，即失敗前為 `WR_SLAVE/WRS_S_LOCK`。
- Master 停在 `WRS_M_LOCK`；Slave 失敗後回到 `WRS_IDLE`、`PP_PDSTATE_FAILURE` 與 PTP fallback。
- Master 的 `time_valid=1`；Slave 的 `time_valid=0`，尚未證明兩端完成 WR 時間同步。
- 完整紀錄：`docs/experiments/EXP-WRPC-JTAG-RUNTIME-20260816.md` 的 `EXP-WRPC-SIGNALING-20260816`。
- 下一輪的 `locking_poll/SoftPLL` 計數與 `seq_state` shadow 尚未 compile、燒錄或做板端實驗。

## 硬體限制與固定條件

- 兩張 DE5a，各自以獨立 JTAG 連接 pain。
- 兩張 DE5a 都以 PCIe 連接 pain。
- QSFP-A lane 0 是目前唯一的 WR timing link。
- QSFP-B/C/D 暫不參與 bring-up。
- 不新增 RS422、Common Reset 或 Common START。
- PHY、lane、polarity、line rate、reference clock 與 PTP 演算法在目前診斷階段固定不變。

## Gate 進度

| Gate | 內容 | 狀態 |
|---|---|---|
| 0 | Git、可重現建置與 artifact provenance | 已完成 |
| 1 | DE5a、Quartus 17、JTAG programming | 已完成 |
| 2 | QSFP-A lane 0 PHY/PCS link | 已完成；status low 16-bit 為 `0x82CF` 基線 |
| 3 | uRV CPU 執行 | 已完成；兩片 `fault=0`、`im_valid=1` |
| 4 | wrpc-sw boot/runtime | 已完成；兩片 marker `0xB004 seen=1` |
| 5 | PTP Master/Slave traffic | 已完成；RX/TX counters 持續增加 |
| 6 | Master/Slave unique node identity | 已完成；MAC 已分離 |
| 7 | Slave foreign/parent 與 servo activity | 已觀察到 activity，仍需更完整 parent 證據 |
| 8 | Master `time_valid=1`、`pps_valid=1` | 已觀察到 |
| 9 | Slave `pps_valid=1` | 已觀察到 |
| 10 | Slave `time_valid=1`、`TRACK_PHASE`、SoftPLL lock | 尚未完成 |
| 11 | 長時間同步穩定性 | 尚未開始 |
| 12 | TX/RX delay calibration 與外部 PPS 量測 | 尚未開始 |
| 13 | `execute_at(T)` scheduler | 尚未開始 |
| 14 | 雙 FPGA accelerator 同步啟動 | 尚未開始 |

## 最近一次燒錄後 runtime 證據

### `18614cf` SoftPLL IRQ count 唯讀診斷

- Master/Slave 以 Quartus 17.0 Build 595 compile 成功並實際燒錄；programmer 均回報 configuration succeeded、0 errors、0 warnings。
- Master checksum：`0x30ABDD91`；Slave checksum：`0x30A5A13F`。
- JTAG session 完成；Master accepted 57/60、Slave accepted 60/60。
- 所有 frame-valid activity rows 的 `IRQ_COUNT` 都是 `0x00000000`；Slave 仍為 `spll_locked=0`、`time_valid=0`、`LAST_STATE=9`。
- 完整紀錄：`docs/experiments/EXP-WRPC-IRQ-ACTIVITY-20260817.md`。

### `f4b7e79` 時鐘域活動唯讀診斷

- Master/Slave 均以 Quartus 17.0 Build 595 compile 成功並實際燒錄；programmer 均回報 configuration succeeded、0 errors、0 warnings。
- Master checksum：`0x30ABDD91`；Slave checksum：`0x30A5A13F`。
- 60 秒 JTAG session 完成；Master accepted 55/60、Slave accepted 60/60。
- QSFPA reference、QSFPB DMTD、recovered RX 三個 activity counter 皆持續變化，表示 clock domain 有活動。
- Slave 仍為 `link_up=1`、`wr_mode=3`、`spll_locked=0`、`time_valid=0`、`LAST_STATE=9`；因此尚未完成 WR synchronization。
- 完整紀錄：`docs/experiments/EXP-WRPC-CLOCK-ACTIVITY-20260816.md`。

來源：`c88cc05` clean Quartus 17 build，燒錄後等待約 60 秒讀取兩片 JTAG。

### Master

- MAC：`02:00:22:33:44:01`
- `WDIAGS_MODE=2`
- `WDIAGS_PTP=6`
- status low byte：`0xFF`
- 目前 probe mapping 顯示 `time_valid=1`、`pps_valid=1`
- `WDIAGS_PTP_RX=0xB4`、`WDIAGS_PTP_TX=0x18D`

### Slave

- MAC：`02:00:22:33:44:02`
- `WDIAGS_MODE=3`
- `WDIAGS_PTP=9`
- status low byte：`0xEF`
- `pps_valid=1`，但 `time_valid=0`
- `WDIAGS_FOREIGN_META=03000001`
- `WDIAGS_DMS_L=0007594B`
- `WDIAGS_CKO=023A7EE1`
- `WDIAGS_UCNT=0000000A`
- PTP counters 持續增加，CPU 沒有 fault。

完整原始輸出保存在 pain：

```text
/home/b10504072/04_WR/build/artifacts/unique_mac_clean_c88cc05/runtime_after_program_68s.log
```

這些證據支持「唯一身份已生效、PTP traffic 正常、Slave servo/parent 路徑已有活動」，但不足以宣稱兩端已完成 White Rabbit 時間同步。

## 建置與 timing 注意事項

- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`
- Master/Slave build script 在 compile 前執行 `quartus_sh --clean`，避免 stale SOF。
- 最近建置的 timing closure 仍為 `NO`；負 slack 與 unconstrained clocks 是獨立的 timing 工作，不與目前 servo bring-up 混改。
- 每個新 artifact 必須保存：Git commit、branch、Master/Slave MIF SHA256、QSF/SDC SHA256、SOF SHA256、Quartus 版本、programmer checksum、JTAG 原始輸出。

## 最新燒錄實驗：SoftPLL EIC 狀態唯讀診斷

- 實驗 ID：`EXP-WRPC-EIC-ACTIVITY-20260817`
- Git commit：`a5d19aec68b031c018b4e50407cb9d932cf6af7e`
- Master/Slave 均以 Quartus 17.0 Build 595 compile 成功並實際燒錄；programmer 均回報 configuration succeeded、0 errors、0 warnings。
- Master checksum：`0x30ABDD91`；Slave checksum：`0x30A5A13F`。
- JTAG session 完成：Master accepted `53/60`、Slave accepted `60/60`，Tcl/SignalTap successful。
- 有效列的 `IRQ_COUNT=0`、`REF_COUNT=0`、`TAG_COUNT=0`、`VISIT_MASK=0x200`、`TRANSITIONS=0`、`LAST_STATE=9`。
- Slave 的 `IRQ_MASK=0x3E9`、`IRQ_STATUS=0x3E8`；依 source mapping，tag input 對應 bit 0 在取樣時沒有 pending status。
- Slave 仍為 `link_up=1`、`wr_mode=3`、`spll_locked=0`、`time_valid=0`；不能宣稱兩端完成 WR synchronization。
- 完整紀錄：`docs/experiments/EXP-WRPC-EIC-ACTIVITY-20260817.md`。
- 下一步只加入 raw tag/FIFO write event 唯讀診斷，以區分 tagger、FIFO write 與 EIC route；不先改 PHY 或 WR 控制參數。

## 已完成：唯讀 JTAG 伺服器時間序列

實驗 ID：`EXP-WRPC-SERVO-TIMESERIES-20260816`。本次使用 `dba7d9b` 的觀測腳本，沿用最近一次有效燒錄 `c88cc05` 的既有 SOF；沒有重新 compile、燒錄或修改 PHY、PTP filter、servo、SI5340。

- 每 1 秒讀取一次，連續 60 個 sample。
- Quartus STP 回報 Tcl script 成功，沒有 timeout、CPU fault 或 reset。
- Master：`SSTAT=0x00000000`、`PSTAT=0x00000001`、PTP=6，status low 固定 `0x82FF`。
- Slave：`SSTAT=0x00000001`、`PSTAT=0x00000001`、PTP=9，status low 為 `0x82CF/0x82EF`；`time_valid=0` 全程未成立，`pps_valid` 不穩定。
- Slave `UCNT` 持續增加，DMS/CKO 有活動；foreign/parent mailbox 多數為有效值，但少數 sample 出現不一致或全零欄位。

### 目前判斷

依現行 register mapping，Slave 仍停在 `TRACK_PHASE` 之前，SoftPLL lock 尚未成立；證據不支持目前已進入「SoftPLL 已鎖定但 time_valid gating 阻擋」的階段。少數 mailbox 欄位不一致表示現有多 register JTAG 讀取不是原子 snapshot，parent flags 暫不能只依單列值下結論。

完整原始輸出：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SERVO-TIMESERIES-20260816/runtime_60samples.log
```

### 同一 JTAG session 交叉驗證

後續以 `6bff5d1` 的 `read_wb_timeseries_session.tcl` 重跑相同 60 秒 read-only 觀測。每張板只建立一次 source probe，並以 `CTRL_BEGIN/CTRL_END` 與 `FRAME_VALID` 標示可採信的資料列：

- Master：60 列，其中 58 列有效、2 列因 `CTRL_END=0` 被標為 invalid。
- Slave：60 列全部 `FRAME_VALID=1`。
- Slave 有效列仍維持 `SSTAT=0x00000001`、`PSTAT=0x00000001`，`time_valid` 仍未成立。

這表示重新建立 JTAG session 確實會增加觀測雜訊，但不是 Slave 尚未取得 SoftPLL lock 的唯一解釋。下一步仍只改善 mailbox frame 的重讀/一致性標記；在此之前不修改 PHY、PTP 演算法、servo 或 SI5340。

### retry 與 SoftPLL 欄位觀測結果

- `b23a452` retry 版本：Master 60 個 sample 中有 1 次 invalid attempt，重讀後接受；Slave 60/60 直接有效。所有 sample 的 `SSTAT` state field（`raw & 0xF00 >> 8`）仍為 0，Slave `PSTAT=0x1`。
- `98c9ddb` SoftPLL 唯讀欄位版本：兩張板各 60 個 sample，0 invalid、0 retry；`SPLL_CSR/ECCR/OCCR`、`WDIAGS_SPLL_HY/MY` 已納入輸出。Slave `PSTAT=0x1`、state field=0、`WDIAGS_SPLL_HY/MY=0`，仍沒有 lock 證據。
- 少數 `SPLL_CSR/ECCR` 跨列異常，表示 `CTRL.DATA_VALID` 不是跨多 register 的硬體原子 snapshot；後續必須用同一欄位重讀/一致性規則再解碼。

因此目前不進入功能修改，下一步是補上 SoftPLL register block 的重讀一致性統計與 bit-field 解碼。

### SoftPLL register block 雙讀結果

使用 `3218b55` 後，120 個 accepted sample 的 SoftPLL block 前後值全部一致為：

```text
SPLL_CSR=01010000
SPLL_ECCR=00000000
SPLL_OCCR=00000000
```

另有 7 次 `SPLL_BLOCK_VALID=0` 與 3 次 `CTRL_BEGIN/CTRL_END` 不一致；全部被 retry 丟棄，最終 120/120 sample 接受。這證明前一輪少數異常 SoftPLL 數值不能當作真實 lock/error 狀態。

依目前 source header，Slave 的 state field 仍為 0，`PSTAT=0x1` 仍只有 link bit；目前沒有 SoftPLL lock 或 `time_valid=1` 證據。

下一步應在相同的 valid-frame 機制下讀取 parent flags、PPS 與 servo transition，不應先修改 WR 功能。

### 父節點欄位雙讀結果

使用 `7467e46` 的 `PARENT_BLOCK_VALID` 後，兩張板各完成 60/60 accepted sample。Master 有 22 次 invalid attempt，Slave 有 13 次 invalid attempt；這些 frame 都由 retry 機制丟棄，沒有混入 accepted 統計。

accepted frame 的父節點欄位已穩定：

```text
Master: foreign=1, wr_config=0, parentIsWRnode=0,
        parentWrModeOn=0, parentCalibrated=0
Slave : foreign=1, wr_config=3, parentIsWRnode=1,
        parentWrModeOn=0, parentCalibrated=1
```

Slave 仍為 `SSTAT[11:8]=0`、`PSTAT.locked=0`、`time_valid=0`；因此目前最保守的判斷是 Slave parent/servo/SoftPLL 前段仍未完成，`parentWrModeOn=0` 只是下一步要查的線索，不是已證明的根因。完整原始 log：

```text
/home/b10504072/04_WR/build/artifacts/EXP-WRPC-SERVO-PARENT-BLOCK-20260816/runtime_60samples.log
```

## 最新燒錄實驗：SoftPLL locking 唯讀診斷

- 實驗 ID：`EXP-WRPC-LOCK-STATE-20260816`
- commit：`3ba9db83812da1cf61a917dafc8ff228c29043fe`
- branch：`exp/jtag-runtime-observability`
- Master checksum：`0x30A0A429`
- Slave checksum：`0x30A5A091`
- 燒錄：兩端 configuration succeeded，Quartus Programmer 0 errors、0 warnings。
- JTAG：兩張板各 60 個 accepted sample，STP Tcl evaluation successful。
- Slave：`locking_poll` 847885 次、未鎖定 847885 次、calibration failure 0 次、`seq_state=9 (SEQ_CLEAR_DACS)`、`SEQ_READY=8` 未出現；`time_valid=0`。
- 結論：問題目前最直接落在 Slave SoftPLL sequence/lock feedback 尚未達到 ready，尚未證明更底層根因。
- 原始 log：`build/artifacts/EXP-WRPC-LOCK-STATE-20260816/runtime_60samples.log`。

下一步是唯讀追蹤 `SEQ_CLEAR_DACS` 的進出條件、DAC clear/ack 與 channel/reference lock feedback；在新證據前不改 PHY、PTP、servo 或 SI5340 控制參數。

## 最新燒錄實驗：SoftPLL 硬體與 lock detector 觀測

- 實驗 ID：`EXP-WRPC-SPLL-HW-OBS-20260816`
- commit：`77f0f7de68ea88ca5baf4886b147daadedc63dcb`
- branch：`exp/jtag-runtime-observability`
- Master checksum：`0x30A0A429`
- Slave checksum：`0x30A5A091`
- 燒錄：兩端 configuration succeeded，Quartus Programmer 0 errors、0 warnings。
- JTAG：同一 bitstream 的 retry=8 補充取樣接受 Master 59/60、Slave 58/60，STP Tcl evaluation successful。
- Slave：`RCER=1`、`OCCR=0x101`、`seq_state=9 (SEQ_CLEAR_DACS)`、helper locked=0/lock_count=0、main enabled=0/locked=0、`calibration_fail=0`、`time_valid=0`。
- 結論：Slave 尚未通過 helper PLL lock，main PLL 尚未啟動；目前優先查 reference/tag input 到 helper lock detector 的路徑，尚未證明光路或特定 PHY 參數是根因。
- 原始 log：`build/artifacts/EXP-WRPC-SPLL-HW-OBS-20260816/runtime_60samples_retry8.log`。

下一步是加入 `softpll.ref_count/tag_count` 與 helper PI error/output 的唯讀觀測，以區分沒有 tag 和有 tag 但誤差超過 threshold。

## 2026-08-16 最新狀態：SoftPLL 活動唯讀觀測

- GitHub 實驗分支最新 commit：`180406824b1f4971b1bfbbbe947f5267c4568a8a`
- 本次已從 GitHub checkout 明確 commit，Master/Slave compile 成功，Quartus `17.0.0 Build 595`。
- 兩片 FPGA 均燒錄成功；Master checksum `0x30A0A429`，Slave checksum `0x30A5A091`。
- Slave 仍為 `link_up=1`、`time_valid=0`、`spll_locked=0`、`seq_state=9`。
- 新增唯讀欄位顯示 Slave `REF_COUNT=0`、`TAG_COUNT=0`、`VISIT_MASK=0x00000200`、`TRANSITIONS=0`、`LAST_STATE=9`；目前沒有「helper 已收到 tag 但誤差過大」的證據。
- 本次 JTAG session 因 300 秒外層 timeout 未完成兩片各 60 個樣本：Master 55/60 accepted，Slave 到 sample 48，沒有 `SESSION_TIME_SERIES_DONE`。因此只列為「燒錄成功、取樣不完整」，不宣稱完整 60 秒實驗。
- 原始 log：`build/artifacts/EXP-WRPC-SPLL-ACTIVITY-20260816/runtime_60samples.log`，SHA256 `a774d75e99006d9626e8f571a1e17f6ac3b33db108594b9de61948f911b90bed`。
- 下一步：沿用同一 bitstream 做較長 timeout 的唯讀重測；不修改 PHY、PTP、servo、SoftPLL 控制或 SI5340。

### 同一 bitstream 的完整唯讀重測

- 沿用硬體 commit `180406824b1f4971b1bfbbbe947f5267c4568a8a`，沒有重新 compile 或燒錄。
- 600 秒外層 timeout 下，JTAG session 完成：`JTAG_RC=0`、`SESSION_TIME_SERIES_DONE`、Tcl/SignalTap 均 successful；總耗時 5 分 44 秒。
- Master accepted `59/60`、Slave accepted `58/60`；rejected 列由前後 mailbox 不一致規則排除。
- Slave 所有 accepted activity 列一致為 `REF_COUNT=0`、`TAG_COUNT=0`、`HELPER_ERROR=0`、`HELPER_OUTPUT=0`、`VISIT_MASK=0x200`、`TRANSITIONS=0`、`LAST_STATE=9`。
- Slave 仍為 `link_up=1`、`spll_locked=0`、`time_valid=0`；證據把優先懷疑維持在 recovered clock/tagger 到 SoftPLL helper lock 的路徑，但尚未證明物理光路根因。
- 完整 log：`build/artifacts/EXP-WRPC-SPLL-ACTIVITY-READONLY-20260816/runtime_60samples.log`，SHA256 `9252c96c9ce4ece0947ad25bda019cca13bf3c91d5039abe91cca2f11f1916ab`。
## 最新燒錄實驗：DCO transaction pipeline 唯讀觀測（2026-08-17）

- 實驗 ID：`EXP-WRPC-DCO-OBS-20260817`
- commit：`c5092ddb343a2fa50a9349468759d0cf9317b1b5`
- 只重新燒錄 Slave；Master 沿用 `5e816ea` baseline。
- Slave compile：Quartus 17.0，Full Compilation successful，0 errors、273 warnings；timing 尚未閉合，worst setup `-0.163 ns`、hold `-3.490 ns`。
- Slave SOF SHA-256：`391c5c245fa53da75e685d9c4dc963f225d2aea58ce8c7d69faa490b88c1dcb1`，programmer checksum `0x30A53A47`，configuration succeeded。
- HPLL source/destination count 可對上；但 accepted 固定 `0x0378`、done 為 `0`，DPLL accepted/done 皆為 `0`。
- 20 秒 runtime 中 PTP、parent、tag、IRQ、UCNT 有活動，但 Slave `PSTAT.locked=0`、`time_valid=0`。
- 結論：尚未同步；目前優先查 DCO runtime I2C start handshake 是否因單週期 pulse 被慢速 I2C state machine 遺失。
- 完整紀錄：`docs/experiments/EXP-WRPC-DCO-OBS-20260817.md`。
## 最新燒錄實驗：DCO I2C 啟動握手修正（2026-08-17）

- 實驗 ID：`EXP-WRPC-DCO-START-HANDSHAKE-20260817`
- commit：`af4a96061bcd68cb9c0f5d7a51025bc2a05286c4`
- Slave compile 與燒錄成功；SOF checksum `0x30A34B86`。
- DCO 短讀從 baseline `done=0` 變成 HPLL `done=2`、DPLL `done=1`，證明 start handshake 使 transaction 完成。
- 但後續 20 秒 Slave 的 PTP、tag、IRQ、UCNT 與 parent activity 掉到 0，後段 `link_up=0`，`time_valid=0`。
- 結論：這不是成功修正；transaction 的實際 SI5340 寫入可能破壞 clock/runtime，下一步先回到可運作 baseline 並查 page/register/readback/clock effect。
- 完整紀錄：`docs/experiments/EXP-WRPC-DCO-START-HANDSHAKE-20260817.md`。
## 最新燒錄實驗：恢復 DCO 觀測 baseline（2026-08-17）

- 實驗 ID：`EXP-WRPC-ROLLBACK-DCO-20260817`
- pain 已 checkout `c5092dd` 並重新編譯、燒錄 Slave；SOF checksum `0x30A53A47`，configuration succeeded。
- rollback 後 Slave 的 PTP/tag/IRQ activity 恢復；但 `PSTAT.locked=0`、`time_valid=0`，因此只是恢復 baseline，不是同步成功。
- 下一步維持此 baseline，先離線核對 SI5340 runtime page/register/ACK/readback，再決定是否重新燒錄。
- 完整紀錄：`docs/experiments/EXP-WRPC-ROLLBACK-DCO-20260817.md`。
