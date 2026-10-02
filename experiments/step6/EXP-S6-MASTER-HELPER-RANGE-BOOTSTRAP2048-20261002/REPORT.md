# Master Helper range candidate: diagnostic NOT PASS

Compiler source: `40c388010fff51991d958f50702f42b3d3437d61`.
Both firmware builds and full FPGA compilations succeeded. Program succeeded
Slave at 13:48:28, Master at 13:48:46 +08:00 on 2026-10-02.

Master SOF: `f4dd3b2357a23ed7ee4c36004b35a821a7d32b52eac3ec32f9cb9bb86568e690`.
Slave SOF: `e890caca31130ec930664c5e35e425b2244c72a3209d80133e19aa5f93806189`.
MIFs remain the preceding passive diagnostic's pinned binaries.

The explicit read-only PLL query completed with unchanged boot generation 1
and no CPU-reset change on both boards. Master remained wait-helper, HL=0,
HY=5, ptracker disabled/not ready, refcnt=0; it did NOT become a ready Master
Helper. Slave was seq=ready, HL=1, ML=1, ptracker ready, active T24P=7050 ps.
Master moved from the upper to the lower output rail. The proposed bootstrap
is therefore NOT a validated Helper-range repair. No additional tuning,
reprogramming, forced timing output or calibration write followed this trial.

At 13:51:00 +08:00 the dashboard nevertheless showed both exported TIME_VALID
and PPS_VALID bits 1, both links healthy, and all five Slave PLL lock fields 1.
Slave servo was SYNC_PHASE, offset +199 ps. This is not a 300-second pass and
does not prove Master fine timestamp correctness.

The Helper-recovery experiment is stopped as diagnostic NOT PASS. The next
action is a separate read-only observation of the SAME programmed images and
live session, named EXP-S6-TIME-VALID-300S-MASTER-BOOTSTRAP2048-20261002.
It tests the user's existing TIME_VALID-only acceptance criterion, not a
weakened Helper-recovery gate. Master Helper failure remains an explicit
unresolved caveat. Do not describe this result as a proven cause of the older
Slave startup regression or as a general WR timing-accuracy PASS.
