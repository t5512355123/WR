# Packaging verification — 2026-10-02

The two fresh hardware qualification cycles completed **before** packaging:
16:28:17–16:58:29 and 16:59:49–17:31:23 (+08:00). Each board had 1192/1192
valid rows with sample spans >302.7 seconds in both cycles. The independent
raw/image/compile-input pair auditor passed on Laptop and Pain.

Final archive SHA256:
`54950148ab09c0a5367f9779e59eaf993fcbef66877b8e7e461d642f8c7e2598`.
Source checkout snapshot `0bb02c6f91dd4c7a578e1b8cb02a553ce9ce9787`;
actual retained-image compile `7b6550123986a9d7cea5f4be0dbb8af1f5a019ab`.
Only packaging/tests/documentation changed after the qualified compile;
production source diff is empty and all 3110 compile-input hashes match.

On Pain, `prepare_source.sh` verified the archive, both alias SOFs, all 3110
production inputs and retained output SOFs, then initialized an independent
Git repository at the exact `.../step6_global_time/source` path. All **273**
root script files compare byte-identically against the extracted source.
Both extracted SOFs and root milestone aliases compare byte-identically with
main-root output. All **64** parent published product checksums passed.
The extracted package's 36 source/diagnostic/time-valid/pair tests passed;
46 related tests passed on Laptop. No old milestone source dependency remains
in those selected tests. Installer also rejects stale archive extractions.

At **17:57:26 +08:00**, the dashboard run from the extracted `source/` showed:

- Master TIME_VALID=1, PPS_VALID=1, Helper=1, TAI=2329, cycles=124999999.
- Slave TIME_VALID=1, PPS_VALID=1, all five displayed lock bits=1,
  TAI=2333, cycles=124999999.
- Both link/RX/TX gates good. Dashboard layout unchanged.

`verification-dashboard.log` retains that exact read-only result. This is a
**same-live-session packaging usability check**, not a third fresh programming
qualification, not proof of equal absolute time labels or physical alignment.
The two complete root build/compile/program/capture cycles are the PASS evidence.
The dashboard's Step5 INFO reflects its separate stability classifier; no
300-second Step5 lock verdict is inferred from this one-shot sample.

There is only one operational Step6 version in this folder. Old root milestone
and extracted packages were moved recoverably outside the repository:

- Pain: `/home/b10504072/WR_milestone_backups/step6-before-two-cycle-20261002`.
- Pain temporary old extraction:
  `/home/b10504072/WR_milestone_backups/step6-extraction-before-self-contained-tests-20261002`.
- Laptop: `C:/Users/zenbook/.codex/backups/WR-step6-before-two-cycle-20261002`.

Git history retains previous tracked packages. The protected
`04_WR_archive_step6_pass` was not accessed or changed. Compiler caches and
external toolchain installations are not part of the frozen source package.
