# Code-only implementation and offline validation

2026-10-04, Asia/Taipei. Production implementation source `4540e8cb`.
Branch `feat/file_cleanup`; root default `WRH_PHASE_CORRECTION_ENABLED=0`.

## Completed checks

- Laptop33/33 Python tests passed; Pain33/33 passed. Source-control tests
  reconstruct the exact historical wrh-servo.c after removing only the three
  phase guards, mode default/validation and two effective tracking-status
  expressions. No other production path changed.
- Native Pain host tests with UndefinedBehaviorSanitizer execute actual
  default-disabled production C:148 cases passed, zero phase writes while
  changing CKO/delay inputs still advance measurements/update_count. Init,
  reset/reinit, IPC toggles,60/120ps thresholds, busy/PLL failure and coarse
  synchronization are covered. Coarse counter operations remain functional.
- The original22-case historical controller test passed with an EXPLICIT
  `-DWRH_PHASE_CORRECTION_ENABLED=1` host-test override. This is a reference
  variant, NOT the production default or a firmware deployment.
- New observer wrapper syntax checked. Mocked-transport tests check
  existing-reader preservation, invalid arguments, a complete mode2 capture
  and an incomplete capture which must remain unsuccessful. These mocks do
  not contact hardware or establish a CKO stability/loaded-firmware result.

Native logs: `raw/offline/pain-native-c.log`, `raw/offline/pain-python.log`.
Exact transfer hashes verified on Laptop:

| Record | SHA256 |
|---|---|
| pain-native-c.log |`bc9d4da5273e1d48aea499a90d3aaeb1b47f030c230ddf5c6d93cbebc0f1a15b`|
| pain-python.log |`14cbac35cd51dcafe755c83d6dda0a9c871cfe72edd0c82a4480cb05068e0727`|

## Explicitly not performed

No WR firmware/Quartus build or FPGA programming, power cycle, JTAG capture,
consultant message or process termination was performed for this candidate.
Small native C unit-test compilation is host-only, not firmware/FPGA compile.
Pain had user-generated dirty build products and an active milestone reader;
these were preserved. Frozen milestones and protected archive were not changed.
No SOF representing the new diagnostic mode was produced or published by us.

Actual CKO amplitude and any new TIME_VALID/precision outcome are NOT_MEASURED.
The user must successfully build/compile/program the current root before
manually capturing this mode. The observer does not independently identify
loaded firmware, and SETP constancy alone cannot identify physical jitter.
