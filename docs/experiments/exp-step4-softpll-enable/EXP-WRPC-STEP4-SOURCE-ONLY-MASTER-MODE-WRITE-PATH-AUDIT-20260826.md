# EXP-WRPC-STEP4：Master mode write-path source-only audit

- Date: 2026-08-26
- Branch: `exp/step4-softpll-enable`
- Audited commit: `aedb9bbd2c8725e87b1b200bcc557c85029d1aa1`
- Scope: source/config read-only audit requested by branch2
- Build/program action in this step: none

## 1. Conclusion

The selected DE5a firmware is built for the generic 8-bit PHY target, not ERTM14. The active generic-target source has one embedded default mode write to `WRC_MODE_SLAVE`; the Master request is dispatched only through the built-in shell command path. There is no second generic-target writer that would normally change a successfully selected Master back to Slave.

The source path is:

```text
wrc_initialize()
  -> wrc_ptp_set_mode(WRC_MODE_SLAVE)
  -> wrc_ptp_start()
  -> wrc_tasks_run_inits()
       -> shell_boot_script()
            -> CONFIG_INIT_COMMAND splitter
            -> shell_exec("mode master")
                 -> cmd_ptp()
                 -> wrc_ptp_set_mode(WRC_MODE_MASTER)
  -> boot marker B004
  -> diags task reads wrc_ptp_get_mode()
```

For the Master image, the source/config evidence therefore does not support a normal post-boot “Master was selected, then another writer reset WRC mode to Slave” explanation. The remaining source-level distinction is between the init command not reaching/executing the `mode master` writer and a runtime/telemetry condition not visible from source. A direct `wrc_ptp_set_mode()` error is not sufficient by itself to explain mode 3: the implementation assigns `ptp_mode = mode` after the bounded PLL wait, including the timeout-return path, unless the function fails to return or the CPU is reset.

## 2. Target and build-selection audit

The generated Master and Slave configs used for the B image both show:

```text
CONFIG_ARCH_RISCV=y
CONFIG_TARGET_GENERIC_PHY_8BIT=y
# CONFIG_TARGET_ERTM14 is not set
CONFIG_WR_NODE=y
CONFIG_EMBEDDED_NODE=y
CONFIG_WRPC_PPSI=y
CONFIG_BUILD_INIT=y
CONFIG_WR_DIAG=y
CONFIG_IP=y
CONFIG_LLDP=y
CONFIG_SNMP=y
```

`vendor/wrpc-sw/boards/boards.mk` selects `boards/generic/board.o` for `CONFIG_TARGET_GENERIC_PHY_8BIT`; the ERTM14 objects are guarded by `CONFIG_TARGET_ERTM14`. The generic `wrc_board_create_tasks()` returns without adding a board-specific task. The generic board also does not define a larger task table, so `WRC_MAX_TASKS` remains the default 20.

The built-in commands are present in the selected config:

```text
Master: CONFIG_INIT_COMMAND="vlan off;ptp stop;mode master;ptp start"
Slave:  CONFIG_INIT_COMMAND="vlan off;ptp stop;mode slave;ptp start"
CONFIG_STEP2_DISABLE_PERSISTENT_INIT=y
```

The corresponding strings are present in the actual B-image ELF files:

```text
build/firmware/master/wrc.elf  f02f27ba183a9270bee9f9bd68bf0f12008b874f99d216722b54ac825f64554e
build/firmware/slave/wrc.elf   f95e2583a0442ad2509718aeebbf214fd8857de8faabfc55d7cc7444485c5470
```

The ELF strings are respectively `vlan off;ptp stop;mode master;ptp start` and `vlan off;ptp stop;mode slave;ptp start`, together with `executing: %s`.

## 3. WRC mode writer inventory

### Embedded generic path

- `vendor/wrpc-sw/wrc_main.c:165` calls `wrc_ptp_set_mode(WRC_MODE_SLAVE)` during `wrc_initialize()`.
- `vendor/wrpc-sw/shell/cmd_ptp.c:72-74` maps `gm`, `master`, and `slave` subcommands to `wrc_ptp_set_mode`; `mode` and `ptp` are both registered by `shell_register_commands()`.
- `vendor/wrpc-sw/ppsi/arch-wrpc/wrc_ptp_ppsi.c:191-274` contains the RISC-V/WRPC implementation.
- `ptp_mode` is assigned only at `wrc_ptp_ppsi.c:203` (temporary zero during a mode change) and `wrc_ptp_ppsi.c:268` (the requested mode). `wrc_ptp_get_mode()` returns this value at lines 276-279.

### Non-active matches excluded from this DE5a image

- `vendor/wrpc-sw/host/ptp.c:6-10` is the host stub; it is not the embedded WRPC implementation.
- `vendor/wrpc-sw/boards/ertm14/board.c:1452` is an ERTM14 control-packet writer, excluded because `CONFIG_TARGET_ERTM14` is unset and the generated build selects the generic board.

### Related state writes that are not WRC mode writes

The source also writes `timingMode` and WR-extension `wrConfig` in the Master/Slave setter, SoftPLL locking callbacks, link-down handling, and WR hooks. These can affect clock/WR-extension state, but they do not assign the `ptp_mode` value returned by `wrc_ptp_get_mode()` and therefore do not explain a WDIAGS WRC mode value of 3 as a second WRC-mode writer.

## 4. Init and command execution path

`wrc_main.c` creates the normal generic task set before `wrc_initialize()`:

```text
idle, check-link, uptime, ptp, ptp_bmc, shell+gui, spll-bh,
net-bh, arp, ipv4, lldp, snmp, stats, diags = 14 tasks
```

This is below `WRC_MAX_TASKS=20`; the shell task is not expected to be rejected for lack of task slots. The shell command array has capacity 40, and `mode` and `ptp` are explicitly registered before the init script is run.

After `wrc_initialize()` completes its default Slave setup, `wrc_tasks_run_inits()` invokes each registered task init function. The `shell+gui` task init is `shell_boot_script()`. That function splits the compiled `CONFIG_INIT_COMMAND` at semicolons and calls `shell_exec()` for each command. `CONFIG_STEP2_DISABLE_PERSISTENT_INIT` only disables the persistent flash-init loop; it does not disable the compiled `CONFIG_INIT_COMMAND` loop.

`cmd_ptp()` recognizes `master` and passes `WRC_MODE_MASTER` (numeric value 2) to the setter. The `mode` command is therefore not a separate mode implementation or an ERTM14-only path.

## 5. Master setter behavior

For `WRC_MODE_MASTER`, `wrc_ptp_set_mode()`:

1. clears the local `ptp_mode` to 0;
2. stops PTP;
3. sets WR config to `WR_M_AND_S` and timing mode to `WRH_TM_FREE_MASTER`;
4. initializes the SoftPLL as free-running Master;
5. enables timing output and sets the free-running clock class;
6. waits in `wrpc_spll_check_lock_with_timeout(LOCK_TIMEOUT_FM)` with a 20-second bound;
7. assigns `ptp_mode = mode` and `wrpcModeCfg = mode`;
8. returns the PLL result.

`wrpc_spll_check_lock_with_timeout()` returns `-ETIMEDOUT` on timeout but does not prevent the subsequent mode assignment in `wrc_ptp_set_mode()`. Thus, if the setter is entered and returns normally, the WDIAGS source should later expose mode 2, even if the PLL did not lock. Mode 3 is consistent with the initial default Slave value when the Master setter is not reached; it is not explained by a normal bounded-lock error alone.

## 6. WDIAGS telemetry audit

`vendor/wrpc-sw/lib/task-diags.c` calls:

```c
wdiags_write_ptp_debug(..., (uint8_t)wrc_ptp_get_mode());
```

`vendor/wrpc-sw/dev/wdiags.c` stores that final argument in bits 31:24 of the AUX3 detail register. The JTAG readers decode the MODE field from `0x00100A5C` by taking bits 31:24. The source path is therefore direct: WDIAGS MODE is the embedded `wrc_ptp_get_mode()` shadow, not PPSI `ppi->state` and not WR-extension `wrConfig`.

## 7. Correlation with B-image timeline

The read-only boot timeline already recorded:

```text
Master: MAC ...01, B004 100/100, WDIAGS mode 3(SLAVE) 100/100,
        PTP LISTENING 88/100 and MASTER 12/100, no mode 2 observed.
Slave:  MAC ...02, B004 100/100, WDIAGS mode 3(SLAVE) 100/100,
        PTP mostly SLAVE, no mode 2 observed.
```

The Master PTP state changing to `PPS_MASTER` in 12 samples does not change the WRC mode conclusion: PPSI state and the WRC mode shadow are separate source fields.

## 8. Branch2 classification requested

- **A — init command not executed/reached:** currently the most consistent explanation for Master WDIAGS mode remaining 3, but the exact runtime reason is not proven by source alone.
- **B — command executed but failed:** not supported as a complete explanation if `wrc_ptp_set_mode()` returns normally, because the requested mode is assigned after the bounded lock wait. A non-returning fault or reset remains a separate runtime possibility.
- **C — command succeeded, then another writer reset WRC mode to Slave:** no active generic-target second writer was found; the only normal embedded default writer is the earlier initialization call, and the ERTM14 writer is excluded.
- **D — WDIAGS telemetry does not reflect mode:** not supported by the source mapping; WDIAGS directly stores `wrc_ptp_get_mode()`. A stale probe/register sample cannot be ruled out by source inspection, but it is not a firmware mapping discrepancy.

No RTL, firmware, configuration, DMTD, threshold, reverse, SoftPLL, FSM, or Step4 functional change was made in this audit. The next diagnostic change, if authorized by branch2, should be firmware-only and expose init-command execution/return evidence without adding RTL counters.

## Evidence

- B-image boot timeline report: `EXP-WRPC-STEP4-B-IMAGE-ROLE-TRANSITION-TIMELINE-20260826.md`
- B-image provenance report: `EXP-WRPC-STEP4-B-IMAGE-ROLE-FIRMWARE-PROVENANCE-AUDIT-20260826.md`
- Raw source-audit snapshot: `raw/EXP-WRPC-STEP4-SOURCE-ONLY-MASTER-MODE-WRITE-PATH-AUDIT-20260826/source_audit_snapshot.txt`
