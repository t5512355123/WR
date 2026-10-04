# Main production-source restoration — 2026-10-04

## Scope and result

User requested the main-root production code match the sealed Step6 milestone,
without changing the milestone. The subsequent clarification explicitly excludes
scripts from restoration and requires the existing direct editable build,
compile and programming workflow, without SHA acceptance checks.

Result: `PRODUCTION_SOURCE_RESTORED`. This is a source-only change, not a new
hardware qualification or TIME_VALID300s PASS.

Base checkout: `cfe535413d503731f70a623ff514b6225c40b3e8`, branch
`feat/file_cleanup`.

The only production edit is
`vendor/wrpc-sw/ppsi/proto-ext-common/wrh-servo.c`: remove the no-phase-correction
diagnostic guards and restore the milestone's actual initialization, acquisition
and tracking phase writes. Acquisition is `/2`; tracking is `/12`. Entry/exit
thresholds remain 60/120ps. No forced TIME_VALID or relaxed offset gate is added.
Other production inputs already matched the milestone and were not changed.

## Verification

Read-only streaming comparison against
`artifacts/milestones/step6_global_time/source.tar.gz`, without extraction or
SHA checks:

| Production group | Files compared | Differences |
|---|---:|---:|
| vendor | 2947 | 0 |
| firmware | 7 | 0 |
| quartus | 25 | 0 |
| quartus_generated | 138 | 0 |
| Total | 3117 | 0 |

All 3117 archived production files match byte-for-byte. Scripts are intentionally
excluded from this comparison/restoration.

Laptop offline tests: 28 tests PASS across `test_editable_current_workflow`,
`test_step6_time_valid_300s` and `test_post_settling_cko`. Editable pipeline tests
use substitute tools, including a failing SHA-check substitute, to verify that
build/program do not depend on SHA acceptance. No FPGA or firmware is built by
these tests. Four manual workflow scripts pass Bash syntax checking.

The preserved no-correction source assertions/observer describe the previous
diagnostic and must not be interpreted as the restored controller. The native
historical-controller regression is `run_wrh_time_valid_baseline_c.sh`.

After Laptop push and Pain fast-forward pull, Pain also passes the same 28
offline Python tests and all 22 native historical-controller C cases with
undefined-behavior checking. The native test executes the real restored servo
using substitute hardware interfaces: acquire=2, track=12, no forced entry.
This is a host-side test, not firmware/FPGA compilation or a hardware capture.
Pain has no working-tree differences in production code, scripts or artifacts
after pulling; existing user-modified build/output products are preserved.

`git diff --check` PASS. No tracked changes to `scripts/`, `artifacts/`, `build/`
or `output/`. Existing products and untracked experiment evidence are preserved.
The protected external Pain archive is not modified or used as a working tree.

## Manual deployment

From `/home/b10504072/04_WR`, run each step only after the preceding step succeeds:

```sh
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

Existing scripts retain `CURRENT_BUILD_POLICY=editable`; build/program SHA
acceptance is disabled. Compile exports new SOFs to
`output/DE5a_wr_master_jtag.sof` and `output/DE5a_wr_slave_jtag.sof`.
Stop other dashboard/JTAG readers before programming. No process is stopped by
this restoration. The existing configuration's historical no-correction
experiment-directory label is preserved because scripts were explicitly left
unchanged; it does not identify the firmware loaded into the boards.

No firmware/FPGA build, programming, runtime observation, reset or power-cycle
is performed in this restoration. Existing SOFs are not changed to the restored
source until the user performs a fresh build and compile. Milestone history
contains sampled300s TIME_VALID success and also a failed fresh standalone
acquisition; source equality alone does not guarantee every startup or a fresh
300s PASS.
