# EXP-S6-TIME-VALID-STABLE-300S-20261001 — baseline attempt record

This experiment is complete. Its run tested only Slave `1-11.2` using the
canonical frozen Step 6 milestone SOF. It did **not** establish the revised
Step 6 criterion: the Slave's exported `STATUS_TIME_VALID` remained 0 in all
1,186 samples. A Master one-shot after the capture is not a 300-second record.

The current acceptance requires each board independently to show sampled
`STATUS_TIME_VALID=1` over at least 300,000 ms, with at least 301 ordered rows
and no sample gap over 1,000 ms. The new signal-only gate ignores snapshot,
PPS, counter progression, link, lock, phase-offset, and timing-closure fields.
The next experiment is
[`EXP-S6-TIME-VALID-300S-QUARTER-ACQUIRE-20261001`](../EXP-S6-TIME-VALID-300S-QUARTER-ACQUIRE-20261001/PLAN.md).

## Executed setup (preserved for provenance)

- Frozen Step 6 source origin:
  `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Frozen source tree: `artifacts/milestones/step6_global_time/source/`.
- Quartus: Prime Standard 17.0.0 Build 595.
- Master canonical SOF SHA-256:
  `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Slave canonical SOF SHA-256:
  `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- Slave was programmed before Master; these canonical files were the inputs.
- The prior execution used a 302-second requested capture at 250-ms cadence on
  Slave only. Preserve its original logs under `raw/`.
- The observer is read-only. It does not establish sub-sample continuity.
- `/home/b10504072/04_WR_archive_step6_pass/` is protected and must never be
  accessed.
