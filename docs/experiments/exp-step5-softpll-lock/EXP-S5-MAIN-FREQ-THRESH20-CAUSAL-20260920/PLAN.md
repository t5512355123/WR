# EXP-S5-MAIN-FREQ-THRESH20-CAUSAL-20260920

## Causal candidate

Change only the Slave Main frequency-lock detector acceptance threshold:

```text
Slave Main freq_ld.threshold: 50 -> 20
```

The Master remains at 50. The AUX channel, frequency lock sample count,
delock floor, PI gains, phase detector, bootstrap, timeout, PHY, RTL, SDB,
and F4J observer are frozen.

## Source scope

- Slave-only identity macro:
  `DE5A_MAIN_FREQ_LOCK_THRESHOLD_OVERRIDE 20`
- Applied only when `CONFIG_WR_NODE` is enabled and `dac_index == 0`.
- The default source assignment remains `s->freq_ld.threshold = 50`.
- Master identity intentionally does not define the override.

## Validation sequence

1. Run offline source/regression tests.
2. Push laptop source commit.
3. Pain pulls the exact commit, builds fresh Slave and Master JTAG images,
   and programs both boards using the existing build/program workflow.
4. Run exactly one read-only `read_wb_runtime.tcl --raw` capture.
5. Stop regardless of the result; do not run F4J in this experiment.

## Required direct-gate evidence

```text
Slave FREQ_LIMITS = 00320014
Master FREQ_LIMITS = 00320032
```

If the Slave word is not `00320014`, implementation is a failure and the
control result is not evaluated. Otherwise classify the operating state using
Helper lock, Main enabled/frequency lock, link, reset, generation, and SI-drop
fields. This experiment itself is not a Step5 pass.
