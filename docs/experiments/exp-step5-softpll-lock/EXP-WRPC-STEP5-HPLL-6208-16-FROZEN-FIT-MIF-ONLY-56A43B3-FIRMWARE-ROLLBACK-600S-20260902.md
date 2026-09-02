# EXP-WRPC-STEP5-HPLL-6208-16-FROZEN-FIT-MIF-ONLY-56A43B3-FIRMWARE-ROLLBACK-600S-20260902

## Purpose

Replay the branch5-directed firmware rollback using the exact historical WRPC
firmware source commit `56a43b3`, while preserving the currently trusted
`7585a06` fitted database. This is a MIF-only rollback: no fitter, synthesis,
place-and-route, HDL, controller, or timing result was regenerated.

The experiment was intended to isolate whether the current Step5 Helper-lock
boundary was introduced by later firmware changes.

## Provenance and frozen-fit identity

```text
branch                         = exp/step5-softpll-lock
local HEAD                    = b892c195a719cf897e9ba94fa982585385834381
rollback firmware source       = 56a43b3e8b1f73369576c6542f63fb027652636c
current fitted image lineage   = 7585a06
bootstrap                     = 6208
code_step                    = 16
kp                           = -300
ki                           = -1
shift                        = 12
bias                         = 5
threshold                    = 200
lock_samples                 = 10000
lane                         = 2
normal tracker               = ON
fitter/P&R                   = preserved from 7585a06
```

The exact historical SOFs referenced by the branch5 recommendation were not
available. Therefore the rollback images were assembled by rebuilding only
the Master and Slave MIFs at `56a43b3`, updating the frozen current project
with `quartus_cdb --update_mif`, and running `quartus_asm`.

```text
Master rollback MIF SHA256 = 8a0d6ed0a5dd8f6ae20fce3f668d279f42f5edc4bc58f5610192fdb9610eee3f
Slave  rollback MIF SHA256 = 1c635910ebd1d7f5497497be4c7f20d5e7e0fed5cf2d8ab66708d812bb343e71
Master rollback SOF SHA256 = 15ff2f2b53742f81e4553ae066128f1f273106c4172a66507af497c35eb3ca33
Slave  rollback SOF SHA256 = 8c83f79386a62ca27346549adc526311db6ce88d79c1a990b091baeb7b6ff58a
Master current SOF SHA256  = da9f67e6e167ea115ddfb24a3a03907553dab1efa39d1b51c8d89df74fbd7ed4
Slave  current SOF SHA256  = 2ab90316fc7425e4ea30c62ae4bb01e49e19a93cfe0fb67fcd19a14bdaea18ac
```

Frozen fit/timing hashes were unchanged by MIF-only assembly:

```text
Master fit.rpt SHA256 = e02fbf1a458861f46acb5a10f4463fb8f089715e0fffa48891feeae73b6925e1
Master sta.rpt SHA256 = fd36464ebc2e51551be1b95eac8fdeff1137983a6bde57547db5a94e9345d737
Slave  fit.rpt SHA256 = 3dfba19a8001ef0077c6e2dc745a126f648a08fdf39faa96fe929fb8c6a3044b
Slave  sta.rpt SHA256 = d801919fefc866dc51121f3e385b4d6b25b2a2377f97fa7d1ed77556081f2523
```

Both MIF updates and assemblies succeeded with zero errors. The nonfatal
Quartus warnings were the existing generated-QIP/parallelism/sopcinfo
warnings; no fitter or timing warning was introduced by this operation.

## Programming

The rollback images were programmed in the required order:

```text
Slave  DE5 [1-11.2] = successful, 0 errors, 0 warnings
Master DE5 [1-11.1] = successful, 0 errors, 0 warnings
```

## Settled preflight result

Two read-only `read_wb_runtime.tcl --raw` captures were taken, with the second
capture after an additional 45-second settling interval. Both had the same
result. Master remained healthy, but Slave never reached the upstream link
gate:

```text
Master Step1/Step2/Step4A       = PASS
Slave  Step1                    = FAIL
Slave  Step2                    = INVALID / NA
Slave  Step3                    = INVALID / NA
STEP4B_ALLOWED                  = NO
STEP4B_RESULT                   = BLOCKED_BY_STEP1
STEP4B_FIRST_INACTIVE_BOUNDARY  = UPSTREAM_PREREQUISITE
STEP5_RESULT                    = UPSTREAM_NOT_READY
JTAG_WB_DIAGNOSTIC_PATH         = TRUSTED
```

The blocking Slave fields were:

```text
si_config_done       = 1
wr_ready             = 1
wr_rx_ready          = 1
wr_tx_ready          = 1
core_tm_link_up      = 0 (required 1)
core_link_ok         = 0 (required 1)
wr_rx_enc_err        = 0
wr_tx_enc_err        = 0
WDIAGS_RXERR delta    = 0
WR_FAILURE_DEBUG      = TIMEOUT, last_fail_state=WRS_S_LOCK
WDIAGS_PTP            = DISABLED
```

Because the Step4B upstream gate did not pass, the requested 600-second
Helper observer was not started. This avoids treating an upstream link failure
as evidence about the Helper-lock boundary.

## Verdict

```text
STEP4B_COMPLETE       = YES (prior/current 7585a06 milestone)
STEP4B_REVALIDATED    = NO (rollback replay blocked upstream)
STEP5_COMPLETE        = NO
MERGE_APPROVED        = NO
FAILURE_CLASSIFICATION= UPSTREAM_SLAVE_LINK_GATE_FAILURE
```

This replay does not overturn the earlier fresh-program `7585a06` Step4B
PASS. It does show that the reconstructed MIF-only `56a43b3` rollback cannot
be used as a valid Step5 comparison on this run because the Slave fails before
Step4B. No merge is authorized.

## Baseline restoration

After the rollback preflight was blocked twice, the previously trusted
`7585a06` Master and Slave SOFs were restored in Slave-to-Master order. The
second settled restoration preflight passed:

```text
Master Step1/Step2/Step4A      = PASS
Slave  Step1/Step2/Step3/Step4B= PASS
STEP4B_ALLOWED                 = YES
STEP4B_RESULT                  = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
STEP5_FIRST_INACTIVE_BOUNDARY  = MAIN_FREQUENCY_LOCK
JTAG_WB_DIAGNOSTIC_PATH        = TRUSTED
```

The board is therefore no longer left in the failed rollback state.

## Raw evidence

The local raw evidence is under:

`docs/experiments/exp-step5-softpll-lock/raw/step5-firmware-rollback-20260902/`

It contains the two programming logs, both preflight captures, both firmware
build logs, and the MIF-update/assembly logs.
