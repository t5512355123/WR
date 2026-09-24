# EXP-S5-ROLLBACK-STEP1-MILESTONE-RS422-20260919

## Verdict

```text
ORIGINAL_STEP1_LINK = PASS
STEP2 = NOT_RUN
STEP3 = NOT_RUN
STEP4 = NOT_RUN
STEP5 = NOT_RUN
```

The earliest preserved pre-Git legacy Step1 milestone images were restored and
programmed. Both QSFP-A endpoints reproduced the original link-level status.
No Step2 or later diagnostic was started in this experiment.

## Image provenance

```text
source_class = PRE-GIT_LEGACY_STEP1_MILESTONE
baseline_date = 2026-08-15
topology = QSFP-A
active_lane = 0
master_target = DE5 [1-11.1]
slave_target = DE5 [1-11.2]
quartus = Prime 17.0 Build 595
```

Exact SOF files used from Pain:

```text
master = /home/b10504072/04_WR/artifacts/EXP-BASELINE-RS422/master.sof
master_sha256 = 9238740e35f2b48915d1fa7ee6d2dca9d443438f197f1226720dde9dd5e1892b
master_programmer_checksum = 0x3088011E

slave = /home/b10504072/04_WR/artifacts/EXP-BASELINE-RS422/slave.sof
slave_sha256 = 44251d6911c021e0d6fb12083034ec870a7d06a4374e435d27caa5e9efb36f15
slave_programmer_checksum = 0x308FFC95
```

These are the preserved legacy artifacts, not a rebuild of the current
Step5 branch and not a newly compiled image.

## Programming

Both programming operations succeeded with zero errors and zero warnings:

```text
Slave: DE5 [1-11.2] -> Configuration succeeded
Master: DE5 [1-11.1] -> Configuration succeeded
```

## Step1-only observation

The direct status probe was repeated 12 times per board. Every board sample
returned low 16-bit status `0x82CF`:

```text
Master: 12/12 = 0x82CF
Slave:  12/12 = 0x82CF
```

Under the repository's Step1 probe mapping, `0x82CF` means:

```text
si_config_done = 1
phy_ready      = 1
tm_link_up     = 1
link_ok        = 1
rx_ready       = 1
tx_ready       = 1
rx_enc_err     = 0
tx_enc_err     = 0
CPU_RESET_n    = 1
time_valid     = 0
pps_valid      = 0
```

The last two zeros are expected for a Step1-only milestone and are not used
to reject this link result.

## Conclusion

The rollback test confirms the suspicion's key separation:

> The earliest preserved Step1 SOF can still establish the QSFP-A PHY/PCS
> link, while the recent source-equivalent Step5 image could not.

This strongly implicates the later image/build changes or their generated
bitstream provenance as the next comparison target. It does not yet identify
which later change caused the regression. The experiment intentionally stops
at Step1 and does not claim Step2, WR signaling, SoftPLL startup, or Step5
lock.

## Raw evidence

- `metadata.md`
- `probe_master.txt`
- `probe_slave.txt`
- `program_master.log`
- `program_slave.log`
- `read-probe-12x.log`
- `manifest.txt`
- `raw-sha256.txt`
