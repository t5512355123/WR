# EXP-WRPC-STEP4-FIXED-IMAGE-SHELL-READY-GATED-RUNTIME-RETEST-20260828

## 結論

本輪完成了 shell-ready gated 的 fresh-image retest，但沒有取得可判定 static-FSM fix 的 runtime transaction。Master 在滿足 gate 後只注入一次 `mode master\n`；command path 在 5 秒後仍停在 `PERSIST_CMD_STAGE=4`（收到 newline），沒有到達 stage 9，也沒有 `PERSIST_MODE_MASTER_STAGE > 0` 或 runtime DCO transaction。

```text
SHELL_READY_GATE = PASS
COMMAND_DISPATCH = NOT_REACHED (stage 4 only)
RUNTIME_FIX_RETEST = INVALID
STATIC_FSM_FALSE_RESTART_FIX = INCONCLUSIVE_RUNTIME_NOT_REACHED
NEXT_BOUNDARY = PERSISTENT_COMMAND_STAGE_4_TO_MODE_DISPATCH
```

依分支 3 的判讀規則，本輪停止，不以這次結果判定 SI5340 one-line fix PASS/FAIL，也不加入第二個 functional fix。

## Baseline and allowed scope

- Branch: `exp/step4-softpll-enable`
- Functional baseline: `7b96574` (`exp: report idle completion gate fix`)
- Preserved functional fix in `quartus/jtag_runtime_diag/si5340a_i2c_reg_controller_dco.v`:

  ```verilog
  else if (i2c_controller_config_done && (i2c_reg_state > 0))
      i2c_reg_state <= i2c_reg_state+1;
  ```

- Firmware shell-ready observability commit: `6a0667d`
- Final reader parser correction: `5279046`
- Raw evidence commit: `7806e22`
- This round changed only read-only observability/test gating and reader decoding; no shell parser, main-loop control flow, SoftPLL, DCO, reset, PTP, or PHY functional logic was changed.

## Shell-ready evidence

The firmware markers are generation-tagged and stored in the fixed `.debug_precrt` `NOLOAD` area. The exact Master and Slave ELF symbol addresses are identical:

| Marker | ELF symbol address | WDIAGS read-only mirror |
|---|---:|---:|
| `FIRMWARE_MAIN_LOOP_REACHED` | `0x0002E0A0` | `0x00100BE0` |
| `SHELL_POLL_LOOP_REACHED` | `0x0002E0A4` | `0x00100BE4` |
| `BOOT_INIT_SEQUENCE_DONE` | `0x0002E0A8` | `0x00100BE8` |
| `FIRMWARE_SHELL_READY` | computed gate | `0x00100BEC` |
| main-loop generation | `0x0002E0AC` | `0x00100BF0` |
| shell-poll generation | `0x0002E0B0` | `0x00100BF4` |
| boot-init generation | `0x0002E0B4` | `0x00100BF8` |

The reader did not use a fixed sample number. It waited for `POST_STARTUP_ARMED=1`, all three firmware markers, matching generation tags, `FIRMWARE_SHELL_READY=1`, `CPU_RESET=0`, and a stable 1500 ms interval. It also required the Master runtime correlation record to be idle and the persistent command stage to be zero before injection.

Master pre-injection evidence included:

```text
POST_STARTUP_ARMED=1
POST_ARMED=1
STARTUP_READY_FINAL=1
FIRMWARE_MAIN_LOOP_REACHED=1
SHELL_POLL_LOOP_REACHED=1
BOOT_INIT_SEQUENCE_DONE=1
FIRMWARE_SHELL_READY=1
GENERATION_MATCH=1
BOOT_GENERATION=1
CPU_RESET=0
GATE=1
RUNTIME_IDLE=1
```

The same gate remained true at the stimulus sample after the 1500 ms candidate interval. CPU PC samples were nonzero and varied during the gate window, providing an additional indication that the CPU was executing rather than held.

## Build and program provenance

Both images were freshly built from firmware source commit `6a0667d54e3c7285b555921e148e74cce5d3f8b0`. Quartus full compilation succeeded for both projects.

| Item | Master | Slave |
|---|---|---|
| Quartus | 17.0.0 Build 595 | 17.0.0 Build 595 |
| MIF SHA256 | `33939dc5da621201bbf9f7f9658dff0eac7273271be8a873e92cd386ec69d6e5` | `373c3ce3a0b9c98bf28e619ffacd1dd5ef318737b093a1426cb3a28e29298836` |
| SOF SHA256 | `2a08bc7b41c61715c30a1a68c65f3541750e0527ebe298c954dec06140a17449` | `241f86397e3fde4a73b71cd54667eb09fe566d60abb9316e054a34c6f8c87790` |
| timing closed | NO | NO |
| worst setup slack | `-0.177 ns` | `-0.272 ns` |
| worst hold slack | `0.037 ns` | `0.036 ns` |
| programmer cable | `DE5 [1-11.1]` | `DE5 [1-11.2]` |
| programmer result | success, checksum `0x30B00EC4` | success, checksum `0x30B7AD8B` |
| JTAG ID | `0x02E660DD` | `0x02E660DD` |

The full build info and compile logs are retained in the raw folder.

## Reader and stimulus

Final command:

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp -t scripts/jtag/read_fixed_image_shell_ready_gated_runtime_retest.tcl 30000 1500 180 200 25
```

Configuration was `ready_timeout_ms=30000`, `stable_ms=1500`, `passive_samples=180`, and `gap_ms=200` (nominal 36 seconds of passive samples after dispatch). The final run used the corrected reader after a fresh reprogram of both boards.

Stimulus rules were enforced:

- Master: `mode master\n`, exactly once, after the gate.
- Slave: no stimulus.
- No CPU hold/release, reset write, reprogram, or functional diagnostic write was issued by the reader.

## Master result

The Master gate candidate was observed at sample 1 and the one-shot stimulus was sent at sample 8, elapsed `1652 ms`, after the required stable interval.

Before injection at sample 8:

```text
GATE=1 RUNTIME_IDLE=1 PERSIST_CMD_STAGE=00000000
POST_ARMED=1 FIRMWARE_SHELL_READY=00000001
FIRMWARE_MAIN_LOOP_REACHED=00000001
SHELL_POLL_LOOP_REACHED=00000001
BOOT_INIT_SEQUENCE_DONE=00000001
GENERATION_MATCH=1 BOOT_GENERATION=00000001 CPU_RESET=0
```

After injection:

| Sample / elapsed | Command and runtime evidence |
|---|---|
| 9 / `1919 ms` | `PERSIST_CMD_STAGE=4`; `MODE_STAGE=0`; `LOCK_WAIT_SUBSTAGE=0`; `SPLL_CHECK_LOCK_STAGE=0`; all runtime timestamps still zero |
| 23 / `5222 ms` | still `PERSIST_CMD_STAGE=4`; runtime timestamps still zero; stop condition reached |
| 27 / `6165 ms` | still `PERSIST_CMD_STAGE=4`; `BOOT_GENERATION=1`; `CPU_RESET=0`; `GATE=1`; runtime idle |

The raw correlation words remained zero throughout the valid capture window:

```text
T_DAC_LOAD=0
T_RUNTIME_START=0
T_BUS_DONE=0
T_STATIC_DONE_PULSE=0
T_STATIC_STATE_LEAVE_ZERO=0
T_STATIC_READY_DROP=0
T_SI_CONFIG_DROP=0
T_WR_CORE_RESET_ASSERT=0
T_CPU_RESET_ASSERT=0
T_SYSTEM_START=0
STATIC_CURRENT=0
```

These zeros are not a PASS for the static-FSM fix because the command never reached the runtime transaction that could exercise the fix. The reset raw word remained `0x00010100010101FF`, consistent with the fresh-boot baseline counters; no new runtime reset transition was observed.

## Slave control result

The Slave remained a no-stimulus control. It reached the same shell-ready gate with `BOOT_GENERATION=1`, `PERSIST_CMD_STAGE=0`, `GATE=1`, and `RUNTIME_IDLE=1`, then completed 180 passive samples. Its runtime timestamps stayed zero and no command was sent.

## Validity classification and next boundary

The shell-ready gate itself is proven for this image: all requested markers and generation tags were present and stable before the stimulus. However, the gate did not guarantee that the injected VUART bytes were consumed by the shell task. The decisive result is:

```text
PERSIST_CMD_STAGE=4 after 5 seconds
PERSIST_MODE_MASTER_STAGE=0
runtime transaction=not reached
```

Therefore:

```text
SHELL_READY_GATE_ASSUMPTION = FAILED_FOR_COMMAND_DISPATCH
EXPERIMENT_VALID_FOR_RUNTIME_FIX = NO
RUNTIME_FIX_RETEST = INVALID
ROOT_CAUSE = NOT_PROVEN
```

The next experiment boundary is the existing command-delivery path after newline (`stage 4 → stage 5`), while preserving both the one-line static-FSM gate and the current shell-ready observability. Do not use this round to alter SI5340, runtime DCO, SoftPLL, reset, or parser functionality.

## Raw evidence

- `raw/EXP-WRPC-STEP4-FIXED-IMAGE-SHELL-READY-GATED-RUNTIME-RETEST-20260828/runtime_retest_r2.log`
- `raw/EXP-WRPC-STEP4-FIXED-IMAGE-SHELL-READY-GATED-RUNTIME-RETEST-20260828/build_info_jtag_master.txt`
- `raw/EXP-WRPC-STEP4-FIXED-IMAGE-SHELL-READY-GATED-RUNTIME-RETEST-20260828/build_info_jtag_slave.txt`
- `raw/EXP-WRPC-STEP4-FIXED-IMAGE-SHELL-READY-GATED-RUNTIME-RETEST-20260828/programming_and_config.txt`
- `raw/EXP-WRPC-STEP4-FIXED-IMAGE-SHELL-READY-GATED-RUNTIME-RETEST-20260828/reader_source.tcl`
- `raw/EXP-WRPC-STEP4-FIXED-IMAGE-SHELL-READY-GATED-RUNTIME-RETEST-20260828/source_diff_7b96574_to_6a0667d.patch`
