# EXP-WRPC-STEP4-HARDWARE-RESET-SOURCE-STICKY-CAPTURE-20260827

## 結論

本輪依分支 2 最新指示，在目前實際 JTAG top 的 reset tree 上加入不依賴 CPU/WR reset 的硬體 sticky capture，重新完整編譯並燒錄兩片 DE5a，然後只對 Master 注入一次 `mode master\n`，以兩片同時被動觀測。

最重要結果：Master 在唯一一次命令注入後，硬體 observer 的 CPU reset 與 WR-core reset assertion count 都各增加 1；Slave 沒有增加。Master 的 SI config-drop count 也增加 1，但 SYS PLL lock-drop 與 external reset count 沒有增加。

```text
Master CPU_RESET_COUNT:       02 -> 03
Master WR_CORE_RESET_COUNT:   02 -> 03
Master SI_CONFIG_DROP_COUNT:  02 -> 03
Master SYS_PLL_DROP_COUNT:    01 -> 01
Master EXTERNAL_RESET_COUNT:  00 -> 00
Master BOOT_GENERATION:       02 -> 03
Slave  CPU/WR/SI/PLL/EXT:     02/02/02/01/00 -> unchanged
ROOT_CAUSE:                   NOT_PROVEN
```

因此，本輪直接證明了命令流程期間曾發生硬體可觀測的 final CPU reset assertion，且同一期間 WR-core reset 也重新 assertion。這把「CPU 被硬體 reset」從推測提升為觀測證據；但因 SI config-drop 也在同一觀測窗口增加，尚不能證明是哪一個上游來源先觸發 WR-core reset，也不能宣稱已完成 root-cause isolation。

## Source audit and diagnostic design

本輪先核對目前 JTAG top，而非假設 reset signal 名稱：

- `CLK_50_B2J` 是外部 50 MHz observer clock，未接到 CPU 或 `wr_core_reset_n` 的 reset input。
- `CPU_RESET_n` 與 `clk_sys_625_locked` 進入 `p_release_wr_core_reset`；`si_config_done='0'` 也會使 `wr_core_reset_n` 保持 asserted。
- `u_xwr_core.rst_n_i => wr_core_reset_n`，所以 `wr_core_reset_n` 是 WR core 的外部 reset gate。
- `wrc_urv_wrapper` 的 final CPU reset 還包含 CPU CSR software-reset bit；本輪保留共用 wrapper 介面不變，僅在 top level 以 `cpu_software_reset <= cpu_reset and wr_core_reset_n` 作 diagnostic-only constituent approximation。
- Sticky/counter process 只使用 `CLK_50_B2J` 與 reset/drop event wires，沒有 CPU reset、WR core reset 或 mailbox reset 作為 process reset。

Instance 27 的 JTAG-readable layout：

```text
bit 0       diagnostic arm
bits 1..8   CPU reset, WR core reset, external reset, SI config drop,
            SYS PLL lock drop, software reset, PHY reset, WR-ready drop
bits 23..16 CPU reset assertion count
bits 31..24 WR core reset assertion count
bits 39..32 external reset assertion count
bits 47..40 SI config-done drop count
bits 55..48 SYS PLL lock-drop count
bits 63..56 software-reset assertion count
```

Sticky bits are the primary pulse-independent evidence. The synchronized edge counters are auxiliary and are not claimed to catch a pulse shorter than the observer sampling path.

## Build and programming provenance

- FPGA image source commit: `15ca15c273da9f2a4081485aae2819d605e0d233`
- Reader initialization fix commit: `942935fe99a0d03159a30e188dc945d77fb23823`
- Raw capture commit: `bcddf4b`
- Project: `quartus/jtag_runtime_diag`
- Quartus: 17.0.0 Build 595
- Master SOF SHA-256: `60683bce00f9b600218ea6c9186d7041d2ee0cdf023f1fcdad0d765f4910f834`
- Slave SOF SHA-256: `5d6bd9e6a322f3077ef02f2b8b05602c56ddcce0acd17b1fac26ce711b2ebf1d`
- Master MIF SHA-256: `c4e36b8cdb2422bbbd9214ccaf859d3725f69f2aba4671d9b3e50b246a088c95`
- Slave MIF SHA-256: `23de209caa5d840bcd68b41076ced4528c432121d4b5ed7025ec2bc8420a42f0`
- Programmer: direct non-privileged `quartus_pgm`; Master cable `DE5 [1-11.1]`, Slave cable `DE5 [1-11.2]`; both configuration operations succeeded.
- Both full Quartus compilations passed fitter and generated SOF. Timing did not close: Master worst setup slack `-0.164 ns`, Slave `-0.215 ns`; both reports also show unconstrained clocks and I/O paths. This remains an experimental diagnostic image.

The original wrapper scripts requested elevated authentication, so they were not used. The successful direct programmer logs are retained in the raw directory.

## Baseline

The first read-only baseline attempt exposed and preserved a Tcl mailbox-toggle initialization error. The reader was fixed and pushed before the retry; the failed log remains in raw evidence.

After fresh programming, the corrected retry completed on both boards. Both reported `ARMED=1` and the following identical startup snapshot:

```text
RESET_RAW=00010200020201FF
CPU_RESET_COUNT=02
WR_CORE_RESET_COUNT=02
EXTERNAL_RESET_COUNT=00
SI_CONFIG_DROP_COUNT=02
SYS_PLL_DROP_COUNT=01
SOFTWARE_RESET_COUNT=00
```

The startup sticky flags were already set on both boards. This means the current short diagnostic arm window observes normal post-configuration reset/drop activity; the flags alone cannot distinguish the later command event. The experiment therefore uses the count delta from the immediate pre-injection sample, with the fresh-program baseline explicitly recorded.

The boot/init read was successful and stable enough for the stimulus: Master reported boot generation 2 and boot-init command index 2; Slave reported boot generation 2 and boot-init command index 4. The full baseline logs are retained under the raw directory.

## Stimulus and passive capture

- One and only one command was injected, to Master at forensics sample 5:

  ```text
  mode master\n
  ```

- The injection was sent through the JTAG VUART HOST_TDR path. The reader did not hold or release the CPU, write CPU reset, or write WR/PHY/SoftPLL control registers.
- Capture length: 60 samples per board, 500 ms interval, approximately 35.5 seconds per board.
- Master and Slave were sampled with the same script; the Slave was not stimulated.

The command injection was accepted and produced the known re-entry signature on Master:

```text
BOOT_GENERATION:             2 -> 3
PERSIST_MODE_MASTER_STAGE:   4
PERSIST_LOCK_WAIT_SUBSTAGE: 1
PERSIST_CMD_STAGE:           9
PERSIST_CMD_BOOT_GENERATION: 2
```

`S5` was not observed during the capture. The command therefore still reaches the same incomplete mode-master/lock-wait boundary while the new hardware reset evidence is available.

## Reset-source transition

The compact transition excerpt is taken from the full 60-sample log:

| Board/sample | CPU count | WR-core count | SI drop count | SYS PLL drop | external reset | Boot generation | Interpretation |
|---|---:|---:|---:|---:|---:|---:|---|
| Master 005, before injection | 02 | 02 | 02 | 01 | 00 | 02 | pre-command baseline |
| Master 006, after injection | 03 | 03 | 03 | 01 | 00 | 03 | CPU and WR-core reset assertions observed |
| Master 060, settled post-capture | 03 | 03 | 03 | 01 | 00 | 03 | no further reset-count change |
| Slave 001/005/006/060 | 02 | 02 | 02 | 01 | 00 | 02 | unchanged control board |

The sticky flags remain set in every row because they were already set during startup. The count deltas, the isolated Master-only stimulus, and the simultaneous Master generation transition are the discriminating evidence in this run.

## Interpretation

1. `BOOT_GENERATION` advanced only on the stimulated Master.
2. Master CPU reset assertion count increased exactly once in the interval containing the command; this satisfies the branch-2 criterion for a hardware CPU-reset observation.
3. Master WR-core reset assertion count increased in the same interval, so the observed CPU reset is consistent with the WR-core reset gate being reasserted.
4. SI config-done drop count also increased once, making SI configuration a co-observed upstream candidate.
5. SYS PLL lock-drop and external reset counts did not increase, weakening those two sources for this attempt.
6. Software-reset assertion count remained zero after the baseline count; this run does not support a standalone CPU CSR software-reset event as the discriminating increment.
7. The 500 ms sample interval and synchronized counters do not establish the exact ordering between SI drop and WR-core assertion. `ROOT_CAUSE` remains `NOT_PROVEN` until that ordering/source dependency is isolated.

## Limitations and next boundary

- The startup arm window is short enough that normal post-configuration events set baseline sticky bits. A future refinement should lengthen or otherwise qualify the arm window if per-run zeroed sticky flags are required.
- The counters are synchronized edge counters, not width-independent event storage. Sticky flags provide the pulse-independent path, but they are not clearable at runtime in this image; comparison therefore relies on fresh reprogramming and pre/post counts.
- Timing is not closed on either experimental image.
- This is one stimulated run. It proves the hardware reset observation for this run, not the ultimate physical trigger or the complete explanation of the S4→S5 failure.

## Raw evidence

All raw logs, build reports, programmer output, source/image hashes, baseline retry, full forensics capture, post-capture readout, and transition excerpt are in:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-HARDWARE-RESET-SOURCE-STICKY-CAPTURE-20260827/`
