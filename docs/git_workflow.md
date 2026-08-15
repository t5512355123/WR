# Git Workflow

## Source of truth

The laptop repository is the primary authoring checkout:

`C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\de5a-white-rabbit`

The pain bare repository is the shared transport endpoint:

`/home/b10504072/de5a-white-rabbit.git`

The pain working clone is used for Quartus 17 and firmware builds:

`/home/b10504072/de5a-white-rabbit-repo`

The old project at `/home/b10504072/04_White_Rabbit/week02/v01` is preserved
and is not a source-of-truth checkout.

## Branch rules

- `main` contains the known-good baseline and reproducibility changes.
- Each functional investigation uses `exp/<short-name>`.
- Do not create ambiguous branches such as `final`, `final2`, or `new`.
- A functional experiment must not be merged into `main` until its artifact
  metadata, build log, SOF/MIF hashes and runtime evidence are recorded.

## Normal change flow

1. Start from a clean local `main` or an explicitly named experiment branch.
2. Make one scoped change and record the reason in `docs/experiments/`.
3. Build firmware and Quartus on pain using the repository scripts.
4. Collect outputs into a new `artifacts/EXP-<id>/` directory.
5. Record the exact Git commit, QSF/SDC/MIF/SOF hashes, Quartus version and
   runtime result before programming a board.
6. Push the commit to the pain bare repository and fast-forward the pain clone
   to that exact commit.
7. Program only the SOF named by the experiment record. Keep the prior SOF and
   logs in their existing artifact directory.

## Build identity

The Quartus build wrappers write `build/build_info_master.txt` and
`build/build_info_slave.txt`. These files connect a SOF to the Git commit,
branch, top-level source, QPF/QSF/SDC, firmware MIF, Quartus version, Fitter
result, timing slack and unconstrained-path counts.

`Full Compilation was successful` means the compiler completed. It does not
mean timing closure, White Rabbit link-up or time synchronization succeeded.

## Recovery rule

If an experiment fails, stop the experiment, preserve its terminal output and
artifact directory, and return to the previously recorded known-good commit
and SOF. Do not overwrite the previous experiment directory.
