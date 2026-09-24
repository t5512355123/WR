# EXP-WRPC-STEP4-VUART-NEWLINE-TO-SHELL-DISPATCH-MICROTRACE-20260828

## 結論

本輪依分支 3 的最新建議，完成 firmware-only、persistent M0–M9 microtrace：Master 等待 shell-ready gate 穩定 1500 ms 後，只注入一次 `mode master\n`；Slave 不注入任何命令。兩張 DE5a 均由 fresh firmware/MIF、clean Quartus compile 產生的 SOF 重新燒錄。

結果：Master 的 persistent microtrace 從 newline boundary 進展至 `M9 MASTER_ARGUMENT_MATCHED`，同時 `COMMAND_STAGE=9`，並保存了完整的 `mode master` 內容；Slave 維持 `M0 IDLE`、`COMMAND_STAGE=0`。因此本輪證明的是 VUART newline-to-shell dispatch 已通過 Master argument match，不是 SoftPLL lock 或 Step 4 functional success。

```text
PERSISTENT_VUART_NEWLINE_TO_SHELL_DISPATCH=PROVEN
MASTER_ARGUMENT_MATCHED=M9
SLAVE_PASSIVE=M0
SOFTPLL_ROOT_CAUSE=NOT_PROVEN
TIMING_CLOSED=NO
```

## Scope 與單一變因

本輪只增加與修正 read-only 診斷可觀測性：

- `vendor/wrpc-sw/shell/shell.c`、`vendor/wrpc-sw/shell/cmd_ptp.c` 與 `vendor/wrpc-sw/dev/console-uart.c` 的既有執行路徑沒有改變。
- 沒有修改 VUART FIFO 語意、shell parser、排程、main loop、`wrc_ptp_set_mode()`、PTP、WR signaling、SoftPLL、DMTD、DCO、SI5340、reset、IRQ、fault 或 PHY functional behavior。
- WDIAGS private window 的 microtrace overlay 只在診斷 trace 啟動後使用；新增保護避免後續 shell-ready 診斷刷新覆蓋已提交的 snapshot。
- 之前一次使用舊 MIF 的測試只作為 debug 線索，沒有納入本輪結論；本紀錄只採用 fresh firmware/MIF 後重新編譯、燒錄與量測的 final log。

## M0–M9 定義與實際路徑

| Marker | Boundary | Source path |
|---:|---|---|
| M0 / 0 | idle、沒有 microtrace evidence | `shell_command_microtrace_active == 0` |
| M1 / 1 | newline detected | `shell.c::KEY_ENTER` |
| M2 / 2 | line-ready scheduled、切到 `SH_EXEC` | `shell.c::KEY_ENTER` |
| M3 / 3 | shell poll observes line ready | `shell.c::SH_EXEC` |
| M4 / 4 | `cmd_buf[cmd_len] = 0` 後 buffer terminated | `shell.c::SH_EXEC` |
| M5 / 5 | shell execution entered | `shell.c::SH_EXEC` |
| M6 / 6 | tokenization completed / token parsed | `shell.c::_shell_exec` |
| M7 / 7 | command lookup matched `mode` | `shell.c::_shell_exec` |
| M8 / 8 | `cmd_ptp()` handler entered | `cmd_ptp.c::cmd_ptp` |
| M9 / 9 | `master` argument matched | `cmd_ptp.c::cmd_ptp` |

RX source audit：`console-uart.c::con_rx_internal()` → `suart_read_byte()` → `wdiags_write_shell_command_rx_byte()`；接著由 `console.c::console_getc()` 交給 `shell_interactive()`。此路徑沒有 firmware software RX write/read-index pair；硬體 FIFO 由既有 `suart_read_byte()` 消費，新增內容只是邊界 breadcrumb。

`wdiags_write_shell_command_micro_stage()` 只接受單調遞增且相鄰的 stage，因此讀到 M9 代表 M1–M8 已依序被接受。由於 reader 每 100 ms 取樣，本輪多個微階段在同一個 sample 內完成；不把它誤寫成每個 stage 都有獨立的 JTAG 時間戳。

## 實驗設定

```text
ready_timeout_ms=30000
stable_ms=1500
passive_samples=80
gap_ms=100
poll_attempts=25
Master stimulus: exactly one mode master\n (12 bytes)
Slave stimulus: none
```

Master 的 gate candidate 在 sample 001 出現；穩定 1500 ms 後於 sample 012 完成 12 bytes 注入。12 個 VUART Wishbone writes 都完成，newline write 的 `WB_RESULT=00027357`。

## Runtime 結果

### Master：DE5 [1-11.1]

正式 log 摘要：

```text
VUART_MICROTRACE_GATE_CANDIDATE sample=001 stable_ms=1500
VUART_MICROTRACE_STIMULUS_SENT sample=012 command=mode_master_once
VUART_MICROTRACE_BOARD_DONE injected=1 samples=92 injection_elapsed_ms=1668 final_micro_stage=9 final_command_stage=9
```

sample 013 的 persistent snapshot：

```text
COMMAND_STAGE=9
MICRO_STAGE=9 MICRO_STAGE_NAME=MASTER_ARGUMENT_MATCHED
MICRO_BOOT_GENERATION=1
MICRO_LENGTH=11 MICRO_POS=11 MICRO_LINE_READY=1 MICRO_SHELL_STATE=2
MICRO_BUFFER_CAPTURE_STAGE=4
MICRO_BUFFER_HEX=6D6F6465206D61737465720000000000
```

buffer hex 以 little-endian byte order 還原為 `mode master`；newline 屬於 12-byte stimulus，但 pre-tokenization command buffer length 為 11。sample 080 仍保持相同 M9 snapshot，沒有回退。

### Slave：DE5 [1-11.2]

```text
VUART_MICROTRACE_BOARD_DONE injected=0 samples=91 injection_elapsed_ms=-1 final_micro_stage=0 final_command_stage=0
```

Slave 沒有 command stimulus；初始與最後狀態均為 `MICRO_STAGE=0`、`COMMAND_STAGE=0`。

## Build / program provenance

Source/build commit：`d5f1c1b6979da88703c0b5c5fd24610dd7ac307a`，branch：`exp/step4-softpll-enable`。

Master 與 Slave 均完成 fresh firmware/MIF build、Quartus Prime 17.0 Build 595 clean full compilation，且 program 成功。兩份 timing report 仍為既有 baseline：Master worst setup `-0.177 ns`、Slave `-0.272 ns`，所以 `TIMING_CLOSED=NO`。

| Image | MIF SHA-256 | SOF SHA-256 | Program cable / checksum |
|---|---|---|---|
| Master | `b3aff30e1c40f8329510588bdd709af4b4c84d083b44026c67e03801c0b0758a` | `cd92634f7fe0d3c0da44c85efcff6bd314f6b571cc932e0fc01d42c2229737d4` | `DE5 [1-11.1]` / `0x30B00EC4` |
| Slave | `a8e5af33314b7b72e2ec944ab3397bf56e5e7d382ae8afb4a6f86711100f572a` | `20d9e0890c1ce8eaea8fcd10e7165b9a81930dc81f211488868537c3e4ba4169` | `DE5 [1-11.2]` / `0x30B7AD8B` |

兩條 cable 的 JTAG ID 都是 `0x02E660DD`，programmer 均為 0 errors / 0 warnings。完整欄位在同資料夾的 `raw/build_info_jtag_master.txt`、`raw/build_info_jtag_slave.txt` 與 `raw/program_jtag_summary.txt`。

## WDIAGS overlay 與證據完整性

因 private WDIAGS SDB window 只到 `0x1ff`，本輪保留 `0x1e0..0x1f8` 作為 idle gate；microtrace stage 大於 0 後，這些位址改作：

```text
0x1e0..0x1ec  command buffer word 0..3
0x1f0         length[7:0], position[15:8], line_ready[16], shell_state[31:24]
0x1f4         micro boot generation
0x1f8         buffer capture stage
0x1fc         microtrace stage，最後寫入，作為 commit marker
```

Preflight 在沒有 stimulus 時確認兩板 `0x1e0..0x1f8` 都仍為 gate words、stage 都為 0，且所有 probe transaction `active=0 err=0 stall=0`。這排除了 overlay 在 idle gate 階段破壞 reader 的情況。

## 判讀與下一步邊界

本輪只把問題定位到：手動命令已經由 VUART 進入 firmware、經過 newline、shell execution、tokenization、`mode` lookup、handler 與 `master` argument match。這使後續可以在不再追查 VUART dispatch 的前提下，依分支 3 再選一個單一的 downstream boundary。

本輪沒有證明 `spll_check_lock()` 成功、SoftPLL 已 lock、DCO/SI5340 正常、WR link 已同步或 Step 4 已通過；也沒有足夠證據把任何 root cause 歸因於硬體或 firmware functional failure。

## Raw evidence

本機保存的摘要與雜湊：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-VUART-NEWLINE-TO-SHELL-DISPATCH-MICROTRACE-20260828/`

- `microtrace_final_excerpt.txt`：final runtime key lines、M9 snapshot 與 remote full-log SHA-256。
- `overlay_preflight_excerpt.txt`：fresh program 後的 idle overlay readback 與 remote debug-log SHA-256。
- `build_info_jtag_master.txt` / `build_info_jtag_slave.txt`：Quartus、MIF、SOF、timing provenance。
- `firmware_hashes.sha256`：fresh ELF/MIF hash。
- `program_jtag_summary.txt`：兩條 JTAG cable 的 successful programming summary。
- `source_path_audit.txt`：RX / shell / dispatch source path 與 overlay map。

原始 pain 端 log 路徑與 hash 也記在 `microtrace_final_excerpt.txt`；本輪報告只採用這次 fresh firmware/MIF、fresh SOF、fresh program 後的 final log。
