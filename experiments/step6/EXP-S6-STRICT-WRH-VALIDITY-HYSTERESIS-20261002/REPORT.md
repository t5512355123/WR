# Strict WR validity — revision 2 complete, NOT a 300 s PASS

The full goal remains a fresh <60 ps acquisition followed by at least 300 s
TIME_VALID inside inclusive +/-120 ps, with validity revoked on excursions.
Frozen Step6 and the protected Pain archive are unchanged.

## Baseline evidence

`4c53b713` uses a one-shot enable with no corresponding >120 ps output revoke.
A 120 s precondition trace had 117 UCNT-bracketed unique updates, CKO
-2432..+4050 ps, only 2 updates within +/-120 ps, and 113 pointwise VALID
updates outside that band. 70 adjacent pairs had >120 ps CKO changes with
unchanged SETP. Several RTT/DMS steps were near 8000/4000 ps. These are
counter-bracketed diagnostic correlations, not publication-coherent causality.
They do not justify blaming only the WR correction divisor/"Ki"; SoftPLL
continues operating even while the WR phase setpoint is unchanged.

## Revision 1: completed build/program, FAIL, superseded

Compile source: `f2362d0553ee4482712f5e0187418242644e5fdf`.
The actual C sanitizer test passed its then-existing 31 Slave cases. Both
firmware builds matched pinned MIFs, both full FPGA compiles succeeded, and
Slave -> Master programming succeeded on 2026-10-02 (Master end 23:16:29).

| Role | Actual SOF SHA256 |
|---|---|
| Master | `4bf417845df16718cfa8c3922bf6badef8e9316ac77492b7753c5cc185c81b1b` |
| Slave | `81f5a9be3869189da9a87f3e26c84c1941b57166ab4f725bd61d6cff2bb95dbc` |

The new short-frame observer obtained 54/54 trustworthy samples with unchanged
reset signatures. CKO was +2072..+6010 ps; no <60 ps entry and no qualified
dwell occurred. Link and all Slave lock gates were 1, but TIME_VALID was 0.
Unlike the baseline's latched VALID, that rejection is correct for these offsets.

A subsequent dashboard at 23:20:40 found Master TIME_VALID=0 too. Source audit
identified a revision-1 regression: WR hooks call the common servo init/reset
on a free-running Master, so unconditional revocation also cleared Master
local PPS/time output. This is an introduced role-scoping bug, not a physical
link regression or evidence that the old source was unstable in the same way.
Revision 1 is NOT qualified and must not become a milestone.

## Revision 2: fresh build/program and 660 s observation complete

Scope revocation to the WRPC effective `WRH_TM_BOUNDARY_CLOCK` timing mode,
not configured role. Preserve local free-running Master/GM output, while a
configured Master that actually becomes Slave remains protected. Add actual-C
Master reset/init/uninitialized and GM-reset cases (35 total). Force-PPS cannot
bypass either a configured Slave or an effective boundary-clock Slave.

Keep /2 acquisition, /12 tracking, both PLL gains, all thresholds, RTL and port
mapping unchanged. Actual-C sanitizer execution passed 35 cases; pinned fresh
MIFs were d55af9716af96805f493623cd6a962a437feaf99fc382be071412bf9fca645a6
(Master) and 49d8fc035afeb84b5c734da03ee61926095d788a8a305c97963b87d255757e7c
(Slave). Both full compiles from `4ba9df5935fc0a6afae2c7bd29603f190936e627`
succeeded at 23:52:18, followed by Slave -> Master programming at 23:53:55.
No timing-closure claim is made.

| Role | Revision-2 actual SOF SHA256 |
|---|---|
| Master | `4f83d5f94758ef2533d628ae13cd39d1642569cf5e2b04c16b43dc84062be8d6` |
| Slave | `887deeb65986399f83dd1b3da3022e684c11d8bcc645429212d3ac4847e09781` |

The 23:54:53 dashboard proves Master TIME_VALID/PPS_VALID restored, Helper
locked, and both links usable. All five Slave PLL lock signals were 1, but
its current WR time had not qualified. A subsequent 15 s strict smoke obtained
41/41 trustworthy rows with CKO -2906..+2580 ps, no strict entry, no observed
VALID-outside-120 row, and no reset/transport errors. Master live health is now
interleaved in the same reader (separate, non-atomic board reads); freshness,
Master validity and reset identity are required for a qualifying Slave window.

The 660 s bounded observation completed in
`raw/observe/20261002T155811Z-strict-offset-validity.log`. Laptop independently
reran the same analyzer and obtained the same result as Pain:

- Verdict: **NOT_ESTABLISHED**, not Step6 strict PASS.
- 1882 Slave rows; 1849 trusted, 33 rejected by the freshness/coherence/
  contiguous-update guards. Rejected rows cannot qualify a hold interval.
- Trusted CKO range: -3158..+3839 ps; no raw row was strictly inside +/-60 ps.
- TIME_VALID=0 in all 1882 Slave rows; no observed VALID-outside-120 row.
- Trusted state counts: WAIT_OFFSET_STABLE (5) = 1668, SYNC_PHASE (3) = 181.
- Longest qualified span = 0 ms; no fresh valid TRACK entry.
- 496 interleaved Master health rows all had READS_VALID=1, TIME_VALID=1,
  LINK_GATE=1 and RESET_CHANGED=0. These are separately sampled, not atomic
  cross-board measurements. Observer transport/reset errors = none.

Result JSON is `analysis/20261002T155811Z-strict-offset-300s.json`.
Revision-2 products are retained in the main root's `build/` and `output/`;
frozen packages remain unchanged. Safe validity rejection and the Master
role fix worked in this session, but neither is a fine-offset convergence PASS.

The passive query now recognizes the F4L owner at 0x00100B5C rather than
mistaking its 0x00100BA0 payload for an idle-shell flag. It still requires live
shell markers, generation/reset agreement and a quiet input FIFO, and sends
only `pll stat` / `pll gps 0`. Both boards responded without a reset change.
Slave T24P=7050 ps, measured R=7000/F=3100; Master T24P=2389 ps, no scan record.
This difference is NOT proof that Master's value is wrong or permission to copy
Slave calibration into Master.

The passive Master query found Helper locked and phase tracker ready, but its
active T24P was the default 2389 ps with no edge-calibration scan record. This
is a measurement-path suspect, not a measured calibration error. Fine RX
timestamp linearization depends on the phase-transition calibration and the
rising/falling counter relationship; see the
[WR specification](https://white-rabbit.web.cern.ch/documents/WhiteRabbitSpec.v2.0.pdf).
Further phase/ahead-bit evidence is required before changing that calibration
or declaring a Ki/controller root cause. No advisor was contacted.

## Next direction

Do not repeat a blind gain sweep. Add bounded passive packet-specific RX
timestamp records to the current root only: original nsec/ahead/phase, active
T24P, linearized seconds/nsec/phase and PTP source identity/message/sequence.
Test the recorder and query path offline; preserve the strict validity fix,
all PLL/WR gains, thresholds, RTL and existing milestone. This can distinguish
an RX selection discontinuity from smooth phase motion, but is not by itself
proof of causal control failure or physical timestamp accuracy.
