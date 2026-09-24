# Experiments

`experiments/` is the evidence space for ongoing and completed research.
Keep successful and failed experiments, negative controls, raw logs, build and
program provenance, analyses, and limitations. Do not replace or overwrite an
older experiment's evidence.

Use one directory per hardware run:

```text
experiments/stepX/EXP-.../
├── PLAN.md
├── REPORT.md
├── raw/build/
├── raw/program/
├── raw/observe/
├── analysis/
└── SHA256SUMS
```

Only accepted, internally consistent frames count toward runtime verdicts;
invalid/retried frames remain in raw evidence and must be reported. Milestone
promotion rules and current verdicts are indexed in [`MILESTONES.md`](../MILESTONES.md).
