# Independent fresh milestone rebuild — 2026-10-02

**PASS_FRESH_STANDALONE_MILESTONE_REPRODUCTION**.

Unlike the original packaging usability check, this run rebuilt firmware,
fully compiled both FPGA projects, programmed the fresh SOFs and captured
each board for more than 300 seconds, all from this package's independent
`source/` directory. Full run: 20:03:23–20:34:23 (+08:00).

| Board | TIME_VALID samples | Valid sample span | Max gap |
|---|---|---|---|
| Master | 1192/1192 | 302952 ms | 257 ms |
| Slave | 1192/1192 | 302872 ms | 256 ms |

Zero invalid rows or transport errors. Both boards remained VALID in the final
dashboard. Acquisition took about 180 seconds this time; no early WAITING
frame was treated as a passed dwell. All 3110 production inputs and both MIFs
match the previously qualified root version. Independent compile identity:
`6f298267cf578d051689db451f1b856b380ad1f6`.

Fresh SOFs in the extracted `source/output/` on Pain:

- Master: `5ac122d17959199f0a6a73c4b6e744f054a44f3bc5cff7fc9e5290752d8a6351`.
- Slave: `35db78d9d8bf969f91a9049e2592d921827c41d9dbe86a65c943e73c4fa33ac4`.

The archive and original root-level SOF aliases are unchanged. Newly compiled
products and their logs are retained as evidence, not a second code milestone.
See the [complete report](../../../experiments/step6/EXP-S6-MILESTONE-STANDALONE-FRESH-REBUILD-TIME-VALID-300S-20261002/REPORT.md)
and raw/offline audit in that experiment directory. This is the TIME_VALID-only
sampled gate, not proof of equal absolute time labels or physical synchronization.
