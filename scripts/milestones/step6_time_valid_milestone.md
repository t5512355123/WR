# Step6 — current successful main-root TIME_VALID version

This package has ONE operational production version: the main-root
`EXP-S6-MAIN-ROOT-TIME-VALID-300S-BACKTRACK-20261003` candidate which completed
fresh build, full compile, two-board programming and sampled TIME_VALID300s.

Root qualification: Master1191/1191 over302747ms; Slave1190/1190 over302799ms,
zero invalid samples or capture errors. Source compile identity:
`00b2342b22c8de000b08be4f4fc9ac1eb44f215e`.

**Main-root qualification PASS; new standalone reproduction NOT ESTABLISHED.**
The independent fresh build/compile and two-board programming succeeded on
2026-10-04, but Slave never acquired TIME_VALID in two bounded600s readiness
attempts in that same boot. No full303s capture began. Allfive PLL locks were1
afterward, with WAIT_OFFSET_STABLE and CKO-2460ps. Root/fresh Master and Slave
RBF configuration payloads are byte-identical; the deeper startup/acquisition
cause is not established. This archive does NOT promise PASS on every boot.
See the external experiment report:
`experiments/step6/EXP-S6-MILESTONE-MAIN-ROOT-TIME-VALID-300S-REPRO-20261003/REPORT.md`.
The failed rebuilt repository/products are preserved outside this canonical
package, not promoted as qualified images. A copy checksum is not a new300s
qualification. No control changes were made to manufacture a PASS.

## Standalone workflow on Pain

```sh
cd /home/b10504072/04_WR/artifacts/milestones/step6_global_time
bash prepare_source.sh
cd source
bash scripts/build/build_current.sh
bash scripts/build/compile_current.sh
bash scripts/program/program_current.sh
bash scripts/monitor/step1_6_dashboard.sh
```

The SOFs to program are this `source/output/DE5a_wr_master_jtag.sof` and
`source/output/DE5a_wr_slave_jtag.sof`, not main-root outputs. Stop the
dashboard with Ctrl+C before running another JTAG reader/programmer.
After acquisition, validate sampled300s with:

```sh
bash scripts/monitor/verify_time_valid_300s.sh
```

It captures the boards sequentially for303s each,250ms requested interval,
requiring every sampled `STATUS_TIME_VALID=1` and >=300s actual sample span.
Expect around10minutes plus bounded acquisition time. One dashboard frame
is not300s evidence.

## Contents and scope

`source.tar.gz` contains all qualified production inputs, scripts/dashboard,
retained firmware/build/output products and successful current experiment
evidence. Other milestones, failed prior images, compiler caches/toolchain
installations and Git history are not embedded. `prepare_source.sh` verifies
the package, extracts `source/` and creates its own independent Git identity.
Fresh compile provenance therefore differs from the parent's root commit.

`master.sof` and `slave.sof` are the retained qualified root pair, duplicated
byte-for-byte in archived and extracted `source/output/`. Unqualified fresh
products and all failure evidence are kept outside this operational package.
`ARCHIVE_SHA256SUMS` and `SHA256SUMS` identify the sealed archive and alias SOFs.

The historical WR validity policy is restored. Controller numerical entry/
fallback thresholds remain60/120ps; TIME_VALID can stay1 during fine-phase
reacquisition. This package proves sampled TIME_VALID retention only, NOT
offset within120ps, absolute UTC/TAI accuracy, simultaneous sampling, physical
PPS/SMA skew or timing closure. Existing firmware still performs real
acquisition; no observer or host command forces the valid bit.

The superseded whole package is recoverably backed up outside this canonical
milestone. `/home/b10504072/04_WR_archive_step6_pass/` is unchanged and read-only.
