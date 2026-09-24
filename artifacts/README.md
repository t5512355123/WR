# Frozen milestone artifacts

This directory contains only promoted Step checkpoints under `milestones/`.
Each checkpoint must include its human-readable README, Master/Slave SOFs,
SHA256 manifest, and complete independently buildable frozen `source/` tree.

A checkpoint is promoted only after its own source has been clean-built,
programmed on both DE5a boards, and passed that Step's runtime acceptance.
Historical reports or a later Step's image are not substitutes. Experiments,
raw captures, build/program provenance, and analysis belong under
`experiments/stepX/EXP-.../`. Quartus databases and disposable build outputs
are not milestone source.

See [`MILESTONES.md`](../MILESTONES.md) for the authoritative Step 1–6 index.
