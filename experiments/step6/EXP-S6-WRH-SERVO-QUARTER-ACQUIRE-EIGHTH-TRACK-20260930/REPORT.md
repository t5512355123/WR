# EXP-S6-WRH-SERVO-QUARTER-ACQUIRE-EIGHTH-TRACK-20260930 — Report

## Verdict

```text
BUILD_AND_PROGRAM                 = PASS
STEP1_AND_STEP5_LOCKS              = PASS during observed dashboard frames
SLAVE_GLOBAL_TIME_READINESS        = FAIL_NOT_VALID
STRICT_OFFSET_LT_60_PS             = 0/180 dashboard samples
STABLE_OFFSET_300S                 = NOT_ESTABLISHED
STEP6_STABLE_OFFSET                = NOT_PASS
```

The candidate did not meet the Step 6 objective. The 300-second accepted
offset gate was not entered because the Slave never established valid Global
Time during the bounded dashboard observation. No timing-closure requirement
was added or used for this verdict.

## Candidate and build/program

Laptop published candidate commit `7d0db202a8ab7dbe4c91358851dd61579b2d9bac`
on `feat/file_cleanup`. Relative to the quarter-acquisition reference, this
candidate changed only the `WRH_TRACK_PHASE` correction from `offset_ps / 4`
to `offset_ps / 8`; quarter-step acquisition, the original 2× fallback guard,
and the strict 60 ps threshold were retained.

Pain built both images from the frozen Step 6 source and programmed Slave
(`DE5 [1-11.2]`) then Master (`DE5 [1-11.1]`) successfully. The candidate SOF
SHA-256 values were:

```text
Slave  0defd92081c7a417b54b509d24dcdab7a86bdd018365ade220ff1e6bbc45b103
Master 978fb11fc255a723b395966b71fc4bd56ffae250694a78036e73ea57efe1e722
```

The runner restored the frozen source after the temporary patch and verified
the 3,219-entry source manifest and four-entry artifact manifest. Quartus
reported timing not closed; this is recorded but is not a functional gate.

## Read-only observations

The 10-second dashboard ran from `2026-09-30 18:20:07` through
`18:49:57 +08:00`, producing 180 paired display frames over 29 minutes
50 seconds. Both boards retained their Step 1 link gates in every frame. The
Slave's five Step 5 lock indicators were all high in all 180 frames. Master
Global Time was valid in all 180 frames, while Slave Step 6 remained
`WAITING` in all 180 frames because its time/PPS validity stayed low behind
the strict offset gate.

The Slave dashboard phase offset ranged from `-2687 ps` to `+4156 ps`; none
of the 180 samples met strict `abs(offset) < 60 ps`. The observed servo states
were `WAIT_OFFSET_STABLE` in 165 frames, `SYNC_PHASE` in 15, and
`TRACK_PHASE` in zero. Thus the candidate's only changed tracking correction
was never exercised in this run; the run cannot establish either benefit or
harm from the `/8` tracking change.

After the dashboard released JTAG, a planned read-only 15-second interleaved
capture was attempted. It stopped itself after five consecutive untrusted
samples (1.577 seconds observed): all five had valid low-level reads and all
five Step 5 locks, but `GLOBAL_TIME_VALID=0`, `SNAPSHOT_VALID=0`, and
`COHERENT=0` in every row. CKO values were `1921–1983 ps`; qualifying samples
were `0/5`. The analyzer classified the capture as incomplete and
`STEP6_POINTWISE_GATE_NOT_ESTABLISHED`. This is diagnostic evidence only,
not a smoke pass or a 300-second acceptance capture.

No reset change, link loss, or read/transport error was observed. The raw
capture and build/program records are listed in `raw/SHA256SUMS`; all 27
transferred raw files were checked against Pain by SHA-256.

## Interpretation and next experiment

The evidence shows a stable upstream link and Step 5 locks but no valid
Slave Global Time because the servo offset does not enter the required band.
The `/8` tracking change was not exercised because the controller remained
in `WAIT_OFFSET_STABLE` or `SYNC_PHASE`. Therefore, repeating a tracking-gain
change would not address the observed boundary.

The next controlled candidate should change only the acquisition correction
from `/4` to `/8`, keeping the tracking correction `/8`, the original 2×
fallback guard, the strict 60 ps threshold, and all other controls frozen.
This is a damping hypothesis, not a presumed fix. It must repeat the same
offline validation, laptop push, Pain build/program, read-only observation,
raw return/checksum, report, and push workflow. Only a complete 300-second
capture with every accepted sample strictly inside `(-60 ps, +60 ps)` and all
required gates valid can establish `STABLE_OFFSET_300S=PASS`.
