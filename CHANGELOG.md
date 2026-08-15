# Changelog

## 2026-08-15

- Created the non-destructive `de5a-white-rabbit` staging repository.
- Imported the pain-side RS422 baseline source, vendor trees, firmware configs and milestone artifacts.
- Added migration inventory, traceability documents, build identity scripts and experiment templates.
- No WR algorithm, PHY, PTP, SoftPLL, DMTD, QSFP port, lane, pre-emphasis, role or PPS behavior was changed.
# 2026-08-15

- Created the non-destructive `de5a-white-rabbit` source-of-truth repository.
- Preserved the old Laptop and pain projects, vendor Git provenance, baseline
  RS422 SOF/MIF/probe evidence and migration manifests.
- Added Quartus 17, firmware, programming, JTAG and artifact-collection scripts.
- Verified Master/Slave firmware and full Quartus compilation on pain with 0
  errors; recorded the result as `EXP-REPRO-BUILD-20260815`.
- Verified a clean pain checkout and documented WRPC build timestamp effects.
