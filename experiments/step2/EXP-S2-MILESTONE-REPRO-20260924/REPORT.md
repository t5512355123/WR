# Step 2 milestone reproduction report

**Verdict: `STEP2_MILESTONE = PASS`**

- Date: 2026-09-24 (Asia/Taipei)
- Branch: `feat/file_cleanup`
Pain checkout commit: `947afd975924ffe32e3ffa9a180230bdc6e36751`

This report records a fresh, self-contained Step 2 source rebuild, dual-board
program, and read-only runtime validation. The verdict covers Step 1 link
health and Step 2 endpoint / MiniNIC / PPSI-PTP behavior only. It does not claim
Step 3 WR handshake or any SoftPLL/global-time milestone.

## Source provenance

- Historical Step 2 source commit: `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`.
- Historical candidate experiment: `EXP-WRPC-STEP2-DCO-RESTORE-20260819`.
- The source package in `candidate_source/` keeps the historical JTAG top
  entities and functional RTL/firmware. Changes for this reproduction were
  limited to self-contained path relocation, JTAG build/program wrappers, and
  text line-ending normalization.
- Candidate/frozen source manifest: 3,142 entries;
  `SHA256SUMS` SHA-256
  `ef623b821a089742a5bcadd5886e257d64ce8cef1368feefaa29fb3c4f3d70dc`.
- The exact manifest was checked on Pain after the GitHub pull; the local
  promoted milestone copy independently verifies all 3,142 entries.
- The Pain build used the pushed commit above. Both generated images were
  programmed before the runtime capture.

Historical SOFs from the 2026-08-19 experiment were Master
`79cfac62ebfe86f338e5e79c6500956b6f3a06247c422508d5542f8b5912da1d` and Slave
`8b5c6652fafabf2f3a6bc0fe0b870c643a6a03dfaf0f419ff52ae32475ae4dee`. The
reproduced images below are new builds; no historical-image identity is
claimed.

## Build

Environment on Pain:

- Quartus Prime Standard 17.0.0 Build 595.
- `riscv64-unknown-elf-gcc` 9.3.0; GNU `ld` 2.34.
- QSF/QIP path audit: 554 direct assignments resolved; 0 missing paths.
- Both role builds ran the candidate clean-build wrappers from the frozen
  source. Quartus reported full compilation successful, 0 errors and 270
  warnings per role.

| Role | MIF SHA-256 | Rebuilt SOF SHA-256 |
|---|---|---|
| Master | `404e51270624c217ca9fa901c4ef1b8b3a8dd143335b8d4cd8afdc0c55805252` | `891ba2ca901cf307edc92223f1115387895b64f20441d8c4adeb3994179548ee` |
| Slave | `fd8f66dc8756922df290e56688334d365b8f1e9baded7a75051ab108a39cb902` | `fd4339f4d324d9b63cf60c3fb7e627abe6d6a3ff4f7f2e1df558f764ad5a270c` |

The full build logs and QSF audit are retained under `raw/build/`. Quartus
reported timing requirements not met; timing closure was not a Step 2
acceptance criterion and is not claimed by this verdict.

## Programming

Programming order was Master then Slave, matching this experiment's selected
Step 2 procedure. No power cycle, cable change, or runtime control write was
performed.

| Board | Cable | Result | JTAG ID | Programmer checksum | Time |
|---|---|---|---|---|---|
| Master | `DE5 [1-11.1]` | 1 device configured; 0 errors/warnings | `0x02E660DD` | `0x30A3010A` | 19 s |
| Slave | `DE5 [1-11.2]` | 1 device configured; 0 errors/warnings | `0x02E660DD` | `0x30A3C3D7` | 18 s |

Both programmer logs are preserved under `raw/program/`. The SOFs in the
milestone directory are the exact files whose hashes appear in this table and
the programmer output.

## Runtime acceptance

The runtime scripts use the existing JTAG source-probe / Wishbone mailbox in
read-only mode. The time-series requested 30 samples per board at a nominal
1,000 ms gap, with up to three retries; each accepted sample passed the
script's begin/end consistency checks. The capture ran for 2 min 23 s.

| Gate | Master (`DE5 [1-11.1]`) | Slave (`DE5 [1-11.2]`) | Verdict |
|---|---|---|---|
| Firmware | marker `B004`, valid image, no CPU fault/reset | marker `B004`, valid image, no CPU fault/reset | PASS |
| Step 1 link bits in every accepted row | 20/20 healthy | 30/30 healthy | PASS |
| RX/TX encoding-error bits | 0/20 rows | 0/30 rows | PASS |
| Endpoint MAC | `02:00:22:33:44:01` | `02:00:22:33:44:02` | PASS |
| Role / PPSI mode | `MODE=2`, `PTP=6 (PPS_MASTER)` | `MODE=3`, `PTP=9 (PPS_SLAVE)` | PASS |
| Accepted consistent time-series rows | 20/30 (10 exhausted retry budget) | 30/30 | PASS; invalid rows excluded |
| PPSI PTP RX counter, first→last accepted | `535→698` (`+163`) | `1572→1861` (`+289`) | PASS |
| PPSI PTP TX counter, first→last accepted | `1225→1587` (`+362`) | `277→320` (`+43`) | PASS |
| MiniNIC TX counter, start→end snapshot | `467→3459` (`+2992`) | `245→1929` (`+1684`) | PASS |
| MiniNIC RX counter, start→end snapshot | `236→1815` (`+1579`) | `415→3302` (`+2887`) | PASS |
| Slave foreign-master metadata | not applicable | `FOREIGN_META=03000001` (`count=1`, `best_index=0`) in all accepted rows | PASS |
| Restart marker / firmware RXERR shadow | marker stable; RXERR `16→16` | marker stable; RXERR `0→0` | no observed growth |

All accepted status-probe rows retained `SI_CONFIG_DONE`, `PHY_READY`,
`TM_LINK_UP`, `CORE_LINK_OK`, `RX_READY`, `TX_READY`, and released-CPU bits.
The Master had 10 samples that remained inconsistent after the configured
retries; they are preserved in the raw log and were not counted as accepted.
Both accepted series include sample indexes 1 and 30.

The firmware `WDIAGS_RXERR` shadow was nonzero on the Master but did not
increase during observation. It is not the dedicated PHY encoding-error bit;
the status-probe RX/TX encoding-error bits were zero in every accepted row.
The per-board restart marker and CPU state were unchanged between snapshots.

The runtime analyzer command is:

```sh
python3 analysis/analyze_step2_runtime.py \\
  --start raw/observe/runtime-snapshot.log \\
  --series raw/observe/runtime-timeseries-30s.log \\
  --end raw/observe/runtime-snapshot-end.log
```

It reports `STEP2_RUNTIME=PASS`. Full raw captures, build/program logs, and
offline analysis are retained in this experiment directory.

## Verdict boundary and limitations

```text
STEP1 = PASS (also independently reproduced at its own milestone)
STEP2 = PASS
STEP3 = NOT CLAIMED
STEP4 = NOT CLAIMED
STEP5 = NOT CLAIMED
STEP6 = NOT CLAIMED
```

`time_valid`, `PSTAT.locked`, WR signaling completion, SoftPLL lock, and global
time are outside Step 2. Timing closure is also not a Step 2 gate. The Master
time-series had 10 rejected/invalid sample slots; the 20 accepted frames,
including the first and last sample indexes, are the only ones used for the
Step 2 time-series assertions.

The promoted frozen source and freshly built SOF pair are in
[`artifacts/milestones/step2_endpoint_ptp/`](../../../artifacts/milestones/step2_endpoint_ptp/).
