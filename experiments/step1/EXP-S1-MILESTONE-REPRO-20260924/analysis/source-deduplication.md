# Step 1 reproduction source deduplication audit

The experiment-local `candidate_source/` was compared recursively with
`artifacts/milestones/step1_phy_link/source/` before removal. For every file,
relative path and SHA-256 were compared.

```text
experiment-local files: 3,121
frozen milestone files: 3,119
frozen files missing from candidate copy: 0
same-path content mismatches: 0
extra candidate-copy files: 2
```

The only two extra files were Python bytecode caches:

```text
scripts/analysis/__pycache__/analyze_step1_capture.cpython-312.pyc
scripts/tests/__pycache__/test_step1_capture_analyzer.cpython-312.pyc
```

All source, wrappers, metadata, and checksum-manifest files in the old copy
were exact matches in the formal milestone source. The two generated `.pyc`
files are caches, not source or experiment evidence. The tracked source tree
was removed; those two ignored cache files remain on disk under the old staging
path but are not part of the repository. Build/program/runtime evidence under
`raw/`, analysis, plan, report, and checksums remains in this experiment.
