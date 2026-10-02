# Master step-account repeatability candidate

Baseline publication ae487031; FPGA compile baseline 40c38801.
The identical qualified SOFs were reprogrammed from the frozen checkout at
15:32 on 2026-10-02. At 16:22 Slave had all five PLL locks but TIME_VALID=0,
WAIT_OFFSET_STABLE, offset -1941 ps. Master Helper=0.
Passive measurements: Master single-word output ranged 5..65531 and frequency
error -90..97 over ten reads, whereas Slave output 47022..47432 and frequency
error -7..13. These separately sampled fields are not a coherent causal frame.
Master PLL query confirmed wait-helper, ptracker enabled but not ready;
generation 1 and reset unchanged. Slave query was skipped by its shell-idle
gate (command_stage=58), not treated as a successful measurement.

Only production variable: Master HPLL_TRACKER_CODE_PER_PHYSICAL_STEP 34 -> 64.
Slave already uses 64; Master bootstrap2048/reverse, firmware PI, threshold,
servo acquire/track /2+/12, timeout, PHY and reset are unchanged.
This is a hypothesis test, not a proved physical plant calibration or root cause.

Laptop edit/test/push -> Pain pull -> fresh build_current -> compile_current
-> program_current -> read-only dashboard/helper -> actual TIME_VALID capture.
Do not force TIME_VALID or loosen its predicates. User final requirement is
TWO consecutive independent root build+compile+program runs, each yielding
both boards' sampled TIME_VALID over >=300 seconds. Any failed cycle breaks
that consecutive count. Keep source fixed for the two qualifying cycles.

Snapshot dashboard at entry and exit; verifier logs every readiness poll,
then 303 seconds per board with <=1 second gaps and >=301 valid fresh rows.
Stop a capture on transport errors; reset/generation changes invalidate it.
If Master still rails/unlocked or acquisition fails, retain the evidence and
continue diagnosis rather than declaring the candidate passed.
After two actual successful cycles only, replace Step6 packaging with ONE
current milestone and move the old package outside that milestone directory
recoverably. Never access the protected archive.
