# Step 5 four-lock raw audit

Capture: raw/observe/f4l_300s.log
Offline parser output: analysis/f4l_300s_analysis.json
Historical acceptance definition: the 2026-09-20 Step 5 300-second lock audit.

## Window and frame integrity

- Observer end: TARGET_REACHED, STOP_REASON=NONE, session_elapsed_ms=301253.
- Target: 300000 ms; hard limit: 310000 ms.
- Slave cycles: 317; primary Main F4L frames valid: 317/317.
- Unique Main observations: 155 over 300291 ms; valid 10-second bins: 31.
- Strict parser: 309 schema-consistent frames, 8 histogram-accounting warnings, no semantic problems.

## Functional gates

| Gate | Count | Source field and interpretation |
|---|---:|---|
| Helper/HPLL lock | 317/317 | HELPER_LOCKED=1; helper lock count reached the required sample threshold |
| Main frequency lock | 317/317 | BRANCH_ID=2 and frequency-lock-after bit set |
| Main phase lock | 317/317 | phase-lock-before/after, phase-called, and phase-in-band set; phase-out-of-band clear |
| PSTAT lock | 317/317 | PSTAT_LOCKED=1 |

Every Main frame reported FLAGS=383 decimal (0x17F). The frozen source
header defines bits 0-6 as valid, frequency-lock-before/after,
phase-lock-before/after, phase-called, and phase-in-band; bit 7 is
phase-out-of-band and was clear; bit 8 is DAC-write and was set. Thus the
frequency and phase gates are directly present in each coherent Main frame.

## Stability

Across all 317 Slave cycles: PHY_LINK_USABLE=1, PSTAT_LOCKED=1,
RESET_CHANGED=0, BOOT_GENERATION=1, TERMINAL=0, and
SPLL_DELOCK_COUNT=0. No runtime stop condition occurred.

## Explicit accounting warnings

All eight parser warnings are HISTOGRAM_PHASE_COUNT_MISMATCH on page 2:

| Repeated cycles | Source epoch | Flags |
|---|---:|---:|
| 19 and 20 | 1637716 | 383 |
| 109 and 110 | 2289994 | 383 |
| 241 and 242 | 3246668 | 383 |
| 301 and 302 | 3681520 | 383 |

The raw rows are preserved. Each pair is the same page/source epoch sampled
twice; no rows were edited or removed. Schema-consistent fresh observations
still span 300291 ms and occur in every one of the 31 10-second bins.

The standalone F4L schema analyzer is a diagnostic closure checker, not the
Step 5 verdict. Its FRAME_SCHEMA_INVALID classification is retained as a
limitation; the four Step 5 functional gates are audited separately above.
