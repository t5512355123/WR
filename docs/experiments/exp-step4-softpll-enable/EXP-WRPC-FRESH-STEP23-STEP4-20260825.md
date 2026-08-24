# EXP-WRPC-FRESH-STEP23-STEP4-20260825

## 實驗識別

- 日期：2026-08-25
- 實驗名稱：exact HEAD fresh build、雙板 program 與 Step 2/3/4 runtime regression
- Git branch：`exp/step4-softpll-enable`
- Git commit：`b040d1bc98843a1175ac32767a6b05ff944a1887`
- 目的：確認目前 branch 的 exact HEAD 能否由 fresh firmware、clean Quartus compile 與 fresh SOF 重現 Step 2/3，並在 regression barrier 通過後觀察 Step 4 SoftPLL startup。

## 實驗限制

- 本次沒有修改 Master/Slave role switching、PTP、WR signaling、SoftPLL algorithm、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。
- 本次只使用 repository 既有 build script 與 read-only JTAG diagnostics。
- 本次使用 exact HEAD 重新產生 MIF/SOF；沒有使用 historical c88cc05 SOF 作為本次結果。

## Fresh build provenance

Quartus：Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition

### Master

| 項目 | SHA256 / 結果 |
|---|---|
| MIF | `f6ffe5f7a1189dbb3c12ecd087aab78eb904468cbe4e37b1ee6cf2328dd17347` |
| QSF | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` |
| SDC | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| SOF | `11283f5c14b55afa139e69876b654fcabf49615b587bdce6a250c3569969c837` |
| compile | Full Compilation was successful |
| timing | `TIMING_CLOSED=NO`, worst setup slack `-0.204 ns` |

### Slave

| 項目 | SHA256 / 結果 |
|---|---|
| MIF | `beb96f8ac9a77dae1b4919101efe6713e795e639ce7c6b64d551b16011971d96` |
| QSF | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| SOF | `9b197b432c3f1a44e832ba0d0da4b0a2adcccfde6abb9b647ebb210013070b63` |
| compile | Full Compilation was successful |
| timing | `TIMING_CLOSED=NO`, worst setup slack `-1.337 ns` |

完整 build 資訊位於 pain：

```text
/home/b10504072/04_WR/build/build_info_jtag_master.txt
/home/b10504072/04_WR/build/build_info_jtag_slave.txt
```

## FPGA program evidence

### Master：DE5 [1-11.1]

- SOF：`DE5a_wr_master_jtag.sof`
- Programmer checksum：`0x30B1B2ED`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`successful. 0 errors, 0 warnings`

### Slave：DE5 [1-11.2]

- SOF：`DE5a_wr_slave_jtag.sof`
- Programmer checksum：`0x30B3BC67`
- 結果：`Configuration succeeded -- 1 device(s) configured`
- Quartus Programmer：`successful. 0 errors, 0 warnings`

Master program wrapper 之後顯示 `test: unary operator expected`，這是遠端 shell 對 pipeline status 的檢查寫法問題；同一份 Programmer log 已明確顯示 configuration succeeded 與 0 errors，因此不把 wrapper 訊息判成 FPGA program failure。

原始 compile/program log：

```text
docs/experiments/exp-step4-softpll-enable/raw/20260825_fresh_b040d1b/step4_build_master_b040d1b.log
docs/experiments/exp-step4-softpll-enable/raw/20260825_fresh_b040d1b/step4_build_slave_b040d1b.log
docs/experiments/exp-step4-softpll-enable/raw/20260825_fresh_b040d1b/step4_program_master_b040d1b_20260825.log
docs/experiments/exp-step4-softpll-enable/raw/20260825_fresh_b040d1b/step4_program_slave_b040d1b_20260825.log
```

## Read-only runtime regression

Program 後等待約 25 秒，再執行下列 read-only scripts；所有 Tcl 結束時均為 Quartus SignalTap successful、0 errors、0 warnings：

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl
quartus_stp -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 25 500
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 30 500 25
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 50 100 events
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 50 100 mapping
```

### Step 1 / Step 2

兩板 dashboard 與 focused samples 均支持：

- Master：MAC `02:00:22:33:44:01`、MODE `2`、PTP `6`。
- Slave：MAC `02:00:22:33:44:02`、MODE `3`、PTP `9`。
- 兩板 PHY/link 欄位正常，MiniNIC/PTP counters 有 activity，RXERR delta 為 0。
- Step 2 focused samples：Master `30/30` valid、Slave `30/30` valid。

判定：`STEP1_REGRESSION = PASS`、`STEP2_REGRESSION = PASS`。

### Step 3

Slave focused samples 為 `30/30` valid，且持續觀察到：

- `FOREIGN=1/0`。
- `parent=1/0/1`，即 parentIsWRnode=1、parentWrModeOn=0、parentCalibrated=1。
- RX message `0x1001`、TX message `0x1000`。
- `LOCK_ENABLE=4`。

focused gate 判定 `STEP3_REGRESSION=PASS`；current state 仍為 `state_idle=30`、`state_good=0`，因此 state evidence 保留為 `READ_INCONSISTENT`，不能把單一 state interpretation 擴大成 Step 3 failure。

判定：`STEP3_REGRESSION = PASS`。

### Step 4

Dashboard 在 Slave 顯示：

- `SPLL_STATE=3 SPLL_MODE_SLAVE`。
- `RCER=1`、`LOCK_ENABLE=4`。
- `OCER=TIMEOUT`。
- `SPLL_DMTD_REF_EVENTS`、`SPLL_DMTD_FB_EVENTS`、TAG、TRR、IRQ、HELPER delta 均為 0。

50-sample `events` focused script 進一步顯示：

- 兩板 native DMTD sampled/transition/stable-hit counters 有增加，表示輸入 clock activity 存在。
- Master 與 Slave 的 deglitch `GOT_EDGE_ENTRY`、`QUAL_REACHED_8`、`ACCEPT` 都沒有增加；Slave 例如 `REF_GOT_EDGE_ENTRY` 固定 `139DE4A4`、`FB_GOT_EDGE_ENTRY` 固定 `130A5303`。
- 兩板 `TAG_VALID_COUNT`、`TRR_WRITE_COUNT`、`IRQ_COUNT`、`HELPER_UPDATE_COUNT`、`TRR_POP_COUNT`、`STATE_TRANSITION_COUNT` 的 delta 都為 0。
- 兩板 event boundary 都是 `QUALIFICATION_ABORT_AFTER_GOT_EDGE`。
- mapping group 50/50 samples valid，沒有 timeout；其中 `REF_QUAL8_MAPPING` 與 `FB_QUAL8_MAPPING` 皆維持 0。

這表示本輪 evidence 已經通過 Step 2/3 barrier，但沒有達到 Step 4「deglitch accept → tag/TRR/servo activity」的 gate。

判定：`STEP4_REGRESSION = NOT_PASS`。

### 本輪截至目前的判定

| Gate | 結果 | 證據狀態 |
|---|---|---|
| Fresh compile | PASS（但 timing 未關閉） | 兩張板均 Full Compilation was successful |
| Master program | PASS | Programmer configuration succeeded |
| Slave program | PASS | Programmer configuration succeeded |
| Step 1 regression | PASS | dashboard + repeated focused samples |
| Step 2 regression | PASS | 兩板 repeated valid samples、PTP/MiniNIC activity |
| Step 3 regression | PASS | Slave 30/30 valid、foreign/parent/signaling/lock-enable |
| Step 4 SoftPLL startup | NOT_PASS | input DMTD activity 存在，但 deglitch accept 及 downstream events 無 activity |

因此本紀錄可以宣稱 fresh exact HEAD 已重現 Step 1/2/3，但不能宣稱 Step 4 PASS。這是 read-only observability 證據；本輪沒有修改 functional behavior，也沒有證明根因是 PHY、firmware 或 SoftPLL algorithm。

## Raw log provenance

本次原始檔案保存於：

```text
docs/experiments/exp-step4-softpll-enable/raw/20260825_fresh_b040d1b/
```

## 下一步

1. 將本紀錄與 raw logs push 到 `exp/step4-softpll-enable`。
2. 請 reviewer 重新檢視 fresh HEAD 的 Step 2/3 regression 與 Step 4 boundary evidence。
3. 在取得下一個單一變因前，不修改 SoftPLL/PHY/firmware functional behavior。
