# EXP-S5-F4J-PRODUCER-AUDIT-FREQ-COUNT-RECAPTURE-20260920

## Purpose

Repeat the bounded F4J producer audit solely to recover the complete stdout
capture. This is not a new control experiment. It uses the same live FPGA
session, the same F4J image, and the same observer as the corrected audit.

## Fixed provenance

- FPGA image source: `63bf952a3ea46dd0231f12d6d3e9b86d816ed953`
- Observer source: `b4ca04ac`
- Pain worktree: `eee6802806c689d7ddaac4838099674094c95214`
- Reprogram: `NO`
- Production-control change: `NONE`
- Target/hard duration: `30000/40000 ms`
- Full raw capture: `tee` from the first line, followed by SHA-256

## Stop rules

- Stop at the 30-second target or at any F4J early-stop/invalid condition.
- Do not run a control candidate after the audit.
- Do not change threshold, delock floor, Kp/Ki, timeout, or any production path.
