# EXP-S5-QSFPB-F4M-FIRMWARE-REBUILD-RETRY-20260917

## Purpose

Retry the QSFP-B Step5 F4M smoke after the previous experiment stopped before
Quartus compilation because Pain lacks `rg`. The only source change is the
build-helper portability correction from `rg` to POSIX `grep -E`.

The firmware MIFs must be rebuilt again in this retry so the full laptop to
Pain build boundary is explicit and the exact MIF hashes belong to this
experiment. Keep the QSFP-B lane-0 mapping and all Step5 production control
behavior unchanged.

## Procedure

After Pain pulls this commit, run:

```text
bash scripts/pain/pain_build_portb_step5.sh \
  EXP-S5-QSFPB-F4M-FIRMWARE-REBUILD-RETRY-20260917
```

The helper must finish firmware build, identity-marker/hash manifest, and both
port-B Quartus compiles. Save programmer logs after programming Slave
(`DE5 [1-11.2]`) first and Master (`DE5 [1-11.1]`) second. Then run:

```text
timeout 120s quartus_stp -t \
  scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  100 1000 "" 60000 70000 f4m
```

Save the read-only preflight and F4M output under this experiment's
`raw/observe/` directory.

## Interpretation

`MAIN_F4L_VALID=1` with coherent/unique pages is required before any Main
phase conclusion. Even if F4L becomes valid, this smoke is not Step5 PASS
unless the repository's sustained Main/Helper/phase/PSTAT lock criteria are
met. If F4L remains invalid after the fresh MIF build, stop and classify the
firmware-to-WDIAGS runtime compatibility boundary; do not try QSFP-C or tune
PI/gain/threshold/timeout.

