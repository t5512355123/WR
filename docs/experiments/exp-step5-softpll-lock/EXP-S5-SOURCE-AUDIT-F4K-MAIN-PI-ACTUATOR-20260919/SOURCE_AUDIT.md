# Source audit and bounded conclusion

## Audit result

```text
F4K_VALID_FULL_ARMS          = B, A2
F4K_A1                      = INVALID / WR_SESSION_ENDED
F4K_KP600_IMPROVEMENT       = NOT_SUPPORTED
F4L_LANE0_LINK               = CONFIRMED_BY_20260919_RUN
F4L_PHASE_DATA               = NOT_AVAILABLE
MAIN_PI_TRACE_SAME_PRODUCER = SUPPORTED_BY_SOURCE
ACTUATOR_LAG_CAUSALITY       = NOT_IDENTIFIED
STEP5                       = NOT PASS
```

The current branch tip is `9354cd1a9865f8dc1622877e43d01626185fca16`.
The F4L executable/control source used for the lane-0 run is
`c4095e7535d1e179e5aef88d2c8ee61130275a88`; commit `9354cd1a` adds the
capture/report artifacts.  These are source/image provenance facts, not a
claim that the F4L diagnostic passed.

## 1. F4K data audit

The comparison file classifies the formal ABA as `ARM_DATA_INVALID` because
A1 stopped at `WR_SESSION_ENDED` after 40.907 s.  B (Main Kp 600) and A2
(Main Kp 300) are the usable complete arms:

| arm | Main Kp | producer span | total | phase | phase in-band | handoffs | freq-error range | lock |
|---|---:|---:|---:|---:|---:|---:|---|---|
| B | 600 | 119264 ms | 455273 | 436968 | 59651 (13.6511%) | 84 | 17..74 | no |
| A2 | 300 | 118927 ms | 455282 | 437830 | 59607 (13.6142%) | 52 | 24..67 | no |

The B/A2 difference in phase-in-band ratio is only about 0.0369 percentage
points.  That is not evidence that doubling Kp improves Step5.  It also does
not prove all PI hypotheses are eliminated; it only says that this valid
B/A2 comparison does not justify adopting Kp 600.  A1 remains excluded from
formal ABA claims.

The bounded counter-delta table in `counter_delta_le10s.csv` uses the first
valid producer row and the last row whose endpoint remains within 10 seconds
of that start.  The observed spans are therefore reported as 9572 ms and
9001 ms, not rounded up to a fabricated 10,000 ms.  Both arms remain in
generation 1 and the producer update-id delta equals the total-update delta.

| arm | span | total | frequency | phase | phase in-band | phase out-of-band | F->P | P->F | freq error first->last |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| B | 9572 ms | 36133 | 1391 | 34742 | 4726 | 30016 | 3 | 3 | 48 -> 50 |
| A2 | 9001 ms | 36134 | 1578 | 34556 | 4696 | 29860 | 2 | 2 | 63 -> 51 |

This supports a bounded statement: both valid windows spend most producer
updates in the phase branch while only about 13.0--13.1% of the phase updates
are in-band.  It does not unwrap phase, establish a physical Hz conversion,
or prove cycle slips.  The source and reset tables remain valid background
evidence: both arms have stable generation/reset fields and usable WR link.

## 2. Actual Main control and publication path

The audited path is:

```text
reference/output tag pair
  -> spll_main.c: mpll_update()
  -> freq_error = dout_dt - dref_dt
  -> frequency branch (-boost * freq_error)
     or phase branch (wrapped tag/adder error)
  -> spll_common.c: pi_update()
       I_new = I_before + Ki*x
       anti-windup chooses I_after
       y = shifted PI result + bias, then clamps
  -> SPLL->DAC_MAIN = value(y) | DAC_SEL(dac_index)
  -> wr_softpll_ng.vhd dac_out_data/sel/load
  -> DE5a jtag top-level dac_dpll_data/load
  -> si5340a_controller_dco.v iDPLL_DATA/iDPLL_LOAD
  -> serialized DCO transaction
  -> dpll_applied_position after completed transaction
```

Concrete source anchors:

- `vendor/wrpc-sw/softpll/spll_main.c:983` computes the frequency error;
  `:1016-1025` selects frequency versus phase input; `:1055` calls the common
  PI; `:1057-1069` copies the completed Main trace; `:1071-1077` writes
  `SPLL->DAC_MAIN`.
- `vendor/wrpc-sw/softpll/spll_common.c:17-66` defines the exact
  `I_before -> I_new -> I_after -> y` and anti-windup behavior.
- `vendor/wrpc-sw/softpll/spll_main.c:1227-1242` records and publishes the
  F4L frame after the PI result is available.  Thus the Main branch, error,
  PI trace, and publication call originate in the same `mpll_update()`
  iteration; they are not assembled from separate host samples.
- `vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd:1301-1306`
  forwards HPLL and Main DAC data/load signals.
- `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:2067-2070` and the
  corresponding Master lines `1689-1692` connect the SoftPLL outputs to
  `dac_hpll_*` and `dac_dpll_*`; the SI controller instantiation consumes
  them at Slave `:1935-1938` and Master `:1557-1560`.
- `quartus/jtag_runtime_diag/si5340a_controller_dco.v:819-838` captures an
  HPLL absolute target and initializes the virtual applied position; the
  normal HPLL transaction is admitted at `:944-959` and advances applied
  position only after the serialized transaction completes at `:1035-1054`.

Important unit boundary: the Main PI output is an unsigned WR DAC code in the
SoftPLL register path; the current RTL position tracker has a separate
quantized physical-step coordinate.  A completed transaction counter or
`applied_position` therefore cannot be treated as proof that the physical
actuator has followed every PI target without a same-generation, same-window
correlation.  The source audit does not find that correlation in the current
F4K data.

## 3. Coherence and current lane-0 boundary

The F4L run on `20260919` repeatedly showed the lane-0 QSFP-A link gate:

```text
CORE_TM_LINK_UP=1
CORE_LINK_OK=1
WR_RX_READY=1
WR_TX_READY=1
PHY_LINK_USABLE=1
PSTAT_LINK=1
```

It stopped before a valid F4L frame because the startup gate
`HELPER_LOCKED_AND_MAIN_ENABLED` was not reached.  The accompanying Helper
state was `HELPER_LOCKED=0`, target/applied code `5`, and error saturated at
the reported rail.  Consequently this run is not evidence of a phase or
integrator failure.  The earlier lane-2 advice claiming an A-path link
failure is stale and conflicts with this newer lane-0 source/run; it is not
used to classify the current state.

The current source already has a coherent Main trace seqlock and the F4L
publication path.  The failed run therefore does not justify changing that
schema or the control path.  It does justify treating Helper startup as the
next boundary to diagnose.

## 4. Minimum proposed diff (not executed in this audit)

The next permissible change is a read-only Helper/Step4B startup observer
using the existing address/packing contract, preferably the existing
`scripts/jtag/read_step5_helper_pi_state_rail_audit.tcl` path.  It should
record, in one reader and without control writes:

- Helper raw/preclamp error, PI before/i_new/after, output and clamp side;
- target/applied position, bootstrap state, normal request/completion and
  DCO-step deltas;
- lock count and low/high/no-rail fractions;
- generation/reset stability and WR/link gate.

This is only a proposal.  It must not change PI/gain/threshold/timeout,
bootstrap, arbiter, mailbox, detector, DAC ordering, PHY, reset, RTL or SDB.
It must pass offline fixtures before another build/program/capture.  A valid
Helper diagnostic would then establish whether the current `output=5` is a
true low-rail saturation, a signed/packing error, or a target/applied service
failure.  Until that evidence exists, no control fix or Step5 PASS claim is
valid.

## 5. Conclusion

```text
SOURCE_AUDIT = COMPLETE
QSFP-A_LANE0_ROUTE = LINK_PASS
F4K_KP600_DIRECTION = NOT_SUPPORTED
F4L_PHASE_CONCLUSION = NOT_REACHED
NEXT_BOUNDARY = HELPER_STEP4B_STARTUP_OBSERVABILITY
STEP5_PASS = NO
MERGE_APPROVED = NO
```
