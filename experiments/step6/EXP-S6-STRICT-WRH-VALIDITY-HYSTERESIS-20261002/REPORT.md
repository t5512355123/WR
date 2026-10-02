# Strict WR validity — work in progress, NOT a 300 s PASS

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

## Revision 2: correction and verification pending

Scope revocation to the WRPC effective `WRH_TM_BOUNDARY_CLOCK` timing mode,
not configured role. Preserve local free-running Master/GM output, while a
configured Master that actually becomes Slave remains protected. Add actual-C
Master reset/init/uninitialized and GM-reset cases (35 total). Force-PPS cannot
bypass either a configured Slave or an effective boundary-clock Slave.

Keep /2 acquisition, /12 tracking, both PLL gains, all thresholds, RTL and port
mapping unchanged. Rebuild and pin new firmware before full compile/program;
revision-1 images are not substitutes. Next run must first prove Master validity
is preserved, then measure coherent offset + live Slave validity/lock health.

The passive Master query found Helper locked and phase tracker ready, but its
active T24P was the default 2389 ps with no edge-calibration scan record. This
is a measurement-path suspect, not a measured calibration error. Fine RX
timestamp linearization depends on the phase-transition calibration and the
rising/falling counter relationship; see the
[WR specification](https://white-rabbit.web.cern.ch/documents/WhiteRabbitSpec.v2.0.pdf).
Further phase/ahead-bit evidence is required before changing that calibration
or declaring a Ki/controller root cause. No advisor was contacted.
