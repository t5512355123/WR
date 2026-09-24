# Step 5 — SoftPLL full-lock milestone

Step: 5 — SoftPLL full lock
Purpose: preserve an independently rebuilt and hardware-revalidated checkpoint with stable Helper/HPLL, Main frequency, Main phase, and PSTAT locks.
Verdict: PASS

## Provenance

- Historical source commit: 26e138fdc0bfc8426704b397141d563cf4d580a2.
- Frozen source origin: 26e138fdc0bfc8426704b397141d563cf4d580a2.
- Read-only observer contract overlay: 47d9a394e53eda31476c82de2a85ad82573494ed.
- Reproduction checkout: 6f1096d7f957beeb2f0c065f7219960bae47bb61, branch feat/file_cleanup.
- Quartus Prime Standard Edition 17.0.0 Build 595; RISC-V toolchain 9.3.0.

| Item | Historical | Rebuilt and validated |
|---|---|---|
| Master SOF SHA-256 | a2945df48fe86038fdff138f4b6368a777fa3df13f98ac9620fb30baa1ee0129 | f72501285cef7f6a892b9334e7de93a5a86f8aff7311417f577c14acfd213a30 |
| Slave SOF SHA-256 | 7462d94a521f52e7660295a6873de5141658fbf5392d90a4d4ade7d4e5f36f50 | d4efd77c91ddc96cd6444e3f47cadf529a4f19da4c9f6b0876ce00557d63ca20 |

Build: Master PASS; Slave PASS. Both full compilations and Fitter completed successfully. Rebuilt QSF paths are layout-relocated; the SDC hash matches the historical SDC. Firmware Git-description metadata was pinned to the frozen source identity. Rebuilt MIF hashes differ from historical because the upstream revision object contains build date/time metadata; the mismatch is recorded, not concealed.

Program: Master PASS on DE5 [1-11.1]; Slave PASS on DE5 [1-11.2]. Quartus reported one device configured on each cable, zero errors, and zero warnings. The actual programmer CRCs and full logs are in the reproduction experiment.

## Runtime acceptance

One read-only, single-reader F4L session reached 301253 ms (target 300000 ms, hard limit 310000 ms), with 317 Slave cycles and no stop reason.

| Required condition | Result |
|---|---|
| Helper/HPLL lock | PASS, 317/317 cycles |
| Main frequency lock | PASS, 317/317 frames |
| Main phase lock | PASS, 317/317 frames |
| PSTAT lock | PASS, 317/317 cycles |
| Fresh valid coverage | PASS, 300291 ms unique span, 31 valid 10-second bins |
| Link/reset stability | PASS, all 317 cycles; no terminal state or SoftPLL delock |

Every Main F4L frame reported FLAGS=383 (0x17F), decoded from the frozen source header as frequency locked, phase locked, phase detector called/in-band, and phase out-of-band clear. Helper and PSTAT states were directly valid on all Slave cycles.

## Rebuild and program

From Pain, with Quartus and the RISC-V toolchain on PATH, use the frozen source tree:

```sh
cd artifacts/milestones/step5_softpll_lock/source
bash scripts/build/build_firmware.sh master
bash scripts/build/build_master.sh
bash scripts/build/build_firmware.sh slave
bash scripts/build/build_slave.sh
CABLE='DE5 [1-11.1]' bash scripts/program/program_master.sh
CABLE='DE5 [1-11.2]' bash scripts/program/program_slave.sh
```

Preserve the Step 5 order: Master, wait at least 90 seconds, then Slave. After both are programmed, wait at least 120 seconds, run the read-only runtime preflight, then run one 300-second F4L capture. The exact commands and complete raw evidence are in the linked experiment report.

## Known limitations

- Quartus timing closure is NO. Worst setup slack: Master -0.289 ns; Slave -0.361 ns. Timing closure is not part of the functional Step 5 gate.
- The strict F4L analyzer reported eight page-2 HISTOGRAM_PHASE_COUNT_MISMATCH rows in four repeated source-epoch pairs. The rows remain in raw evidence; all retain FLAGS=383. Schema-consistent fresh data spans 300291 ms and all 31 ten-second bins.
- The preflight emits the same WR signal sideband read-inconsistent Step 3 classification seen in the historical accepted run. JTAG/Wishbone transport is trusted, the link and reset state are stable, and the continuous lock evidence is direct.
- Auxiliary Main schedule fields are unavailable in this observer/source combination, as in the historical accepted capture; they are not used to infer lock.
- This milestone does not claim Step 6 global-time agreement or physical SMA/output edge-skew validation.

## Evidence

Reproduction report: experiments/step5/EXP-S5-MILESTONE-REPRO-20260924/REPORT.md
Full raw captures, build/program provenance, and per-gate audit are retained under that experiment. The complete self-contained frozen build source is in source/.
