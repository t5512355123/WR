# EXP-S5-QSFPB-F4M-FIRMWARE-REBUILD-20260917

## Purpose

Repeat the QSFP-B Step5 F4M smoke with a freshly built WRPC firmware image.
The preceding B-port SOF was successfully programmed and its PHY/WR path was
healthy, but every Main F4L frame was invalid. The B project loads firmware
from `build/firmware/{slave,master}/wrc.mif`; this round makes that firmware
build an explicit, recorded part of the experiment boundary.

## Single changed boundary

Only the firmware-image build boundary is changed:

1. build Slave and Master firmware from the pushed source and identity headers;
2. record the identity/config/MIF hashes and F4L compile-time markers;
3. compile the same QSFP-B lane-0 Quartus projects;
4. program Slave, then Master;
5. repeat the existing read-only F4M smoke.

The identity headers must retain:

```text
DE5A_F4L_MAIN_PHASE_DIAG=1
DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD=1
DE5A_MAIN_PI_KP_OVERRIDE=300
```

No PI/gain/threshold/timeout/bootstrap/arbiter/mailbox/detector/DAC-ordering,
PHY, reset, RTL, SDB, or observer-control behavior may change.

## Laptop boundary

Use `scripts/pain/pain_build_portb_step5.sh` from this commit after Pain pulls
the branch. It rebuilds both MIFs before the two port-B Quartus compilations
and stores the build manifests in this experiment folder.

## Pain procedure

From the repository root:

```text
bash scripts/pain/pain_build_portb_step5.sh \
  EXP-S5-QSFPB-F4M-FIRMWARE-REBUILD-20260917
```

Then program the newly generated SOFs in this order:

```text
Slave: DE5 [1-11.2] / quartus/jtag_runtime_diag_portb/output_files_slave_portb/DE5a_wr_slave_portb.sof
Master: DE5 [1-11.1] / quartus/jtag_runtime_diag_portb/output_files_master_portb/DE5a_wr_master_portb.sof
```

Save both programmer logs under `raw/program/`. Run one `read_probe.tcl`
preflight, then the exact existing F4M smoke:

```text
timeout 120s quartus_stp -t \
  scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
  100 1000 "" 60000 70000 f4m
```

Save preflight and observer output under `raw/observe/`.

## Pass/fail interpretation

This experiment is **not** Step5 PASS unless the observer obtains coherent,
unique F4L frames and the repository's sustained Main/Helper/phase/PSTAT lock
criteria are satisfied. If F4L becomes valid but `PSTAT_LOCKED` remains zero,
record the correlation and stop without tuning. If F4L remains invalid despite
fresh MIF hashes, classify the failure as firmware-to-WDIAGS/runtime-image
compatibility and stop before trying QSFP-C.

