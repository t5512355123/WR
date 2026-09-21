# EXP-S6-MASTER-LAST-EXACT-IMAGE-RECOVERY-ATTRIBUTION-20260921

## Verdict

```text
RESULT                         = NOT_RUN_ARTIFACT_UNAVAILABLE
HARDWARE_PROGRAMMING           = NOT_PERFORMED
MASTER_PROGRAM_COUNT           = 0
SLAVE_PROGRAM_COUNT            = 0
MASTER_FULL_COMPILE             = 0
SLAVE_FULL_COMPILE              = 0
FIRMWARE_BUILD                  = 0
POWER_CYCLE                     = 0
STEP6A_GLOBAL_TIME              = NOT_PASS
STEP6B_SCHEDULED_TRIGGER        = NOT_RUN
```

The experiment was stopped before hardware programming because the exact
Master bitstream required by the same-image A/B comparison was unavailable.
This is an artifact-availability stop, not a hardware result and not an
`INCONCLUSIVE` hardware observation.

## Required artifact

```text
SOURCE_COMMIT       = ec1f25e81e0eb8c2caee796d13a225eaae81e5f2
EXPECTED_MASTER_SOF = 568f08c974064bdd3e82f68e3f1ecb0ff6c8a2a8e5705bdcc15b5941d33173a3
EXPECTED_SLAVE_SOF  = 7fefa7afae8bd2070276c94cd5caac73a0f3748139c609c6f4ab423a3680773e
EXPECTED_PATH       = quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof
MASTER_CABLE        = DE5 [1-11.1]
SLAVE_CABLE         = DE5 [1-11.2]
```

The expected Master artifact was the original `ec1f25e8` output used by the
earlier Step6A run.  The Git tree does not contain the `.sof` binary.

## Evidence collected

On Pain, the current worktree was verified at `d30094b8` and the observer
runner passed shell syntax validation.  The expected path existed, but its
current file was a later diagnostic image:

```text
PATH = quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof
SHA256 = f371c0ed3df88f629d1c57d2333246395a92993420435039619867fe88449487
```

That hash did not match `568f08...`, so it was not used.

The following read-only searches found no matching `568f08...` file:

1. All `.sof` files below `/home/b10504072/04_WR` on Pain.
2. All local `.sof` files in the synchronized research, Downloads, and
   Desktop locations.
3. Git tree/history and tracked `.sof` paths.
4. Pain NFS home snapshot locations.  `/home` is an NFS mount, but no
   `.snapshot`, `#snapshot`, or `@snapshot` directory was present.  The
   user-level `snap` directory only contains `snapd-desktop-integration`.

The adviser confirmed that recompiling `ec1f25e8` would not recreate the
original exact SHA and therefore must not be called an exact-artifact run.

## Hardware actions explicitly not taken

```text
No Quartus compilation
No firmware build
No Master programming
No Slave programming
No reset or power cycle
No PHY/PTP restart
No mode, MDIO, SI5340, fiber, QSFP, polarity, bitslip, or autoneg change
```

The original exact-image experiment is therefore closed without a hardware
verdict.  A future rebuild must use a new experiment name and may only claim
`ec1f25e8-source rebuild Master-last` behavior, never the original
`568f08...` exact-image result.

