# Open Decisions and Conflicts

These items are intentionally not auto-merged or deleted.

## Source conflicts

- The laptop snapshot did not contain the complete pain-side vendor and
  firmware/artifact set. The pain snapshot was therefore used for the
  canonical baseline after inventory and backup.
- The root Laptop/pain QSF difference was identified as Quartus metadata
  (`LAST_QUARTUS_VERSION`); the canonical project keeps the proven pain-side
  source and records the comparison rather than silently selecting a winner.
- The pain vendor trees were detached and dirty at inventory time. Their HEAD,
  remotes and modifications are recorded in `provenance/vendor_git_state.md`.

## Not merged

- `simplewa`, complex word alignment, 62.5 MHz, DCO, SFP EEPROM/I2C, runtime
  probe, load probe, JTAG Wishbone and no-SFP-match diagnostics remain legacy
  snapshots under `archive/diagnostics/`.
- No WR algorithm, PHY, PTP, SoftPLL, DMTD, QSFP, role, lane, PPS or
  pre-emphasis change was made to resolve any of these conflicts.

## Technical follow-up

- The current baseline has link/configuration evidence but not time
  synchronization evidence.
- TimeQuest reports show negative worst setup and recovery slack and several
  unconstrained paths. This is a future timing/constraint experiment, not an
  undocumented migration change.
- uRV/wrpc-sw runtime, PPSi state, SoftPLL lock and calibrated PPS alignment
  still need separate experiments with their own commits and artifacts.
