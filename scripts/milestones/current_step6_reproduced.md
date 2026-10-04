# Step6 — current main-code TIME_VALID milestone

This is one self-contained operational version of the committed main program.
The retained pair was independently rebuilt and programmed from
`artifacts/milestones/step6_global_time/source`, not borrowed from root output.
See `VERIFICATION.md` and `verification-result.json` for the actual run,
source/bitstream identities, sample counts and measured qualification spans.

Only seal this template after both boards pass the unchanged sampled
TIME_VALID300s verifier. A successful compile, copy or dashboard frame alone
does not qualify a milestone. Fresh-boot acquisition is not guaranteed merely
because one boot passed; preserve any earlier timeout in the experiment history.

## Reproduce on Pain

Stop any other dashboard/JTAG reader first. Run these four existing steps:

```sh
cd /home/b10504072/04_WR/artifacts/milestones/step6_global_time
bash prepare_source.sh
cd source
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

The newly compiled SOFs are:

- `source/output/DE5a_wr_master_jtag.sof`
- `source/output/DE5a_wr_slave_jtag.sof`

After stopping the dashboard with Ctrl+C, verify a full sampled retention run:

```sh
TIME_VALID_ACQUISITION_TIMEOUT_S=600 bash scripts/monitor/verify_time_valid_300s.sh
```

It allows bounded acquisition, then observes each board sequentially for303s,
requested250ms interval. Every TIME_VALID sample must be1, actual sample span
must be>=300s, gaps<=1000ms, both board identities and DONE records present.
Total observation takes about10minutes after acquisition. This is not a
simultaneous dual-board capture or a claim of unobserved sub-sample behaviour.

## Package and limits

`source.tar.gz` contains production sources, firmware/build/compile/program
scripts, dashboard and analyzer, retained firmware/output products and the
successful qualification record. No compiler caches, unrelated milestones,
Git history, alternative failed images or unbuilt diagnostic changes are
operational inputs. `prepare_source.sh` checks the archive and creates an
independent source repository for honest subsequent compile provenance.

Alias SOFs match `source/output` byte-for-byte. Check `ARCHIVE_SHA256SUMS`,
`SHA256SUMS` and `VERIFICATION_SHA256SUMS` before using the package.

Acceptance is sampled TIME_VALID300s only. Historical WR phase entry/fallback
thresholds remain60/120ps; valid can remain asserted during fine-phase
reacquisition. This does NOT certify precision offset, absolute UTC/TAI,
physical PPS/SMA skew, timing closure or deterministic startup. No forced
validity, gain/control/calibration/RTL/SDC change was used for this reproduction.

Superseded packages remain recoverable outside the canonical folder.
`/home/b10504072/04_WR_archive_step6_pass/` is unchanged and strictly read-only.
