# EXP-WRPC-STEP4：firmware-only VLAN/pfilter progress diagnostic

- Date: 2026-08-26
- Branch: `exp/step4-softpll-enable`
- Final diagnostic commit: `4232655`
- Raw-evidence commit: `e031ba0`
- Scope: read-only runtime evidence requested by branch2
- Step4 functional interpretation: not performed

## 1. Conclusion

The final diagnostic shows that the Master boot script does not enter `cmd_vlan()` during the observation window. The packet-filter markers visible on Master are the completed generic-board initialization path, not the `vlan off` shell-command path:

```text
Master:
VLAN_CMD_ENTER             = 0
PFILTER_ENTER              = 1
PFILTER_BEFORE_DISABLE     = 1
PFILTER_RULE_INDEX         = 30
PFILTER_AFTER_RULE_WRITE   = 1
PFILTER_BEFORE_ENABLE      = 1
PFILTER_RETURN             = 1
VLAN_CMD_RETURN            = 0

Slave:
VLAN_CMD_ENTER             = 1
PFILTER_ENTER              = 1
PFILTER_BEFORE_DISABLE     = 1
PFILTER_RULE_INDEX         = 30
PFILTER_AFTER_RULE_WRITE   = 1
PFILTER_BEFORE_ENABLE      = 1
PFILTER_RETURN             = 1
VLAN_CMD_RETURN            = 1
```

The command index from the preceding boot diagnostic was `1` on Master and remained there. That index is published immediately before `shell_exec()` is called. Since the first line of `cmd_vlan()` publishes `VLAN_CMD_ENTER`, the combination of `BOOT_INIT_COMMAND_INDEX=1` and `VLAN_CMD_ENTER=0` means the Master run did not reach the `cmd_vlan()` handler (or its first statement). It is therefore not evidence of a pfilter rule or pfilter MMIO write hang.

The next blocker is now narrower: the Master boot path is stopping before the `vlan` command handler, in the `shell_exec()` command-dispatch/entry path. The pfilter implementation itself completed its earlier board-initialization call through rule index 30. The final diagnostic used no additional endpoint MMIO reads, so the observation does not introduce a read-side wait into the path being diagnosed.

## 2. Diagnostic mapping

The existing private mapping counter/inverse words at `0x00100B34` and `0x00100B38` retain their low 16-bit counter and inverse. Their high 16 bits carry the progress value:

```text
bit  0  VLAN_CMD_ENTER
bit  1  PFILTER_ENTER
bit  2  PFILTER_BEFORE_DISABLE
bits 3..8  PFILTER_RULE_INDEX (6-bit current/last rule index)
bit  9  PFILTER_AFTER_RULE_WRITE
bit 10  PFILTER_BEFORE_ENABLE
bit 11  PFILTER_RETURN
bit 12  VLAN_CMD_RETURN
```

The checkpoint calls only write the existing WDIAGS diagnostic area. The endpoint packet-filter sequence remains unchanged:

```text
PFCR0 disable
for each filter rule:
    PFCR1 rule data
    PFCR0 rule address/data/write
PFCR0 enable
```

## 3. Build and programming

Both firmware/FPGA builds passed:

```text
Master Quartus build passed: .../output_files_master_jtag/DE5a_wr_master_jtag.sof (timing_closed=NO)
Slave  Quartus build passed: .../output_files_slave_jtag/DE5a_wr_slave_jtag.sof (timing_closed=NO)
```

`timing_closed=NO` is the existing timing baseline; this experiment changed firmware observability only.

Both boards were programmed successfully with 0 errors and 0 warnings:

```text
Master cable: DE5 [1-11.1], SOF checksum: 0x30B1722A
Slave  cable: DE5 [1-11.2], SOF checksum: 0x30B05EEB
```

Final rebuilt artifact SHA-256 values from pain:

```text
Master wrc.elf: fbd5371fca151414e6f2720f4caf3e5c4c4d7049f151d62340d56e535455bd11
Master wrc.mif: 8eaf6c888e88244df7706477df64bcf547611a8636980c360ffd1855a53c65f1
Master SOF:    3059db5d47ae24a490efee12522456ab07e1ef5310c99509b88295499746a59f
Slave  wrc.elf: 73f0cd9db05972f97d52358757aff2d147fdf3e626d0ac88a918571358fb46e9
Slave  wrc.mif: d84226e22f3df6279e94aff342829a485c26094e67d7443ae47d511980524e7b
Slave  SOF:    996245ec179a13bc601a504556b439969dc7db0ee0266b81cdf5ffa46a1e4005
```

## 4. Runtime observation

The final read-only command was:

```text
quartus_stp -t scripts/jtag/read_vlan_pfilter_progress_diag.tcl 12 1000
```

The final Master samples after the initial post-program clear showed:

```text
COUNTER high16 = 0x0EF6
VLAN_CMD_ENTER=0
PFILTER_ENTER=1
PFILTER_BEFORE_DISABLE=1
PFILTER_RULE_INDEX=30
PFILTER_AFTER_RULE_WRITE=1
PFILTER_BEFORE_ENABLE=1
PFILTER_RETURN=1
VLAN_CMD_RETURN=0
```

The first Master sample was taken before the periodic mapping writer had republished the progress shadow and therefore showed zero progress; subsequent samples retained the same marker state. One later counter/inverse pair crossed a periodic counter increment and failed the low-16 coherence check, while the high-bit progress fields remained unchanged. This is a read-timing artifact of reading two independently updating diagnostic words, not a change in the checkpoint state.

Slave samples 1–12 retained the complete state, including `VLAN_CMD_ENTER=1` and `VLAN_CMD_RETURN=1`, with rule index 30. This confirms that the new instrumentation and WDIAGS mapping are functional on the same two image roles.

## 5. Preliminary read-side run

Before the final rebuild, an initial version of the checkpoint helper read the current WDIAGS counter before writing the overlay. Those outputs are preserved as `preliminary_with_read` raw files but are not used for the conclusion. The final firmware removed that read and was rebuilt, reprogrammed, and observed again; the Master result remained `VLAN_CMD_ENTER=0` with completed board-init pfilter markers.

## 6. Branch2 handoff classification

```text
Master boot script entered: yes (prior diagnostic ENTER=1)
Master boot command index: 1
Master cmd_vlan entered: no (VLAN_CMD_ENTER=0)
Master pfilter board-init path: completed through rule index 30
Master cmd_vlan returned: no
```

The evidence now points to the command-dispatch/handler-entry boundary around `shell_exec("vlan off")`, before the first statement of `cmd_vlan()`. The next investigation should stay firmware-only and inspect the shell command lookup/tokenization/dispatch path or its immediate entry behavior. It should not remove `vlan off`, alter packet-filter writes, change DMTD/SoftPLL settings, or run Step4.

## Evidence

- Final raw read: `raw/EXP-WRPC-STEP4-FIRMWARE-ONLY-VLAN-PFILTER-DIAG-20260826/vlan_pfilter_diag_final_no_read.txt`
- Preliminary raw read (not used for conclusion): `raw/EXP-WRPC-STEP4-FIRMWARE-ONLY-VLAN-PFILTER-DIAG-20260826/vlan_pfilter_diag_preliminary_with_read.txt`
- Preliminary long raw read (not used for conclusion): `raw/EXP-WRPC-STEP4-FIRMWARE-ONLY-VLAN-PFILTER-DIAG-20260826/vlan_pfilter_diag_preliminary_with_read_long.txt`
- Reader: `scripts/jtag/read_vlan_pfilter_progress_diag.tcl`
- Prior boot-init diagnostic: `EXP-WRPC-STEP4-FIRMWARE-ONLY-BOOT-INIT-DIAGNOSTIC-20260826.md`
