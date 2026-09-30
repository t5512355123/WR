# EXP-S6-WR-FAILURE-RECORD-SOURCE-RAW-AUDIT-20261001

## Objective

Use the already captured WR lock-event raw log to decode the failure record
from its source-defined register, and determine which of these paths is
supported by evidence:

- S_LOCK timeout;
- automatic Slave re-arm;
- WR extension disable.

This is an offline/source audit only. It does not compile, program, reset,
power-cycle, or open a JTAG/Wishbone reader.

## Exact baseline

- Repository: t5512355123/WR
- Branch: feat/file_cleanup
- Audit baseline: 1b0cd82246ba98953fca80159db2194062f005ae
- Capture report: EXP-S6-WR-LOCK-EVENT-CONTINUITY-TRACE-20261001
- Raw log: raw/observe/20260930T194058Z-wr-lock-event-continuity.log
- Expected raw SHA-256:
  9fc2da70c44d005e351a721057f26b2f9506e441d752b354fde8338b56197580
- Capture checkout recorded before programming:
  fa9a813274783e3974fbdf76b46130b18637a246
- Exact pinned Slave/Master SOF SHA-256:
  13a457cd8c9457e04a60eec2384fb0e741f5defe2022724dee4b83f930891b19 /
  697d998c97618b819ffcd705edc044ed08662131e7de3d623a3143d57a53146a
- Matching saved build metadata: repository commit
  9c9afa345c1de03760ec9ee07eb742888c3fa8fe; frozen source origin
  74dc28862653d306e0450cf437ba6d3a230d979d.

## Allowed scope

- Add an offline decoder and its regression tests.
- Correct the event-continuity analyzer's result label so the observer's
  historical stop-rule string is not presented as proof of extension disable.
- Add this audit report and correct the preceding capture report.

Do not modify the Tcl observer, frozen firmware/RTL source, SOFs, build inputs,
control parameters, or any Pain/archive data. Do not access the read-only
Step 6 archive.

## Required audit

1. Recompute the raw SHA-256 and validate all 741 rows.
2. Decode A6C low-eight failure count, last-failure role/state, and disable
   metadata without treating invalid metadata bits as valid fields.
3. Decode A8C result/check-lock, reason bits 9–15, and failure timer low16.
   Keep the timer as a low-word tick value; do not convert it to host seconds.
4. Preserve row/read brackets, RX/TX raw words, WR mode/parent context,
   SoftPLL/Helper/Main/PSTAT context, and S_LOCK tail as non-atomic context.
5. Audit the failure/re-arm/disable writers, call sites, and reset paths in the
   frozen source. Verify the exact SOF hashes against saved build and program
   records rather than substituting other Step 6 milestone images.

## Stop conditions

Stop the audit without any hardware action if the raw hash/rows fail validation,
the mapping conflicts with frozen source, or image/source provenance conflicts.
After decoder tests, source-path review, and report correction, stop and wait
for a fresh advisor direction before any further hardware capture.
