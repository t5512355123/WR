# Step 5 reproduction source deduplication audit

The former experiment-local `source/` tree was compared recursively with
`artifacts/milestones/step5_softpll_lock/source/`. All 3,207 files matched by
relative path and SHA-256:

```text
experiment-local files: 3,207
frozen milestone files: 3,207
missing paths: 0
extra paths: 0
same-path content mismatches: 0
```

The tracked redundant source copy was removed only after this complete identity
check. Four ignored Python bytecode cache files remain on disk in the former
copy; they are generated caches, not source or experiment evidence, and are
excluded from the repository. The experiment's plan, report, raw captures,
build/program records, analysis, and SHA256SUMS remain. Use the formal frozen
milestone source for future rebuilds.
