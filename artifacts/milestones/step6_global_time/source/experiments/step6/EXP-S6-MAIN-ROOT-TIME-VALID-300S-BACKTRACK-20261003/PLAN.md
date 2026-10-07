# Main-root TIME_VALID 300s backtrack

User resumed experiments on 2026-10-03 with TIME_VALID >=300s as the target.
The preceding unchanged current-image capture failed on Slave: 434/1192 invalid
rows. It is retained, not overwritten or reclassified.

## Candidate and meaning

Restore the 3110 historical production inputs from qualified snapshot
`0bb02c6f91dd4c7a578e1b8cb02a553ce9ce9787`. Its actual qualified second root
compile was `7b6550123986a9d7cea5f4be0dbb8af1f5a019ab`; two independent root
cycles and one standalone fresh cycle each passed per-board TIME_VALID 300s.

This is a main-root fresh-build candidate, NOT a claim that retained SOF bytes
or a historical PASS prove the next boot. Master bootstrap2048/reverse1 and
HPLL physical-step accounting64; Slave Main Kp300/Ki1, frequency threshold20,
full-step DPLL admission16, WR /2 acquire and /12 track. No new gain sweep,
guessed calibration, clock/PHY/reset/timeout/SDC change or forced valid write.

The restore replaces 12 currently modified historical input files. Seven
later-added diagnostic headers/sources remain preserved but are not linked or
referenced by the qualified inputs. Tests require every original input to match
Git's baseline blobs, explicitly allow only those inert additions, and pin both
qualified MIF hashes before any FPGA compile/program.

IMPORTANT: this restores historical WR validity behavior, not strict full64
offset invalidation. The historical state machine enters TRACK only at <60ps
and falls back above120ps, but does not clear TIME_VALID on every fine-phase
fallback. Both numerical thresholds remain unchanged. TIME_VALID may therefore
remain1 while measured CKO exceeds120ps. No strict-offset precision, UTC/TAI
accuracy or physical PPS/SMA skew PASS may be claimed from this trial.

## Workflow and checks

1. Laptop restore, source-contract/actual-C harness preparation and offline
   analyzer tests; commit and push only scoped candidate/plan/tests/docs.
2. Pain pull the exact source commit in `/home/b10504072/04_WR`, preserve
   pre-change products, run native actual-servo C tests and shell syntax checks.
3. Run existing `scripts/build/build_current.sh`, then
   `scripts/build/compile_current.sh`; both firmware hashes and full compilations
   must pass, real new SOFs must exist in `output/` and match build metadata.
4. Run existing `scripts/program/program_current.sh` once, Slave then Master.
   One read-only dashboard, then a bounded600s acquisition readiness wait and
   the existing303000ms-per-board,250ms-sampled observer/unchanged analyzer.
5. Return complete raw/build/program/capture/result/checksums to Laptop,
   independently rerun analyzer and archive a truthful report; push records and
   real root products. No archive or milestone edits, no main merge.

Pass requires both board windows >=300000ms, every STATUS_TIME_VALID=1,
>=301 samples, exact expected board identities, sequential indices, matching
DONE counts, positive gaps<=1000ms and no capture error. Other signals are
diagnostic only. Boards are observed sequentially, not simultaneously.

Stop this candidate on source/MIF mismatch, compile/program failure, competing
JTAG owner, transport failure or600s acquisition timeout. Save all failures.
Only a completed capture can produce PASS; no cropping/replacing invalid rows.
After a PASS, stop tuning and report the actual current version. If not PASS,
record and inspect the failure before choosing a different experiment.
