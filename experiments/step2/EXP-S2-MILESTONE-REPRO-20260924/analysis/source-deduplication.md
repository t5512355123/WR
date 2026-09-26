# Step 2 reproduction source deduplication audit

The former experiment-local `candidate_source/` was compared recursively with
`artifacts/milestones/step2_endpoint_ptp/source/`. All 3,143 files matched by
relative path and SHA-256:

```text
experiment-local files: 3,143
frozen milestone files: 3,143
missing paths: 0
extra paths: 0
same-path content mismatches: 0
```

The redundant `candidate_source/` tree was removed only after this complete
identity check. The experiment's plan, report, raw build/program/observe logs,
analysis, and checksum evidence remain. Use the linked formal milestone source
for any future rebuild.
