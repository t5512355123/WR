# EXP-WRPC-STEP4-MANUAL-MODE-MASTER-TRANSITION-FORENSICS-20260827

## Purpose

On a freshly programmed, known-healthy Master, execute exactly one manual
`mode master` transition and identify the first stage that does not become
observable. The Master boot command remains:

```text
vlan off;ptp stop
```

## Stage markers

The sticky read-only marker is written at WDIAGS private offset `0x158`,
CPU address `0x00100B58`:

```text
0 = not entered
1 = entered wrc_ptp_set_mode(MASTER)
2 = immediately before spll_init()
3 = immediately after spll_init()
4 = immediately before wrpc_spll_check_lock_with_timeout()
5 = immediately after lock-wait return
```

Only observability was added. No SoftPLL algorithm, IRQ behavior, fault
handler, DMTD, RAM, reset, PTP functional behavior, PI parameter, or DCO
behavior was changed.

## Transport boundary

The host PCI VUART path was tested first, but the configured PCI resource was
not usable by `wrpc-vuart` (`Permission denied` without elevated access and
`Invalid argument` with the available BAR). Those attempts opened no WRPC
UART and sent no command; their logs are retained as transport evidence.

The valid stimulus used the existing JTAG Wishbone path to write the WRPC
virtual-UART `HOST_TDR` at `0x00100510`. This is equivalent to entering the
command through VUART and does not hold/release the CPU or write reset. The
capture script sent exactly one command, `mode master` followed by newline,
to the Master only. All 12 byte writes reached Wishbone completion.

## Reproducibility record

```text
IMAGE_SOURCE_COMMIT=f3b780edc0de88a6cec31ea4f35fd18c72cc47c1
CAPTURE_SCRIPT_COMMITS=9422c28ef3b24df014f7970246abb5fe57097f41, ebc6562645fe45d2f55d4a0c52f3f171133719f7
MASTER_CONFIG_INIT_COMMAND="vlan off;ptp stop"
SLAVE_CONFIG_INIT_COMMAND="vlan off;ptp stop;mode slave;ptp start"
MASTER_MIF_SHA256=892fb85c5b1aba1bd6b2c68b4fb00ccf7a8663daa66e78360069cee6ebd84b3c
MASTER_SOF_SHA256=b22f7930f2da0eaa04204ed53b68d698dfc13da80f40f53088a7c6cc048c405a
SLAVE_MIF_SHA256=55b6b2f24613d1ddf28447909a8fd9b274b3c60d975cd4fac421a1b5932d60c8
SLAVE_SOF_SHA256=f8bbe3617110ce32d2d0148334638ce9168f266281cad6e5811097056735960f
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
MASTER_COMPILE=Full Compilation was successful
SLAVE_COMPILE=Full Compilation was successful
QUARTUS_VERSION=17.0.0 Build 595 04/25/2017 SJ Standard Edition
```

Firmware symbol addresses in the fresh build:

```text
MASTER shell_init_cmd=0x00017A20
MASTER build_init_readcmd_p=0x0001C3DC
MASTER debug_boot_stage=0x0002E000
SLAVE shell_init_cmd=0x00017A20
SLAVE build_init_readcmd_p=0x0001C3EC
SLAVE debug_boot_stage=0x0002E000
```

Both DE5a devices were freshly programmed successfully on cable `DE5 [1-11.1]`
(Master) and `DE5 [1-11.2]` (Slave).

## Healthy baseline

Before the valid manual stimulus:

- Both probe reads showed `CPU_RESET_N=1`, `link_ok=1`, `tm_link_up=1`,
  `phy_ready=1`, and `si_config_done=1`.
- The Master role timeline was `MODE=3 (SLAVE)` and `PTP=4 (LISTENING)`.
- Master boot-init diagnostics were stable: script enter count 1, command
  index 2, mode-master calls 0, returns 0.
- Slave boot-init diagnostics were stable: script enter count 1, command
  index 4, mode-master calls 0, returns 0.
- The first two Master forensics samples had
  `MODE_MASTER_STAGE=0`, `PTP=0x00002104`, and `PTP_META=0x03020404`.

## Observed transition

The single valid JTAG-VUART capture used 60 samples at 250 ms spacing. The
Master stayed at stage 0 through sample 2. After the newline was injected,
sample 3 at 643 ms showed:

```text
MODE_MASTER_STAGE=00000004
PTP=00000000
PTP_META=00000000
SPLL_STATE=00000000
LOCK_ENABLE=00000000
EIC_ISR=00000000
TAG_VALID=00000000
TRR_WRITE=00000000
TRR_POP=00000000
IRQ_COUNT=00000000
HELPER_UPDATE=00000000
```

The Master remained at stage 4 for all remaining 58 samples. The 250 ms
sampling interval did not resolve stages 1–3 individually; the sticky result
does prove entry reached the pre-lock-wait boundary.

A subsequent 100-sample, no-injection, read-only capture covered 28.656 s on
the Master. Every Master sample had:

```text
MODE_MASTER_STAGE=00000004
BOOT_GENERATION=00000003
P_AT_ENTRY_LATEST=0x00017A20
CPU_RESET_N=1
SPLL_STATE=00000000
LOCK_ENABLE=00000000
EIC_ISR=00000000
TAG_VALID=00000000
TRR_WRITE=00000000
TRR_POP=00000000
IRQ_COUNT=00000000
HELPER_UPDATE=00000000
```

`P_AT_ENTRY_LATEST` equals `shell_init_cmd`, so the captured pointer offset is
0. Master `BOOT_GENERATION` and `P_AT_ENTRY_LATEST` were stable throughout
the post-command window. The pre-stimulus capture used the earlier output
format and did not preserve the generation high word, so a precise
generation transition at the command instant is not claimed by this round.

The Slave remained at `MODE_MASTER_STAGE=0` and
`BOOT_GENERATION=2`, with `P_AT_ENTRY_LATEST=0x00017A20` throughout the same
post-command capture. Four isolated nonzero raw stage words occurred on
Slave reads; they were not persistent, and all other Slave evidence remained
consistent with the stage-0 path. They are retained as raw mailbox sampling
artifacts, not interpreted as a Slave transition.

## Interpretation

```text
VALID_MANUAL_MODE_MASTER_STIMULUS=YES
MASTER_STAGE_BEFORE_COMMAND=0
MASTER_FIRST_VISIBLE_POST_COMMAND_STAGE=4
MASTER_STAGE_5_WITHIN_28_656S=NOT_OBSERVED
MASTER_POST_COMMAND_BOOT_GENERATION=3_STABLE
MASTER_POST_COMMAND_P_AT_ENTRY=0x00017A20_STABLE
MASTER_CPU_RESET_N=1_THROUGHOUT_POST_CAPTURE
IRQ_STORM_SUPPORTED_BY_THIS_CAPTURE=NO (IRQ_COUNT=0, EIC_ISR=0)
FIRST_UNOBSERVED_BOUNDARY=after pre-lock-wait marker and before visible stage 5
ROOT_CAUSE=NOT_PROVEN
```

The manual command reached the `wrc_ptp_set_mode(MASTER)` path and advanced
through the pre-lock-wait marker, but no evidence was observed beyond that
boundary during the 28.656-second read-only window. This localizes the next
investigation to the lock-wait return path or the immediately following stage
5 write. It does not by itself distinguish a lock-wait hang from a failure in
the stage-5 write, and it does not prove an IRQ storm or the final root cause.

Per branch 2's instruction, do not repair IRQ/fault behavior in this round.

## Raw evidence

Raw files are stored at:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-MANUAL-MODE-MASTER-TRANSITION-FORENSICS-20260827/`

- `firmware_master_build.log`, `firmware_slave_build.log`, and timing summaries
- `source_commit.txt`, artifact SHA-256 records, and programmer logs
- `baseline_read_probe.log`, `baseline_role_timeline.log`, and
  `baseline_boot_init_diag.log`
- `forensics_jtag_vuart.log` — the single valid command injection and 60-sample
  transition capture
- `forensics_post30s_generation.log` — 100-sample post-command capture with
  full generation/pointer fields
- `forensics.log` and `forensics_retry.log` — transport attempts that sent no
  command
- `raw_log_sha256.txt` and `raw_file_inventory.txt`
