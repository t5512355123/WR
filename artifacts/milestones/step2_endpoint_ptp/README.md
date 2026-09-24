# Step 2 milestone — Endpoint / MiniNIC / PTP

**Verdict: PASS**

## Purpose and boundary

This checkpoint proves Step 1 PHY/link health plus the Step 2 endpoint,
MiniNIC, and PPSI-PTP behavior on both DE5a boards. It does not require WR
handshake completion, SoftPLL lock, `PSTAT.locked`, or global time.

The canonical project entities in this frozen source are
`DE5a_wr_master_jtag` and `DE5a_wr_slave_jtag`. This milestone's compilation,
programming, and runtime evidence uses the JTAG path.

## Frozen source and provenance

- Historical source commit: `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00`.
- Reproduction checkout commit: `947afd975924ffe32e3ffa9a180230bdc6e36751`.
- Self-contained frozen source: [`source/`](source/).
- `source/SHA256SUMS` has 3,142 entries and SHA-256
  `ef623b821a089742a5bcadd5886e257d64ce8cef1368feefaa29fb3c4f3d70dc`;
  every entry was verified after promotion.
- Quartus Prime Standard: 17.0.0 Build 595.
- Firmware toolchain: RISC-V GCC 9.3.0, GNU ld 2.34.

The source snapshot was rebuilt with path-only packaging changes from the
historical JTAG source. No functional RTL or firmware change was part of this
reproduction.

## Images

| Role | Historical SOF SHA-256 | Rebuilt SOF SHA-256 | Rebuilt MIF SHA-256 |
|---|---|---|---|
| Master | `79cfac62ebfe86f338e5e79c6500956b6f3a06247c422508d5542f8b5912da1d` | `891ba2ca901cf307edc92223f1115387895b64f20441d8c4adeb3994179548ee` | `404e51270624c217ca9fa901c4ef1b8b3a8dd143335b8d4cd8afdc0c55805252` |
| Slave | `8b5c6652fafabf2f3a6bc0fe0b870c643a6a03dfaf0f419ff52ae32475ae4dee` | `fd4339f4d324d9b63cf60c3fb7e627abe6d6a3ff4f7f2e1df558f764ad5a270c` | `fd8f66dc8756922df290e56688334d365b8f1e9baded7a75051ab108a39cb902` |

The actual rebuilt images are [`master.sof`](master.sof) and
[`slave.sof`](slave.sof). Verify the milestone payload with
[`SHA256SUMS`](SHA256SUMS).

## Rebuild and program

On the configured Pain build host, from this frozen source directory:

```sh
bash scripts/build/build_master.sh
bash scripts/build/build_slave.sh
JTAG_CABLE='DE5 [1-11.1]' bash scripts/program/program_master.sh
JTAG_CABLE='DE5 [1-11.2]' bash scripts/program/program_slave.sh
```

Set `QUARTUS_SH`, `QUARTUS_PGM`, and the RISC-V toolchain `PATH` if they are
not already configured. The reproduced programming order was Master then
Slave.

## Validation results

- Build: Master and Slave full compile PASS, 0 errors and 270 warnings each.
- Program: both DE5a boards configured successfully, 0 programmer errors or
  warnings; JTAG ID `0x02E660DD`.
- Runtime: Step 2 acceptance PASS. Master had 20 accepted consistent samples
  out of 30 requested; Slave had 30/30. Both roles showed increasing MiniNIC
  and PPSI-PTP RX/TX counters. Slave foreign-master metadata remained
  `count=1`, `best_index=0`.
- Timing closure: not met in this build and not part of Step 2 acceptance; no
  timing-closure claim is made.

Full provenance and evidence are in
[`experiments/step2/EXP-S2-MILESTONE-REPRO-20260924/`](../../../experiments/step2/EXP-S2-MILESTONE-REPRO-20260924/).
