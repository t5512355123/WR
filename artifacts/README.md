# Artifacts

`artifacts/milestones/stepX_*` contains promoted, frozen Step checkpoints.
Each milestone keeps its human-readable README, freshly built Master/Slave
SOFs, a top-level checksum file, and a complete independently buildable
`source/` snapshot with its own `SHA256SUMS`.

An artifact is promoted only after its own source has been clean-built,
programmed on both DE5a boards, and passed that Step's runtime acceptance.
Historical reports or a later Step's image are not substitutes.

Experiment raw logs, build/program provenance, and analysis belong under
`experiments/stepX/EXP-.../`, not in the milestone directory. Quartus databases
and disposable build outputs are not archived as milestone source.

See [`MILESTONES.md`](../MILESTONES.md) for the authoritative Step 1–6 index.
