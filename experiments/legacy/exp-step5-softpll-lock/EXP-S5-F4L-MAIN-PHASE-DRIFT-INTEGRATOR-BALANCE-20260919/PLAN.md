# EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260919

## Scope

One passive Main-DAC0 diagnostic capture after QSFP-A lane 0 link recovery.
The purpose is to distinguish phase drift from integrator/branch balance. It
is not a gain experiment and cannot establish Step5 pass.

## Fixed control baseline

Keep the latest A2 control image unchanged:

- Main Kp/Ki/boost: `300 / 1 / 20`;
- Slave Kp/Ki/boost: `300 / 1 / 20`;
- Helper Kp/Ki: `-2250 / -2`;
- Slave bootstrap: `3388`;
- Master bootstrap: disabled;
- candidate: `0/0`;
- timeout, thresholds, lock samples, anti-windup, handoff, tag pairing,
  DAC writes, RTL arbitration, reset behavior: unchanged.

QSFP-A remains on the recovered lane-0 route from source baseline
`87a304ad`/`ef3223ad`.

## Passive diagnostic contract

The already-reviewed F4L source records only Main `dac_index == 0`:

- 16-bin signed phase-error histogram;
- phase-conditioned frequency-error sum/count/min/max;
- contiguous same-generation/source/update phase-pair deltas with ambiguous
  half-turns and boundary crossings counted separately;
- frequency/phase actual integrator deltas, `Ki*x` proposals, clamp and
  anti-windup/mismatch counts;
- versioned three-page F4L publication with transport and source epochs;
- separate schedule shadow for page rotation and Main enable transitions.

It does not write control state, extend the shared control ABI, request a
Helper PI snapshot, drain the debug FIFO, or add a second reader.

## Observer limits

- smoke window: 10 seconds;
- formal target: 120 seconds;
- hard wall-clock limit: 130 seconds;
- stop on invalid schema, missing valid frames, generation/reset change,
  WR terminal, transport failure, or unsafe reader ownership.

The Tcl observer enforces the 120/130-second F4L contract even if an accidental
legacy duration is passed.

## Required evidence

Save the exact source/image manifest, offline fixture output, program console,
raw F4L pages, schedule shadow, WR/PHY context, hashes, and analyzer output.
Use same-generation endpoint deltas only. A diagnostic capture can be
`DIAGNOSTIC_COMPLETE` while `STEP5_PASS` remains false.
