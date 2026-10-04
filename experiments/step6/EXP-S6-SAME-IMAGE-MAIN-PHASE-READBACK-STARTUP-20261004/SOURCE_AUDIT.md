# Source-proven diagnostic boundaries

Production sources are unchanged from the3117input manifest418bb254.
This audit explains what the new passive readbacks can and cannot establish.

## Busy gate, request and execution progress

`ppsi/proto-ext-common/wrh-servo.c` updates its offset/update_count first,
then returns while `adjust_in_progress()` is true. Thus a progressing servo
UCNT and a WAIT state alone do not prove a completed phase adjustment.
`ppsi/arch-wrpc/wrpc-spll.c` defines busy as PPS-counter adjustment OR
Main shifter busy. Main busy is the exact firmware comparison
`phase_shift_target != phase_shift_current` in `softpll/spll_main.c`.

SYNC_PHASE adds C-truncated offset/2 to SETP, calls adjust_phase, enters WAIT.
TRACK adds offset/12 or falls back at abs(offset)>120ps. WAIT enables time
only through its legacy<60ps test. The later fallback does not revoke
previously enabled time, as already established by native baseline tests.

In `softpll_ng.c`, phase requests pass to mpll_set_phase_shift and are
converted from ps to DMTD units; HPLL_N14,8000ps reference and divide-by-two.
In each locked Main update, phase_shift_current moves at most one unit
toward phase_shift_target. The F4L producer captures current BEFORE that
advance. Update ID/source epochs establish producer activity, not actual
DAC application or measured physical phase. `pll gps 0` reads the real
firmware current/target fields in ps, not a physical phase measurement.

The optional Main observer reads only the common F4L v1 subset, whose
transport is guarded by equal even publication epochs and whose source
copy has a positive even source epoch. Main and servo groups have separate
time windows. Stable servo-publication UCNT is not proof that the slower
publication reflects the currently executing request at every instant.
The modeled ideal target is mathematical quantization, not a target-register
read. The negative signed32 converter risk≤−131072ps remains separately
flagged and must not be assigned as a cause without actual affected data.

## A busy component can already be excluded in the midnight failure

`dev/pps_gen.c:shw_pps_gen_busy` returns not-busy when CR.CNT_ADJ is1.
`include/hw/pps_gen_regs.h` maps CNT_ADJ to bit2. The preserved failed
standalone dashboard has CR20000006, hence PPS-counter busy=0 at that
observation. That rules out a PPS counter action still pending in THAT
dashboard; it does not establish Main-shifter state or all earlier history.
Main target/current were not recorded in that lost failed boot.

## Calibration and timestamp branch, not a guessed replacement value

`dev/netif.c` initializes phase_transition from
`include/dev/rxts_calibrator.h` DEFAULT_T24P_PHASE_TRANSITION2389ps.
`dev/rxts_calibrator.c` explains that a Master must be calibrated previously
as a Slave and load storage; its normal Master boot does not run that Slave
scan. The readonly `pll stat` query only prints cached/current scan/tracker
state, never starts calibration or loads storage. Observed Master2389ps and
unstarted scan establish a default-valued observation, not a measured correct
transition phase. They do not prove the stored value is absent or incorrect.

`lib/net.c:ptpd_netif_linearize_rx_timestamp` selects rising or falling
coarse counters from the calibrated DMTD phase and ahead flag. A branch
switch can change the selected coarse contribution by one8ns tick; WR offset
math can halve a return-leg change. Continuity requires the coarse/phase/
calibration relationship, not merely Main lock flags. This is a plausible
boundary supported by earlier timestamp experiments, not proof that it
caused this particular midnight startup failure. No guessed T24P, forced
calibration, phase target, control gain or threshold is written this round.

The20s live smoke is actual hardware evidence:8/8 Main frames valid, producer
updates progressed in7 same-identity intervals;5 matched publication pairs
have current equal to ideal SETP units. It establishes the reader and one
already-successful boot's software progression, not fresh-start reliability.
