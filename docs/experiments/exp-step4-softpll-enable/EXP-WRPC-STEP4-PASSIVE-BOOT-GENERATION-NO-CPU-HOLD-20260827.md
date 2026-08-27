# EXP-WRPC-STEP4-PASSIVE-BOOT-GENERATION-NO-CPU-HOLD-20260827

## Purpose

Determine whether `BOOT_GENERATION` increases during a natural 30-second run
when the observation itself never holds, releases, resets, or otherwise
controls the CPU. This is a diagnostic-only continuation requested by branch 2.

## Boundary

- No `CONFIG_INIT_COMMAND` change.
- No changes to fault handling, IRQ, SoftPLL, DMTD, RAM behavior, PTP/PHY, or
  reset functional logic.
- The final reader calls only `read_probe_data`.
- The reader does not use the Wishbone mailbox, `write_source_data`, CPU CSR,
  CPU hold/release, or CPU reset writes.
- Samples are taken at 0, 5, 10, 20, and 30 seconds.

## Final passive instrumentation

The pre-CRT assembly writes two tagged diagnostic values through the already
validated fixed `.debug_boot` marker word at `0x0002E000`:

- tag `0xE`: `BOOT_GENERATION` in the low 28 bits;
- tag `0xD`: `P_AT_ENTRY_LATEST` in the low 28 bits.

The existing CPU store observer decodes those tags into direct JTAG probe 26:

| Probe | Bits | Meaning |
|---:|---:|---|
| 26 | `[63:32]` | `BOOT_GENERATION` |
| 26 | `[31:0]` | `P_AT_ENTRY_LATEST` |
| 2 | bit 35 | `CPU_RESET_n` |
| 2 | bit 36 | `wr_core_reset_n` |
| 2 | bit 37 | `si_config_done` |
| 2 | bit 38 | `clk_sys_625_locked` |
| 0 | bit 15 / bit 0 | duplicate `CPU_RESET_n` / `si_config_done` checks |

A first implementation used new `.debug_boot` words at `0x2e004` and
`0x2e008`. Its MIF contained the expected stores, but the passive probe stayed
zero, so that implementation was discarded before the formal run. The formal
run below uses only the final tag-based implementation at the proven marker
address.

## Reproducibility record

```text
SOURCE_COMMIT=3fca2a42ec359b7a96fd870a6e9cdda2ccee8d53
MASTER_MIF_SHA256=f0841d898ea274357db7256c70c267d68716efe901501f31262c4680a450a963
SLAVE_MIF_SHA256=90796ce395d8f850ec7384b6fe52ce73cfe714ab8f20215aed5d40834f50845c
MASTER_SOF_SHA256=b275cacb060ef57602433b298b4474db049346d90d052be3a3ba9f5c8f714b6d
SLAVE_SOF_SHA256=208929933e8640f60b461891748f6d35cce898af09319b50625cb3433993f098
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

The final link map places `debug_boot_stage` at `0x0002e000` and
`build_init_readcmd_p` at `0x0001c3a4` in both firmware images. The passive
reader is `scripts/jtag/read_passive_boot_generation_no_cpu_hold.tcl`.

## Observed results

All rows below are valid passive samples. `CPU_RESET_n`, `wr_core_reset_n`,
`si_config_done`, and `clk_sys_625_locked` were `1` at every sample on both
boards. The duplicate reset/config fields in probe 0 and probe 2 agreed at
every sample.

| Time (s) | Master generation | Master p | Slave generation | Slave p |
|---:|---:|---:|---:|---:|
| 0 | 4 | `0x000179E4` | 2 | `0x000179D8` |
| 5 | 4 | `0x000179E4` | 2 | `0x000179D8` |
| 10 | 4 | `0x000179E4` | 2 | `0x000179D8` |
| 20 | 4 | `0x000179E4` | 2 | `0x000179D8` |
| 30 | 4 | `0x000179E4` | 2 | `0x000179D8` |

The starting generations are not 1 because the `.debug_precrt` area is
`NOLOAD` and this run does not establish a clean fresh-generation baseline.
The valid result is the absence of change during the passive interval.

## Interpretation

```text
PASSIVE_BOOT_GENERATION_CHANGE=NOT_OBSERVED (Master 4->4, Slave 2->2)
NATURAL_CPU_RESTART_WITHOUT_FPGA_RECONFIG=NOT_PROVEN
CPU_CORE_REENTRY_WITHOUT_FPGA_RECONFIG=SUPPORTED_BY_PRIOR_HOLD_RELEASE_RUN
DIAGNOSTIC_INDUCED_REENTRY=SUPPORTED_BY_PRIOR_READER_HOLD_RELEASE
ROOT_CAUSE=NOT_PROVEN
STEP4_PASS=NOT_CLAIMED
```

The passive monitor did not observe a natural generation increase. The earlier
reader that intentionally held/released the CPU did observe generation
increases; that evidence is consistent with diagnostic-induced CPU/core
re-entry and must not be presented as proof of a natural restart. This
experiment is therefore stopped here. Do not begin a fault/IRQ repair or other
functional change without a new instruction from branch 2.

## Raw evidence

Raw files are stored at:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-PASSIVE-BOOT-GENERATION-NO-CPU-HOLD-20260827/`

- `passive.log` and `passive_samples.txt`
- `program_master.log` and `program_slave.log`
- `build_jtag_master.log` and `build_jtag_slave.log`
- `build_info_jtag_master.txt` and `build_info_jtag_slave.txt`
- `artifact_sha256.txt`
- `symbol_addresses_master.txt` and `symbol_addresses_slave.txt`
- `source_commit.txt`
