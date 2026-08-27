# EXP-WRPC-STEP4-PERSISTENT-MODE-MASTER-STAGE-ACROSS-REENTRY-20260827

## Purpose

Following branch 2's latest instruction, this round made the mode-master
stage evidence survive CPU-only re-entry. The change is observability-only:
the existing `.debug_precrt` `NOLOAD` record now retains the latest
mode-master stage, lock-wait sub-stage, generation at the recorded stage, and
the last four mode-master stages. The record is republished through dedicated
read-only WDIAGS words after `wdiags_init()` so the capture can remain
passive, without CPU hold/release or CPU-host-RAM live reads.

The Master boot command remained:

```text
vlan off;ptp stop
```

Only one manual JTAG-VUART command was sent:

```text
mode master
```

No reset logic, SoftPLL algorithm, timeout, IRQ/fault handler, DMTD, DCO,
PTP/PHY behavior, or functional role logic was changed.

## Persistent record and read-only mirror

The persistent record is placed after the existing fixed `.debug_precrt`
fields. Each field has a distinct linker input section and the linker script
keeps the order explicit, preventing LTO from moving the existing fixed
addresses.

| Persistent field | `.debug_precrt` byte address | Read-only WDIAGS offset | CPU read address |
| --- | ---: | ---: | ---: |
| `PERSIST_MAGIC` | `0x0002e030` | `0x170` | `0x00100B70` |
| `PERSIST_MODE_MASTER_STAGE` | `0x0002e034` | `0x174` | `0x00100B74` |
| `PERSIST_LOCK_WAIT_SUBSTAGE` | `0x0002e038` | `0x178` | `0x00100B78` |
| `PERSIST_BOOT_GENERATION_AT_STAGE` | `0x0002e03c` | `0x17c` | `0x00100B7C` |
| `PERSIST_STAGE_HISTORY[0..3]` | `0x0002e040..0x0002e04f` | `0x180..0x18c` | `0x00100B80..0x00100B8C` |

`PERSIST_MAGIC=0x504D5354` means the record is valid. A valid record is not
cleared by `wdiags_init()`; only an invalid/uninitialized record is seeded.
Nonzero mode-master stages shift the four-entry history and record the
current `BOOT_GENERATION`. Nonzero lock-wait sub-stages update only the
persistent lock-wait sub-stage. The WDIAGS mirror is read-only and does not
feed back into WR control.

## Reproducibility record

```text
SOURCE_COMMIT=5988a6c77db4c8d70ed348c45211ecb077b77b6a
EXPERIMENT_BRANCH=exp/step4-softpll-enable
MASTER_CONFIG_INIT_COMMAND="vlan off;ptp stop"
SLAVE_CONFIG_INIT_COMMAND="vlan off;ptp stop;mode slave;ptp start"
CAPTURE_COMMAND="quartus_stp -t scripts/jtag/read_manual_mode_master_transition_forensics.tcl 110 250 25 5"
MASTER_PROGRAMMER_CHECKSUM=0x30B37E9B
SLAVE_PROGRAMMER_CHECKSUM=0x30B4455C
MASTER_JTAG_ID=0x02E660DD
SLAVE_JTAG_ID=0x02E660DD
MASTER_TIMING_CLOSED=NO
MASTER_WNS_NS=-0.383
MASTER_HNS_NS=+0.038
SLAVE_TIMING_CLOSED=NO
SLAVE_WNS_NS=-0.307
SLAVE_HNS_NS=+0.038
QUARTUS_PROGRAMMER_VERSION=17.0.0_Build_595
QUARTUS_SIGNAL_TAP_VERSION=21.3.0_Build_170
```

Fresh full Quartus builds passed for both images. Both devices were freshly
programmed successfully on `DE5 [1-11.1]` (Master) and `DE5 [1-11.2]`
(Slave), with zero programmer errors and warnings. Artifact hashes are in
the raw directory's `artifact_sha256.txt`.

## Healthy baseline

Before the manual stimulus:

- Probe reads were `001E32E130F082EF` (Master) and `001018C3245082EF`
  (Slave); the status records retained the healthy CPU/link/configuration
  bits.
- Master boot-init evidence settled at `PTP_STATE=4`, script enter count 1,
  command index 2, mode-master call/return counts 0/0.
- Slave boot-init evidence settled at `PTP_STATE=4`, script enter count 1,
  command index 4, mode-master call/return counts 0/0.
- The six-sample persistent forensics baseline showed
  `PERSIST_MAGIC=504D5354`, persistent stage/sub-stage 0, generation-at-stage
  0, and history 0/0/0/0 on both boards.
- Master remained firmware `MODE=3(SLAVE)` / PTP listening; Slave remained
  firmware `MODE=3(SLAVE)` / PTP slave in the stable baseline samples.

## Stimulus and capture

The capture used 110 samples at 250 ms spacing. It did not hold/release the
CPU and did not write a reset register. At Master sample 5 it injected exactly
one command through the JTAG Wishbone virtual UART. All 12 byte writes
completed at Wishbone level. Master sampling covered approximately 35.384 s;
Slave sampling covered approximately 35.347 s.

## Observed result

Master samples 1–5 showed the healthy pre-stimulus state:

```text
BOOT_GENERATION=00000002
MODE_MASTER_STAGE=00000000
PERSIST_MODE_MASTER_STAGE=00000000
PERSIST_LOCK_WAIT_SUBSTAGE=00000000
PERSIST_BOOT_GENERATION_AT_STAGE=00000000
PERSIST_STAGE_HISTORY=00000000,00000000,00000000,00000000
```

From Master sample 6 through sample 110:

```text
BOOT_GENERATION=00000004
MODE_MASTER_STAGE=00000000
LOCK_WAIT_SUBSTAGE=00000000
PERSIST_MAGIC=504D5354
PERSIST_MODE_MASTER_STAGE=00000004
PERSIST_LOCK_WAIT_SUBSTAGE=00000001
PERSIST_BOOT_GENERATION_AT_STAGE=00000002
PERSIST_STAGE_HISTORY=00000001,00000002,00000003,00000004
```

The ordinary WDIAGS
stage and lock-wait words were zero after re-entry, while the persistent
record retained stage 4 and lock-wait sub-stage 1. The history proves the
mode-master path reached stages 1, 2, 3, and 4 in order. The lock-wait
sub-stage 1 means `wrpc_spll_check_lock_with_timeout()` was entered; no later
sub-stage was persistently observed.

The Master post-capture boot-init evidence remained command index 2 with
mode-master call/return counts 0/0 because the re-entry reset the ordinary
diagnostic shadows. The post-capture persistent reader reproduced the same
stage 4, sub-stage 1, generation 2, and history 1/2/3/4 values.

Slave received no command and retained persistent mode-master stage 0,
lock-wait sub-stage 0, and history 0/0/0/0 in its stable samples. A few late
Slave reader samples contained transient malformed mirror values while the
magic/status words were also changing; those samples were not repeatable and
are treated as read artifacts, not mode-master evidence. The post-capture
stable Slave samples returned to stage 0.

## Interpretation

```text
VALID_MANUAL_JTAG_VUART_STIMULUS=YES
MASTER_BOOT_GENERATION=2_THEN_4
MASTER_PERSISTENT_MAGIC=VALID
MASTER_PERSISTENT_STAGE=4
MASTER_PERSISTENT_LOCK_WAIT_SUBSTAGE=1
MASTER_PERSISTENT_BOOT_GENERATION_AT_STAGE=2
MASTER_PERSISTENT_STAGE_HISTORY=1,2,3,4
REENTRY_AFTER_MODE_MASTER_ENTRY=PROVEN
BOUNDARY=after pre-lock-wait marker and after lock-wait function entry,
          before the next persistent lock-wait boundary was recorded,
          or around the re-entry itself
ORDINARY_WDIAGS_MARKERS_CLEARED_BY_REENTRY=SUPPORTED
SLAVE_MODE_MASTER_PATH=NOT_ENTERED
ROOT_CAUSE=NOT_PROVEN
```

This round proves that the Master reached the mode-master path through the
pre-lock-wait marker and entered the lock-wait function before the observed
generation change. It does not prove whether the re-entry happened inside
`spll_check_lock()`, between the lock-wait sub-stages, or through another
trigger close to that point. It also does not by itself prove a hardware
reset source or identify a root cause. Per branch 2's instruction, no repair
was attempted.

## Raw evidence

Raw files are stored in:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-PERSISTENT-MODE-MASTER-STAGE-ACROSS-REENTRY-20260827/`

Important files:

- `baseline_persistent_forensics.log`
- `forensics_manual_mode_master.log` — one 12-byte Master stimulus and the
  110-sample capture
- `post_capture_persistent_forensics.log`
- `baseline_boot_init_diag.log` and `post_capture_boot_init_diag.log`
- `baseline_role_timeline.log`
- `artifact_sha256.txt`, `timing_summary.txt`, `source_commit.txt`, and
  `raw_file_inventory.txt`
