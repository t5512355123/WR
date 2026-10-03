# Final archive/publication audit — 2026-10-04

Source/package integrity PASS; fresh standalone runtime qualification
NOT_ESTABLISHED. See REPORT.md for both600s acquisition timeouts and the
five-lock/WAIT_OFFSET_STABLE post-failure observations. No303s capture began.

Final canonical package includes ONLY the qualified main-root version and
its known-passing products/evidence. Root qualification remains Master1191
and Slave1190 valid samples, each spanning>300s. The failed independent rebuild
and its complete repository are preserved outside the canonical package.
Successful root history must not be used to label this new boot as passed.

Canonical `/home/b10504072/04_WR/artifacts/milestones/step6_global_time/`:

- Source snapshot checkout85b6edb1; production compile00b2342b unchanged.
- `source.tar.gz` SHA256 `2184c0ab9d5d6c22a5689413b93284bc7c8a7d6a7d85a835a9eca1e299f67fe3`.
- Qualified `master.sof` SHA256 `33e58bf47e7e944a30d90cb791eba0416213ad9838b073642e44b1057ea42134`.
- Qualified `slave.sof` SHA256 `fa5e4d2ce52e3cbbdf65ceaa14a34b0360d0e2af47bfb3fdd4385893b3e99c6f`.
- Archived/prepared source/output SOFs and aliases are byte-identical.
- All tracked main-root scripts are byte-identical in the prepared source.
- All3117 production inputs verify against the pinned418bb254 manifest.
-12 source/analyzer tests pass in the final prepared package and on Laptop.

All311 returned products/records/package files were SHA256-verified on Laptop
against TRANSFER_SHA256SUMS; zero mismatches. Transfer bundle SHA256:
`f0286e8e7fde6530a5a5f52ab5e84bdae201518fac000cdb7059a3c505b6a02f`.
Laptop independently re-counted readiness rows:376/376 Master valid and0/376
Slave valid, and independently compared both root/fresh RBF SHA256 pairs.
These separate1s readiness windows are not a continuous300s qualification.

Recoverable external Pain backups:

- Original package: `04_WR_step6_package_backups/20261003T160324Z/step6_global_time`.
- Unqualified full rebuild: `04_WR_step6_package_backups/20261003T165122Z-unqualified-rebuild/source`.
- Intermediate qualified package: `04_WR_step6_package_backups/20261003T165502Z/step6_global_time`.

The previous Laptop package is recoverable at
`C:/Users/zenbook/AppData/Local/Temp/wr-step6-before-current-76e6de380604477faafac304646524f5/step6_global_time`.
Protected `/home/b10504072/04_WR_archive_step6_pass/` and other milestones were
not modified. No reset/power cycle or further programming/tuning after the
bounded failed reproduction. No persistent JTAG reader/programmer remains.
