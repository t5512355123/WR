# Independent full cycle 1 — PASS, pair still pending

Root `/home/b10504072/04_WR`, compile source
`3b68162d8c13998478f970b9d6c1020b682cb4c6`.
Cycle began 2026-10-02 16:28:17 +08:00, ended 16:58:29 +08:00.
Both firmware builds passed the pinned MIF hashes. Both Quartus clean/full
compiles completed. Slave and Master programmers succeeded at 16:45:17
and 16:45:36, respectively. Timing was not closed and is not the gate.

| Board | Valid rows / total | Observed span | Maximum gap | Invalid rows |
|---|---:|---:|---:|---:|
| Master 1-11.1 | 1192/1192 | 302791 ms | 257 ms | 0 |
| Slave 1-11.2 | 1192/1192 | 302901 ms | 257 ms | 0 |

Both complete captures independently passed on Pain and Laptop. Boards were
sampled sequentially, not simultaneously or on every clock cycle. No capture
transport error or malformed row was reported; live time was monotonic.
Post-capture dashboard: both TIME_VALID/PPS_VALID=1; Master Helper=1;
Slave Helper/Main frequency/Main phase/Main lock/PSTAT all 1. These lock
snapshots are not a separately sampled 300-second lock qualification.

Master read-only PLL query after this run: mode 2, sequence ready, HL1,
HY=49760, ptracker enabled/ready, phase_ps=1708. This is a positive change
from the failed 34-code-account session's wait-helper/unready tracker, but
does not prove universal startup reliability or a precise plant calibration.
Slave UART query may be skipped by its persistent command-stage gate;
no skipped query is considered valid data.

Actual retained SOFs:
- Master: d593846302998a8601b244212dc32e283d9c2d0c3ff66bfa751e195774b12861
- Slave: a79633978091796bc4b78122bbf4df04c3704456c814d13acd2cde66f03cb412

Full records, images and input hashes are in
`raw/cycles/20261002T082817Z-cycle1/`; original compiler exports, programming,
readiness polls, raw capture and analyzer output are retained separately.
The input manifest contains 3110 files. The independent cycle auditor passed.
Download archive SHA256:
`621a3f5380ae3bd8b571a32b584a701c38ac22c8b5966e4164dfb3e3e35b3b2b`.

Overall status: **one of two required independent cycles passed**.
Do not promote the final milestone until the second complete cycle and pair
audit pass, publication/synchronization finish, and the previous operational
Step6 package is moved out so only one milestone remains.
