# EXP-WRPC-STEP4-LOCK-WAIT-INTERNAL-SUBSTAGE-FORENSICS-20260827

## Purpose

Following branch 2's latest instruction, this round added only read-only
observability inside `wrpc_spll_check_lock_with_timeout()`. The experiment was
intended to distinguish `spll_update()`, `timer_delay()`, timer progress, and
timeout-control-flow boundaries after one manual `mode master` command.

The Master boot command remained:

```text
vlan off;ptp stop
```

No SoftPLL algorithm, timeout value, timer semantics, IRQ behavior, fault
handler, DMTD, RAM, reset logic, PTP functional behavior, PI parameter, or DCO
behavior was changed.

## Added diagnostic observability

The private WDIAGS area was extended to offset `0x16c` (`g_wdiags_num_words =
92`). The new words are direct firmware shadows and do not feed back into WR
control:

| Offset | CPU address | Meaning |
| ---: | ---: | --- |
| `0x15c` | `0x00100B5C` | `LOCK_WAIT_SUBSTAGE` |
| `0x160` | `0x00100B60` | `LOCK_WAIT_ITERATION` |
| `0x164` | `0x00100B64` | `LOCK_WAIT_START_TICS` |
| `0x168` | `0x00100B68` | `LOCK_WAIT_CURRENT_TICS` |
| `0x16c` | `0x00100B6C` | `LOCK_WAIT_LAST_LOCK_RESULT` |

Sub-stage values:

```text
0 = not entered
1 = function entered
2 = after spll_check_lock()
3 = before spll_update()
4 = after spll_update()
5 = before timer_delay()
6 = after timer_delay()
7 = after timeout comparison
8 = function return
```

The original short-circuit behavior is preserved: with `lock_timeout == 0`,
`spll_check_lock()` is still not called. The diagnostic words are reset to
zero by `wdiags_init()` so a fresh boot starts at sub-stage 0.

## Reproducibility record

```text
SOURCE_COMMIT=b3dcd46096769eff9519ee98d8f55f0a96cadafb
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
QUARTUS_PROGRAMMER_VERSION=17.0.0 Build 595
QUARTUS_SIGNAL_TAP_VERSION=21.3.0 Build 170
```

Fresh builds passed for both images. Artifact SHA-256 values are recorded in
the raw directory's `artifact_sha256.txt` and are:

```text
MASTER_SOF_SHA256=f226faecdf54426624655c478300836d334df7c8e7297dd3f3508333c070a9fd
MASTER_MIF_SHA256=87697ac86fef992dc8ad2f14bc1306837b30c0101ea625aa854e7032c8a25a7c
SLAVE_SOF_SHA256=09ea0db42d4d2556c433f643699f34fd7d7a13bf37d16d6138ab780b08f76266
SLAVE_MIF_SHA256=15f6ffaffd5ce607684b32996bd51a1ed954b4ce2c2c70cd374d4d9398aabc49
```

Both devices were freshly programmed successfully on `DE5 [1-11.1]` (Master)
and `DE5 [1-11.2]` (Slave), with zero programmer errors and warnings.

## Healthy baseline

Before the manual stimulus:

- Probe reads were `001E90C1295C82EF` (Master) and `0010D841225082EF` (Slave).
  The sampled `CPU_RESET_N`, link, PHY-ready, and configuration bits were
  asserted healthy.
- Master boot-init diagnostic: `PTP_STATE=4`, script enter count 1, command
  index 2, mode-master call count 0, return count 0.
- Slave boot-init diagnostic: `PTP_STATE=9`, script enter count 1, command
  index 4, mode-master call count 0, return count 0.
- The six-sample forensics baseline showed `MODE_MASTER_STAGE=0` and every
  `LOCK_WAIT_*` field equal to zero on both boards.
- The role timeline retained the normal Master firmware mode `SLAVE` and did
  not show a mode-master call. Transient PTP/reader values are retained in the
  raw log and are not used as causal evidence.

## Stimulus and capture

The capture used 110 samples at 250 ms spacing. The script read the diagnostic
area before and after the stimulus and did not hold/release the CPU or write a
reset register. At Master sample 5 it wrote exactly one command through the
JTAG Wishbone VUART:

```text
mode master\n
```

All 12 byte writes reached Wishbone completion. The Slave cable was not used
for command injection. Master sampling covered approximately 33.059 seconds;
Slave sampling covered approximately 32.980 seconds.

## Observed result

Master samples 1–5 showed:

```text
BOOT_GENERATION=00000002
MODE_MASTER_STAGE=00000000
LOCK_WAIT_SUBSTAGE=00000000
LOCK_WAIT_ITERATION=00000000
LOCK_WAIT_START_TICS=00000000
LOCK_WAIT_CURRENT_TICS=00000000
LOCK_WAIT_LAST_LOCK_RESULT=00000000
```

From Master sample 6 through sample 110, the observed state was:

```text
BOOT_GENERATION=00000004
MODE_MASTER_STAGE=00000000
LOCK_WAIT_SUBSTAGE=00000000
LOCK_WAIT_ITERATION=00000000
LOCK_WAIT_START_TICS=00000000
LOCK_WAIT_CURRENT_TICS=00000000
LOCK_WAIT_LAST_LOCK_RESULT=00000000
```

The Master PTP diagnostic temporarily showed zero during the transition window
and later returned to its normal listening state. The sampled CPU reset probe
bit remained asserted healthy in the read records. The post-capture boot-init
diagnostic again showed Master command index 2 with mode-master call/return
counts 0/0.

The Slave remained at `BOOT_GENERATION=2`, `MODE_MASTER_STAGE=0`, and all
`LOCK_WAIT_*` fields zero for the full capture. Its post-capture boot-init
diagnostic remained command index 4 with mode-master call/return counts 0/0.

No nonzero lock-wait sub-stage was observed on either board. In particular,
there is no evidence in this round that the Master reached
`spll_check_lock()`, `spll_update()`, `timer_delay()`, the timeout comparison,
or the function return marker.

## Interpretation

```text
VALID_MANUAL_JTAG_VUART_STIMULUS=YES
MASTER_STAGE_BEFORE_COMMAND=0
MASTER_STAGE_AFTER_COMMAND=0
MASTER_LOCK_WAIT_SUBSTAGE=0_FOR_ALL_SAMPLES
MASTER_BOOT_GENERATION=2_THEN_4
SLAVE_BOOT_GENERATION=2_STABLE
LOCK_WAIT_INTERNAL_FORENSICS=NOT_REACHED
FIRST_UNOBSERVED_BOUNDARY=before_or_at_visible_mode_master_entry_marker
IRQ_STORM_SUPPORTED_BY_THIS_CAPTURE=NO (IRQ_COUNT=0, EIC_ISR=0 in sampled post state)
NATURAL_CPU_RESTART=NOT_PROVEN
ROOT_CAUSE=NOT_PROVEN
```

The command stimulus was valid at the transport level, but this run left no
sticky evidence that the firmware reached the mode-master entry marker. The
Master generation change coincided with the stimulus, so a reset/re-entry-like
event is possible; however, this capture does not distinguish that possibility
from command loss or marker clearing, and the sampled CPU reset bit did not
provide direct proof of a reset. Therefore this round cannot localize the
failure to `spll_update()`, `timer_delay()`, the timer timebase, or timeout
control flow.

Per branch 2's instruction, no repair was attempted in this round. The next
decision is deferred to branch 2 after review of this report and raw evidence.

## Raw evidence

Raw files are stored in:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-LOCK-WAIT-INTERNAL-SUBSTAGE-FORENSICS-20260827/`

Important files:

- `baseline_read_probe.log`
- `baseline_role_timeline.log`
- `baseline_boot_init_diag.log`
- `baseline_lock_wait_forensics.log`
- `forensics_manual_mode_master.log` — one valid 12-byte Master stimulus and
  the 110-sample capture
- `post_capture_boot_init_diag.log`
- `artifact_sha256.txt`, `timing_summary.txt`, `source_commit.txt`, and
  `raw_file_inventory.txt`
