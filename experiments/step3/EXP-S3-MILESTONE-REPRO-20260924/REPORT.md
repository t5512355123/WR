# Step 3 milestone reproduction report

**Verdict: `STEP3_MILESTONE = PASS`**

This reproduction proves Step 1/2 prerequisites and the Step 3 WR parent and
signaling handshake on the two DE5a boards. It also proves the source-backed
entry into `wrpc_spll_locking_enable()`. It does **not** claim SoftPLL lock,
Step 4 completion, Step 5 lock, valid global time, or timing closure.

## Source and frozen package

- Date: 2026-09-24 (Asia/Taipei).
- Branch: `feat/file_cleanup`.
- Pain checkout used for build/program: `f235b557ad09d9b37adff2c2b11b36f615f66e9e`.
- Frozen source origin: `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`.
- Historical Step 3 candidate audited: `fb8c926cfe37b82e86300117181a6ac01e1889e2`.
- Source manifest: 3,142 entries; `sha256sum -c` passed on Pain.
- `source/SHA256SUMS` SHA-256:
  `76245e8d53306a1cd2c0c7abd40145c6c4926b131568ed65dedec42594ac7207`.
- Master and Slave QSF SHA-256 values match the Step 2 frozen package. The
  existing QSF dependency audit therefore applies: 554 direct assignments
  resolved, 0 missing paths. See
  [`../step2/EXP-S2-MILESTONE-REPRO-20260924/raw/build/qsf-path-audit.txt`](../../step2/EXP-S2-MILESTONE-REPRO-20260924/raw/build/qsf-path-audit.txt).

No functional RTL, firmware-control, board-pin, reset-sequence, QSFP-A lane,
PHY, PTP, or SoftPLL parameter was changed for this experiment. The only new
implementation files are offline prerequisite-analysis code and tests.

## Clean build

Pain used Quartus Prime Standard 17.0.0 Build 595, `riscv64-unknown-elf-gcc`
9.3.0, and GNU `ld` 2.34. Both build wrappers completed successfully. Quartus
reported full compilation with 0 errors and 270 warnings per role. The reports
also say setup/hold requirements are not fully constrained; timing closure is
not a Step 3 gate and is not claimed.

| Role | Firmware MIF SHA-256 | Fresh SOF SHA-256 | Full compile |
|---|---|---|---|
| Master | `336dfa3161ec918e8ee02f8787d32447e608a743afbf285c93b5212fb9847a79` | `0cae1a4d4c800c3a67e5dcac7ca4abf739475867119ac333d0d71ef39380acf2` | 0 errors, 270 warnings |
| Slave | `44d7fe97d4900712e195998a25675e6d9be0d946401286e0081e180301e2eb31` | `f196de1f5d431a493c2a8ce0aaeeb34d202f4d04f30c340977a4b771049896de` | 0 errors, 270 warnings |

The full Master and Slave logs and generated MIFs are retained under
`raw/build/`. The SOFs are retained both there in Pain's frozen source build
outputs and in the top level of
[`artifacts/milestones/step3_wr_handshake/`](../../../artifacts/milestones/step3_wr_handshake/).

## Programming

Programming was Master first, then Slave. No power cycle, cable change, or
runtime control write was performed.

| Board | JTAG cable | Programmer result | JTAG ID | Quartus checksum | Duration |
|---|---|---|---|---|---:|
| Master | `DE5 [1-11.1]` | 1 device configured; 0 errors/warnings | `0x02E660DD` | `0x30A3010A` | 19 s |
| Slave | `DE5 [1-11.2]` | 1 device configured; 0 errors/warnings | `0x02E660DD` | `0x30A3C3D7` | 18 s |

Programmer output is preserved under `raw/program/`. The two top-level
milestone SOFs are byte-for-byte the files whose hashes appear above.

## Runtime evidence and selected window

The first 30-sample capture was taken while the Slave was still transitioning
through PTP state 8; the capture itself showed stable Step 3 handshake data,
but it was not used as the final Step 1/2 window. A second window used the
settled baseline but yielded only 17/30 coherent Master frames with the
reader's 3-retry limit, so that replicate is preserved as `INCONCLUSIVE`.

The verdict uses the subsequent stable start/end snapshots and the same
read-only JTAG reader with 30 nominal 1-second samples per board and up to 10
reader retries. The retry setting affects observation only. The session ran
13:48:56–13:51:39 (2 min 43 s including mailbox reads). Both stable snapshots
showed Master `MODE=2/PTP=6` and Slave `MODE=3/PTP=9`.

| Gate | Master | Slave | Result |
|---|---|---|---|
| Coherent accepted frames | 30/30 | 30/30 | PASS |
| Role / PTP state in accepted frames | `MODE=2/PTP=6` | `MODE=3/PTP=9` | PASS |
| Step 1 required status bits | High in 30/30 | High in 30/30 | PASS |
| RX/TX encoding-error status bits | Low in 30/30 | Low in 30/30 | PASS |
| PPSI PTP RX counter, first→last | `2208→2410` (`+202`) | `5414→5677` (`+263`) | PASS |
| PPSI PTP TX counter, first→last | `4973→5428` (`+455`) | `798→831` (`+33`) | PASS |
| MiniNIC TX snapshot, start→end | `6093→7361` (`+1268`) | `3411→4125` (`+714`) | PASS |
| MiniNIC RX snapshot, start→end | `3208→3876` (`+668`) | `5849→7074` (`+1225`) | PASS |
| Firmware RXERR shadow | `0→0` | `0→0` | PASS |

Both boards retained the expected endpoint identities. Slave foreign-master
metadata was `count=1, best_index=0` in every accepted frame; the selected
parent was identified as WR and calibrated.

### Step 3 handshake

All 30 accepted Slave frames passed the source-backed analyzer:

- Received WR `LOCK`: message `0x1001`, positive receive count.
- Transmitted `SLAVE_PRESENT`: message `0x1000`, positive transmit count.
- Signaling rejection count remained zero.
- `wr_lock_enable_count=4` in the observed series, proving the
  `wrpc_spll_locking_enable()` entry hook ran.

The current sampled `WR_LOCAL state` was 0 after that transient path; the
historical `fail_state=2` value was not used as current-state evidence. Step 3
acceptance is satisfied by the positive source-backed lock-entry counter, not
by claiming the Slave remained in `WRS_S_LOCK` or that SoftPLL locked.

## Reset observability and analyzer semantics

The frozen image exposes no source-backed reset-generation counter. Therefore
this report claims **no sampled reset evidence**, not that an arbitrarily
short reset between samples is impossible. In the selected window, `CPU_RESET_n`
was high in both status snapshots and all accepted frames; CPU debug reset/fault
indicators were clear; firmware marker `B004` was present; and `SYSC_RSTR` /
`SYSC_GPSR` snapshots were unchanged.

Two legacy labels are not valid reset evidence:

- The snapshot script labels a read of `0x0010096C` as `WDIAGS_RESTART`, while
  the Step 3 time-series reader maps the same address to `wr_fail_debug`.
- The snapshot script reads `0x00100B00` as `CPU_RESET`, but its readable status
  semantics are not source-validated. On the final Master snapshot it returned
  `0x83274730` while the actual `CPU_RESET_n` probe was high and CPU debug
  reported `reset=0, fault=0`.

The legacy Step 2 analyzer consequently printed `NOT_PASS` for this final
capture due to that `CPU_RESET` readback. The Step 3-specific offline
prerequisite analyzer checks the source-backed status/probe evidence instead
and reports `STEP3_PREREQUISITES=PASS`. The Step 3 handshake analyzer reports
`STEP3_HANDSHAKE=PASS`. All seven offline analyzer unit tests pass.

From this experiment directory, rerun the verdict checks with:

```sh
python3 analysis/analyze_step3_prerequisites.py \
  --start raw/observe/retry10-start-snapshot.log \
  --series raw/observe/timeseries-retry10-30s.log \
  --end raw/observe/retry10-end-snapshot.log
python3 analysis/analyze_step3_runtime.py \
  --series raw/observe/timeseries-retry10-30s.log
python3 -m unittest discover -s analysis -p 'test_*.py' -v
```

## Verdict boundary

```text
STEP1_PHY_LINK                 = PASS
STEP2_ENDPOINT_PTP             = PASS
STEP3_WR_HANDSHAKE             = PASS
STEP3_SOFTPLL_LOCK             = NOT CLAIMED
STEP4_SOFTPLL_STARTUP           = NOT CLAIMED
STEP5_CLOSED_LOOP_LOCK          = NOT CLAIMED
STEP6_GLOBAL_TIME               = NOT CLAIMED
FULL_TIMING_CLOSED              = NOT CLAIMED
```

Raw captures, build logs, program logs, MIFs, and their SHA-256 values are
preserved under this directory. `SHA256SUMS` covers raw evidence and analysis
inputs; the milestone directory's `SHA256SUMS` covers the exact SOF pair and
the frozen source manifest.
