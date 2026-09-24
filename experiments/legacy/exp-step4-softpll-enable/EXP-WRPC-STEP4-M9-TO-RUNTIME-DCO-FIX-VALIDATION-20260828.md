# EXP-WRPC-STEP4-M9-TO-RUNTIME-DCO-FIX-VALIDATION-20260828

## 結論

本輪依分支 3 最新建議，保留既有 static-FSM false-restart 修正，只增加 downstream boundary 的 read-only 證據，完成 fresh firmware、Quartus full compile、雙 DE5a 重新燒錄，並執行 Master 單次 `mode master\n`、Slave 被動觀察。

有效的控制 VUART log 證明 Master 已到達 `M9 MASTER_ARGUMENT_MATCHED` 與 `COMMAND_STAGE=9`；後續 forensics 證明 `wrc_ptp_set_mode(WRC_MODE_MASTER)` 的 persistent stage history 依序走過 `2 → 3 → 4 → 5`。runtime context 同時看到一次 SoftPLL init / clear-DAC、無 DAC timeout，以及 Master 的 TAG、TRR write/pop、IRQ、helper update 持續活動。Slave 沒有收到 stimulus，所有 command/mode/runtime-DCO counters 維持 0。

依分支 3 的判定條件，本輪支持 static-FSM false-restart fix 的 PASS（至少在 M9 → mode-master → runtime-DCO downstream 邊界）；這不是 WR lock、DCO/SI5340、link/sync 或整個 Step 4 functional success 的宣告。專用新 reader 的一次結果為 `M9=5 / COMMAND_STAGE=4`，與已驗證的 VUART reader transaction pattern 不一致，因此列為 inconclusive，排除於主要結論之外。

```text
FRESH_BUILD_AND_PROGRAM=PASS
MASTER_COMMAND_DISPATCH=M9_AND_COMMAND_STAGE_9_PROVEN
MASTER_MODE_STAGE_HISTORY=2->3->4->5
MASTER_SPLL_INIT_COUNT=1
MASTER_CLEAR_DACS_COUNT=1
MASTER_DAC_TIMEOUT=0
MASTER_TAG_TRR_IRQ_HELPER_ACTIVITY=OBSERVED
SLAVE_PASSIVE=NO_STIMULUS_AND_ZERO_COMMAND_RUNTIME_COUNTERS
STATIC_FSM_FALSE_RESTART_FIX=PASS_FOR_THIS_VALIDATION_BOUNDARY
WR_LOCK_OR_STEP4_FUNCTIONAL_SUCCESS=NOT_PROVEN
TIMING_CLOSED=NO
```

## 變更與實驗範圍

保留 active Quartus source `quartus/jtag_runtime_diag/si5340a_i2c_reg_controller_dco.v` 的既有修正：

```verilog
else if (i2c_controller_config_done && (i2c_reg_state > 0))
    i2c_reg_state <= i2c_reg_state + 1;
```

本輪只新增 `scripts/jtag/read_m9_to_runtime_dco_fix_validation.tcl` 作為 downstream capture reader；沒有再修改 VUART、newline、shell parser、command lookup、`wrc_ptp_set_mode()`、SoftPLL、DMTD、DCO、SI5340、reset 或 IRQ functional behavior。

reader 設定如下：

```text
ready_timeout_ms=30000
stable_ms=1500
passive_samples=100
gap_ms=100
poll_attempts=25
Master stimulus: exactly one mode master\n (12 bytes)
Slave stimulus: none
```

## Downstream boundary 證據

| Boundary | 本輪證據 | 判讀 |
|---|---|---|
| D0：M9 argument matched | Valid control log: `sample=013`, `COMMAND_STAGE=9`, `MICRO_STAGE=9`, `MICRO_STAGE_NAME=MASTER_ARGUMENT_MATCHED`；final `micro_stage=9`, `command_stage=9` | Master command dispatch 已通過 |
| D1：進入 mode-master path | Forensics: `PERSIST_CMD_STAGE=9`、`PERSIST_CMD_RX_BYTE_COUNT=0x0C`、`PERSIST_CMD_LAST_BYTE=0x0A`、`PERSIST_MODE_MASTER_STAGE=5` | `mode master\n` 已進入並完成 mode-master persistent path |
| D2：`wrc_ptp_set_mode(MASTER)` downstream | Forensics: `PERSIST_STAGE_HISTORY0..3=2,3,4,5`、`LOCK_WAIT_SUBSTAGE=8`、`LOCK_WAIT_ITERATION=0x14` | mode-master 初始化與 lock-wait path 均留下證據 |
| D3：SoftPLL setup | Runtime: `INIT_COUNT=1`、`LAST_INIT_TICS=0xE392`、`SPLL_STATE=0x00020004`；forensics: `PERSIST_SPLL_CHECK_LOCK_STAGE=5` | SoftPLL init / check-lock path 已被執行；不宣稱 lock 成功 |
| D4：first DAC / runtime activity | Runtime: `CLEAR_DACS_COUNT=1`、`LAST_CLEAR_TICS=0xE392`、`DAC_TIMEOUT=0`；`TAG_VALID`、`TRR_WRITE`、`TRR_POP`、`IRQ`、`HELPER_UPDATE` 均持續增加 | runtime DCO downstream activity 已觀察到 |

Master control run 的第一個有效 post-stimulus sample 為 sample 013，persistent shell snapshot 為：

```text
COMMAND_STAGE=9
MICRO_STAGE=9 MICRO_STAGE_NAME=MASTER_ARGUMENT_MATCHED
MICRO_BOOT_GENERATION=1
MICRO_LENGTH=11 MICRO_POS=11 MICRO_LINE_READY=1 MICRO_SHELL_STATE=2
MICRO_BUFFER_CAPTURE_STAGE=4
MICRO_BUFFER_HEX=6D6F6465206D61737465720000000000
```

`MICRO_BUFFER_HEX` 以 little-endian byte order 還原為 `mode master`；newline 是 12-byte stimulus 的最後一個 byte，pre-tokenization buffer length 則為 11。

## Runtime 與 reset 判讀

Master forensics 在觀察期間重複得到：

```text
MODE_MASTER_STAGE=00000005
PERSIST_MODE_MASTER_STAGE=00000005
PERSIST_STAGE_HISTORY0=00000002
PERSIST_STAGE_HISTORY1=00000003
PERSIST_STAGE_HISTORY2=00000004
PERSIST_STAGE_HISTORY3=00000005
PERSIST_SPLL_CHECK_LOCK_STAGE=00000005
PERSIST_SPLL_CHECK_LOCK_STATE=0000000A
PERSIST_CMD_STAGE=00000009
PERSIST_CMD_RX_BYTE_COUNT=0000000C
BOOT_GENERATION=00000001
CPU_RESET_LIVE=0
WR_CORE_RESET_ASSERTED_LIVE=0
EXTERNAL_RESET_ASSERTED_LIVE=0
SI_CONFIG_DONE_LIVE=1
SYS_PLL_LOCK_LIVE=1
```

Master 的 `TAG_VALID` / `TRR_WRITE` / `TRR_POP` / `IRQ_COUNT` / `HELPER_UPDATE` 從約 `0x455xx` 增加到約 `0x6E5xx`；runtime context 末段五者一致為 `0x6E5B2`。`BOOT_GENERATION` 穩定為 1，live reset signals 在觀察期間維持非 reset。reset sticky 的 startup baseline 為 `00010100010101FF`，其歷史 sticky bits 不解讀為本輪新 reset。

Slave 保持被動：`PERSIST_MODE_MASTER_STAGE=0`、`PERSIST_CMD_STAGE=0`、`PERSIST_CMD_RX_BYTE_COUNT=0`、`INIT_COUNT=0`、`CLEAR_DACS_COUNT=0`、`DAC_TIMEOUT=0`，且 TAG/TRR/IRQ/helper counters 均為 0。其 live `CPU_RESET`、WR core reset、external reset 均為 0，`SI_CONFIG_DONE=1`、`SYS_PLL_LOCK=1`。

## Build / program provenance

build source commit：`b7be8356081a62e4ffefdd330c7a1a458f15d12b`，branch：`exp/step4-softpll-enable`。Master / Slave firmware 與 MIF 均 fresh；兩個 Quartus project 都是 full compilation successful，Quartus `17.0.0 Build 595`。

| Image | MIF SHA-256 | SOF SHA-256 | Program cable / checksum |
|---|---|---|---|
| Master | `b99f005af0f3552cdc3d2ca0414a11d772c6cfd8577a395637d5e7e751bc1aca` | `4f24645be564df38bdb985a1cd9ca3b3c9ad8bfb3c1e7c6e746b2fadb329cfa6` | `DE5 [1-11.1]` / `0x30B00EC4` |
| Slave | `f6cdbe5beb960a60ac4864b84c541b8682b1050b64b21a6acccbdeb1eff6a964` | `7d4ccb57096e9d14ca740d350883537b6cf3667958d22443a09fe0e04c6031f1` | `DE5 [1-11.2]` / `0x30B7AD8B` |

兩條 cable 的 JTAG ID 都為 `0x02E660DD`，program 成功且 0 errors / 0 warnings。timing 仍未 closed：Master worst setup `-0.177 ns`，Slave `-0.272 ns`；完整 timing / QSF / SDC / firmware hash 在 raw build-info 檔案中。

## Inconclusive reader run

新增 reader 的首次執行本身成功完成 Tcl / Signal Tap，且 gate 與 single injection 都符合設定，但得到：

```text
DCO_FIX_BOARD_DONE board=DE5 [1-11.1] injected=1 samples=112 final_m9=5 final_command_stage=4
```

其 WB result pattern 為 `0007FE57`，不同於已驗證 VUART reader 的 sequential pattern（最後 newline `00027357`）。因此這次只保留作為 reader/tool transaction discrepancy 的診斷紀錄，不用來否定有效 control VUART run，也不把它解讀為 firmware functional regression。

## 下一步邊界

本輪已完成分支 3 指定的 M9 → runtime-DCO fix validation。依分支 3 的建議，後續若要繼續，只觀察 `DMTD accepted → TAG → TRR write/pop → IRQ → helper` 的既有 downstream evidence；不要在同一輪再修改 functional code。本輪已看到 TAG / TRR / IRQ / helper activity，因此下一次應先由分支 3 依最新紀錄決定是否需要更窄的 read-only boundary，而不是再回頭追 VUART、newline 或 shell parser。

## Raw evidence

本輪 raw logs 保存在：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-M9-TO-RUNTIME-DCO-FIX-VALIDATION-20260828/`

- `control_vuart.log`：有效的 single `mode master\n` control run；Master final M9/command stage 9，Slave passive 0。
- `forensics.log`：mode-master stage history、lock-wait、persistent command、reset/live correlation 與 downstream counters。
- `runtime_context.log`：SoftPLL init/clear-DAC、timeout、TAG/TRR/IRQ/helper runtime context。
- `inconclusive_dedicated_reader.log`：新增 reader 的 inconclusive run，排除於主要結論。
- `build_info_jtag_master.txt` / `build_info_jtag_slave.txt`：fresh build、Quartus、timing、MIF/SOF provenance。
- `firmware_master_hashes.sha256` / `firmware_slave_hashes.sha256`：fresh firmware hash。

本輪新增 reader commit：`b7be835`；raw evidence preservation commit：`de27bb2`。
