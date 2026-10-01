# EXP-S6-TIME-VALID-STABLE-300S-20261001

## Objective

Reproduce at least 300 seconds of sampled Slave Global-Time validity using the
previously validated frozen Step 6 source. For every accepted sample, both the
PPS-latched snapshot and exported status must report `TIME_VALID=1`, and the
snapshot must be stable and valid. `PPS_VALID`, phase offset, Step 1/link,
SoftPLL locks, and reset state are recorded for context but are not gates for
this revised objective.

The current fixed-SETP diagnostic image is not the baseline for this run: its
recent short sample had valid Step 1 and Step 5 lock bits, but the Slave had no
valid Global-Time snapshot. The exact frozen Step 6 source previously produced
valid Global Time on both boards and a 300-second Slave time series. This run
rebuilds that frozen source and checks the known image hashes before touching
the boards.

## Frozen source and images

- Frozen source origin: `74dc28862653d306e0450cf437ba6d3a230d979d`.
- Source tree: `artifacts/milestones/step6_global_time/source/`.
- Quartus: Prime Standard 17.0.0 Build 595.
- Expected Master SOF SHA-256: `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.
- Expected Slave SOF SHA-256: `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- Build/program order: Slave, then Master.
- No timing/servo/PI/gain/threshold/timeout/PHY/RTL behavior changes.
- Never access `/home/b10504072/04_WR_archive_step6_pass/`.

## Procedure

1. Laptop tests and pushes this observer, analyzer, dashboard-gate update, and
   experiment plan to `feat/file_cleanup`.
2. Pain fast-forwards `/home/b10504072/04_WR` to that branch tip.
3. Verify the frozen source manifest and compile Master and Slave from the
   frozen source tree. Record the freshly rebuilt SOF hashes. The firmware
   embeds a `git describe` string from the outer checkout, so rebuilt SOF hashes
   can differ even when the frozen source is unchanged; do not treat that
   difference as hardware evidence.
4. Independently verify the checked-in, previously validated milestone files
   using `artifacts/milestones/step6_global_time/SHA256SUMS` and the exact
   Master/Slave hashes listed above. Program those exact milestone SOFs (not
   the newly rebuilt files), Slave first and then Master. Save separate build,
   artifact-verification, and programming logs. Any canonical artifact hash
   mismatch stops before programming.
5. Run the read-only Global-Time observer on Slave `1-11.2` for 302 seconds,
   requested cadence 250 ms. Do not run another JTAG reader concurrently.
6. Analyze the raw capture on Laptop; add the checksummed raw log, JSON
   analysis, and final verdict to this experiment folder, then push the report.

## Acceptance and stop conditions

`PASS_TIME_VALID_300S` requires all of the following:

- At least 300,000 ms between the first and last timestamped samples and at
  least 300,000 ms reported capture duration.
- At least 301 samples, with no adjacent sample gap above 1,000 ms.
- Every sampled row has a stable, valid snapshot, snapshot and exported
  `TIME_VALID=1`, and a parseable TAI/cycle payload.
- The sampled live TAI/cycle counter advances monotonically across the capture;
  PPS validity, Step 1/link readiness, other lock states, and reset state are
  reported as diagnostics but do not veto this objective.
- No observer error and a normal completion record.

Any sampled `TIME_VALID` loss fails this attempt in the final analyzer;
preserve all rows and identify the first failing sample. A canonical milestone
SOF hash mismatch, missing cable, concurrent reader, or transport/Tcl error
stops before continuing. A freshly rebuilt SOF hash mismatch is recorded but
does not stop this controlled run because the previously validated canonical
milestone artifacts are the programming inputs. If the capture does not pass,
do not declare Step 6 complete or tune unrelated controls; use the saved
servo/PTP evidence to set the next experiment.

The observer is read-only. A sampled 250-ms cadence does not prove sub-sample
behavior between reads; report the maximum measured gap and do not describe it
as cycle-by-cycle monitoring.
