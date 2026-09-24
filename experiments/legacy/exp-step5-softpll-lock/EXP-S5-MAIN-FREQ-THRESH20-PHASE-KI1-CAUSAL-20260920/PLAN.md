# EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-CAUSAL-20260920

## Objective

Test whether restoring the configured Main phase-branch integral term can
remove the remaining phase-frequency bias after the threshold20 candidate
reduced the residual frequency error.  This is a single causal candidate, not
a parameter sweep.

## Exactly one control difference

```text
previous threshold20 arm: Slave DE5A_MAIN_PHASE_PI_KI_ZERO = 1
this candidate:           Slave DE5A_MAIN_PHASE_PI_KI_ZERO = 0
effective phase Ki:       0 -> configured Ki=1
```

The Master identity is unchanged and remains on its current Ki=0 identity.

Everything else is frozen:

```text
Slave Main frequency threshold = 20
frequency lock samples        = 50
frequency-branch Ki            = 1
Main Kp                        = 300
prelock boost                  = 20
phase threshold                = 1200
phase lock samples             = 1000
bumpless frequency-to-phase preload = enabled
F4L diagnostic owner           = enabled
Helper / timeout / PHY / RTL / SDB = unchanged
```

## Required sequence

```text
offline source diff and tests
  -> push laptop source commit
  -> Pain pull
  -> clean Slave firmware/FPGA build
  -> program Slave candidate only
  -> one read_wb_runtime --raw direct gate
  -> stop
```

The Master is not rebuilt or reprogrammed because it has no source/control
diff in this candidate.  Do not run F4L formal in this round.

## Direct-gate stop conditions

The gate is valid only if the runtime remains healthy and records the frozen
Slave threshold20 limits.  If Helper is still unlocked or Main is disabled,
classify the implementation as passed but the control result as
`NOT_EVALUATED_UPSTREAM` and stop.  If Helper/Main are healthy, classify the
candidate as allowed for a later F4L formal and stop.  Any link, reset,
generation, SI-drop, transport, or Helper regression invalidates the control
result and stops the round.

Regardless of the direct snapshot, this round cannot declare Step5 PASS;
stable phase-lock evidence and timing closure are still required.

