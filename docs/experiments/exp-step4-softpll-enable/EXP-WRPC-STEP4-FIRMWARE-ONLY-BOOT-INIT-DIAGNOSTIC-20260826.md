# EXP-WRPC-STEP4：firmware-only boot init execution diagnostic

- Date: 2026-08-26
- Branch: `exp/step4-softpll-enable`
- Firmware/diagnostic commit: `55a7077`
- Raw-evidence commit: `49e406c`
- Scope: read-only runtime evidence requested by branch2
- Step4 functional interpretation: not performed

## 1. Conclusion

The new firmware-only diagnostic shows that the Master image enters the compiled boot-init script but does not reach `mode master` during the observation window:

```text
Master: BOOT_INIT_SCRIPT_ENTER_COUNT=1
        BOOT_INIT_COMMAND_INDEX=1
        MODE_MASTER_CALL_COUNT=0
        MODE_MASTER_RETURN_COUNT=0

Slave:  BOOT_INIT_SCRIPT_ENTER_COUNT=1
        BOOT_INIT_COMMAND_INDEX=4
        MODE_MASTER_CALL_COUNT=0
        MODE_MASTER_RETURN_COUNT=0
```

The command index is 1-based and is updated immediately before each init command is passed to `shell_exec()`. The Master value stayed at index 1 for 12 samples over approximately 11 seconds. With the Master configuration `vlan off;ptp stop;mode master;ptp start`, this means the observed execution did not advance beyond the first command and never entered the Master setter. Therefore `MODE_MASTER_CALL_COUNT=0` and `MODE_MASTER_RETURN_COUNT=0` are evidence that this run did not test a failing or non-returning `wrc_ptp_set_mode(WRC_MODE_MASTER)` call.

The Slave image reached index 4, as expected for its four-command script. Its zero Master counters are expected because its script contains `mode slave`, not `mode master`.

This is the requested runtime evidence for branch2 classification A: the Master init path is not reaching the `mode master` command. It does not by itself identify why command 1 does not return. No DMTD, threshold, reverse, SoftPLL, FSM, RTL, or Step4 functional change was made or interpreted.

## 2. Diagnostic implementation

Four firmware-only diagnostic fields are published through the existing `WDIAG_PTPSTAT` register at Wishbone address `0x00100A10`:

```text
bits  0.. 7  existing PPSI PTP state (unchanged)
bits  8..11  BOOT_INIT_SCRIPT_ENTER_COUNT
bits 12..15  BOOT_INIT_COMMAND_INDEX (1-based current/last index)
bits 16..23  MODE_MASTER_CALL_COUNT
bits 24..31  MODE_MASTER_RETURN_COUNT
```

The call counter is incremented and published immediately before `wrc_ptp_set_mode(WRC_MODE_MASTER)` is invoked through the shell command table. The return counter is incremented and published immediately after the setter returns. This preserves the ability to distinguish a setter that is entered but does not return.

The existing readers were changed to validate only the PTP state low byte, so the added high-bit evidence does not invalidate the normal PTP-state checks.

## 3. Build and programming

Pain built both images successfully:

```text
Master Quartus build passed: .../output_files_master_jtag/DE5a_wr_master_jtag.sof (timing_closed=NO)
Slave  Quartus build passed: .../output_files_slave_jtag/DE5a_wr_slave_jtag.sof (timing_closed=NO)
```

The existing timing baseline remains `timing_closed=NO`; this diagnostic did not modify RTL timing paths.

Both devices were programmed successfully with 0 errors and 0 warnings:

```text
Master cable: DE5 [1-11.1], SOF checksum: 0x30B1722A
Slave  cable: DE5 [1-11.2], SOF checksum: 0x30B05EEB
```

The rebuilt firmware artifacts were verified on pain by SHA-256:

```text
Master wrc.elf: fbd5371fca151414e6f2720f4caf3e5c4c4d7049f151d62340d56e535455bd11
Master wrc.mif: 8eaf6c888e88244df7706477df64bcf547611a8636980c360ffd1855a53c65f1
Slave  wrc.elf: 73f0cd9db05972f97d52358757aff2d147fdf3e626d0ac88a918571358fb46e9
Slave  wrc.mif: d84226e22f3df6279e94aff342829a485c26094e67d7443ae47d511980524e7b
```

## 4. Runtime observation

The read-only command was:

```text
quartus_stp -t scripts/jtag/read_boot_init_execution_diag.tcl 5 100
quartus_stp -t scripts/jtag/read_boot_init_execution_diag.tcl 12 1000
```

The first run returned:

```text
DE5 [1-11.1] RAW=00001104 PTP_STATE=4 ENTER=1 INDEX=1 MASTER_CALL=0 MASTER_RETURN=0
DE5 [1-11.2] RAW=00004109 PTP_STATE=9 ENTER=1 INDEX=4 MASTER_CALL=0 MASTER_RETURN=0
```

In the longer run, Master samples 1–12 remained at `INDEX=1, CALL=0, RETURN=0`. The low-byte PTP state changed between 6 and 4 while the boot evidence remained unchanged. Slave samples 1–12 remained at `INDEX=4, CALL=0, RETURN=0`; its low-byte PTP state varied between 9 and 4. These low-byte changes do not alter the boot-init conclusion.

## 5. Branch2 handoff classification

```text
Master: script entered = yes
        command index 1 published immediately before command 1 execution = yes
        command 2 or later reached = no during ~11 s observation
        mode master setter called = no
        mode master setter returned = no
```

The most precise current statement is: the Master firmware reached the boot-init command loop and published command index 1, but the loop did not advance to `ptp stop` or `mode master` during the observation. The next investigation should therefore focus on the first init command execution/return path, as branch2 directs; it should not yet change DMTD or interpret Step4 behavior.

## Evidence

- Raw short read: `raw/EXP-WRPC-STEP4-FIRMWARE-ONLY-BOOT-INIT-DIAG-20260826/boot_init_diag.txt`
- Raw long read: `raw/EXP-WRPC-STEP4-FIRMWARE-ONLY-BOOT-INIT-DIAG-20260826/boot_init_diag_long.txt`
- Reader: `scripts/jtag/read_boot_init_execution_diag.tcl`
- Prior source audit: `EXP-WRPC-STEP4-SOURCE-ONLY-MASTER-MODE-WRITE-PATH-AUDIT-20260826.md`
