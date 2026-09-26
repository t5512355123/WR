# EXP-S6B-PAIN-DIRECT-PROGRAMMER-ACCESS-PREFLIGHT-20260922

## Verdict

```text
RESULT = PASS_DIRECT_NONSUDO_PROGRAMMER_ACCESS
FAILURE_CLASS = NONE
QUARTUS_PGM_LIST_RC = 0
MASTER_CABLE_VISIBLE = YES
SLAVE_CABLE_VISIBLE = YES
FPGA_PROGRAM_COUNT = 0
SUDO_USED = NO
PROGRAM_OPERATION = NO
```

This preflight confirms that Pain can enumerate both DE5 JTAG programmer
cables without the sudo wrapper. It does not program either FPGA and does not
constitute a Step6A or Step6B functional result.

## Source and fitted-artifact provenance

```text
Laptop/Pain source commit = d7cd0a55b6ecaab722a1038cdc8cea995a5c551c
Fitted design source      = c24568e383be3355ac8684b7d13f293115931586

Master SOF SHA256 = 1cc55bfd9f90dda061fb39f626d49473a7bbb6f6e5deb5803e81627865af76c5
Slave SOF SHA256  = 66360fe362983ab1a45eb19111ab7e731580b95878293ccf9532487e51462151
Master MIF SHA256 = 8b569afe29d93cfedca84eed484c9c683f1fc58cf10e89943574b7de8d31df7e
Slave MIF SHA256  = eab60d5ceb4af234284f6f241a4595ee850cf3a0184a939d70a30c3d8a5ad26b

POSTFIT_TIMING = PASS_STEP6B_POSTFIT_TIMING_PROVEN
PROVENANCE_CHECK = 1
```

All four fitted artifact hashes, the fitted source commit, and the prior
post-fit timing proof matched before the read-only command was executed.

## Read-only command and result

The only hardware-facing command was:

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_pgm -l
```

The preserved log shows:

```text
1) DE5 [1-11.1]
2) DE5 [1-11.2]
Info: Command: quartus_pgm -l
Info: Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

No `sudo`, password request, `-o` programming option, configuration action,
reset, PTP restart, target write, or ARM write occurred. The raw command log,
provenance, stop record, and JSON summary are preserved under this experiment
directory.

## Boundary for the next experiment

The previous stop is now isolated as a wrapper invocation problem:

```text
sudo wrapper = blocked
direct non-sudo quartus_pgm enumeration = PASS
```

This preflight is complete. A future hardware run needs a new adviser-approved
experiment using direct non-sudo `quartus_pgm` programming, with a fresh
Slave-once then Master-once allowance; this report does not grant that
allowance.
