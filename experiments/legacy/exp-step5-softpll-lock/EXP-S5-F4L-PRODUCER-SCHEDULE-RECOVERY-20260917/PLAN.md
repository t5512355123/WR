# EXP-S5-F4L-PRODUCER-SCHEDULE-RECOVERY-20260917

## Purpose

Recover the original runtime path for the next passive F4S producer-schedule
smoke, following the latest phase-lock diagnosis.  The latest diagnosis says
not to switch to QSFP-B while the validated F4L capture has a usable WR link;
therefore this recovery keeps the original image/topology and does not mix a
port sweep into the producer-schedule experiment.

## Fixed scope

- Reuse the already validated `f847f4e7` JTAG Master/Slave images.
- Reprogram Slave `DE5 [1-11.2]`, then Master `DE5 [1-11.1]`.
- Perform one read-only runtime preflight.
- Run F4S only if both boards satisfy the WR link gate.
- No QSFP port switch, physical power-cycle, source/control change, PI/gain
  change, timeout change, detector/anti-windup/DAC change, RTL/SDB change, or
  second reader.

## Entry gate for F4S

Both endpoints must show `SI_CONFIG_DONE=1`, `CPU_RESET_N=1`,
`CORE_TM_LINK_UP=1`, `CORE_LINK_OK=1`, and `PHY_LINK_USABLE=1`.  If the gate
fails, stop without interpreting Main enable, page scheduling, page2 due, or
page2 publication.

## Stop condition

This recovery ends at the first failed upstream gate.  It does not claim a
producer-schedule result or Step5 result.
