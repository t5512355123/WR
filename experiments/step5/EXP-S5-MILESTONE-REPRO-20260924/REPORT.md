# EXP-S5-MILESTONE-REPRO-20260924

## Verdict

STEP5_MILESTONE_REPRODUCTION = PASS
STEP5_FUNCTIONAL_FOUR_LOCKS_300S = PASS
MASTER_CLEAN_BUILD = PASS
SLAVE_CLEAN_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
CONTINUOUS_VALID_LOCK_WINDOW = 300291 ms
TIMING_CLOSED = NO (not a Step 5 functional gate)

This is an independent reproduction from the frozen Step 5 source, not a
promotion based only on the earlier historical report. The rebuilt Master
and Slave images were programmed to the two DE5a boards and then observed in
one read-only F4L session.

## Source and build provenance

- Historical firmware and Quartus source: 26e138fdc0bfc8426704b397141d563cf4d580a2.
- Read-only observer contract overlay: 47d9a394e53eda31476c82de2a85ad82573494ed.
- Pain checkout used for this reproduction: commit 6f1096d7f957beeb2f0c065f7219960bae47bb61 on feat/file_cleanup.
- The frozen package verifier confirmed 3,190 historical Git blobs and 7 reproduction wrappers. The promoted source snapshot independently checked 3,203 source-index files.
- Quartus Prime Standard 17.0.0 Build 595; RISC-V toolchain 9.3.0.
- The candidate package and build/program tooling are under source/. The promoted frozen source is artifacts/milestones/step5_softpll_lock/source/.

| Board | QSF SHA-256 | SDC SHA-256 | Rebuilt MIF SHA-256 | Rebuilt SOF SHA-256 | Build |
|---|---|---|---|---|---|
| Master | fc2f861ad6cf3a2f660ac66184fe054415515ab4006e578542ddce59ab026530 | 921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b | 79c66610be6339be9651a8ab0baa633c2a04a91d89895502aa401a99c88b03b7 | f72501285cef7f6a892b9334e7de93a5a86f8aff7311417f577c14acfd213a30 | PASS |
| Slave | d074d47954f13d539d5477615a8a03752622b2b115dfa6684bc51169a3d7275d | 921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b | eaa1596fce3d3b1df93557be7dee25967b3720e7bd247a7b188e06b7b1ea6860 | d4efd77c91ddc96cd6444e3f47cadf529a4f19da4c9f6b0876ce00557d63ca20 | PASS |

Both build metadata files record full compilation success and successful
Fitter status. The embedded firmware source description was pinned to
master-diagnostic-baseline-20260817-1175-g26e138fd. The regenerated MIF hashes
differ from the old historical MIF hashes because the upstream revision
object embeds build date/time metadata; the source identity, firmware
configuration, and control sources were verified. No historical hashes are
represented as matching when they do not.

The first Master compile, made before the metadata wrapper was corrected,
contained the enclosing checkout version and was not programmed. Its logs and
generated firmware are preserved in raw/build/attempt-unpinned/.

## Programming

| Board | Cable | Programmer result | Quartus checksum |
|---|---|---|---|
| Master | DE5 [1-11.1] | One device configured; 0 errors, 0 warnings | 0x30AFA169 |
| Slave | DE5 [1-11.2] | One device configured; 0 errors, 0 warnings | 0x30B5B27A |

Historical Step 5 order was preserved: Master first, then Slave after the
settling interval. The actual Master completion-to-Slave start gap was 128 s.
The boards then settled for more than 120 s before preflight. The direct
Master wrapper launch initially returned permission denied without invoking
Quartus; the successful operation used the same wrapper through bash. Both
attempts are preserved in raw/program/.

## Read-only preflight

Both boards reported healthy SI configuration, CPU reset deasserted, WR link
up, RX/TX ready, and active PTP traffic. Master Step 1, Step 2, and Step 4A
passed. Slave Step 1 and Step 2 passed. The runtime dashboard repeated the
same WR signal sideband read-inconsistent Step 3 classification present in
the historical accepted capture: the RX/TX sideband counters did not expose
the expected LOCK and SLAVE_PRESENT tokens at that sample. The preflight
nevertheless confirmed the parent-WR state, calibration, lock-enable path,
healthy link, and trusted JTAG/Wishbone transport.

Transport totals were 353 requests, 353 preload/commit pairs, 1,765 probe
reads, and zero timeout, invalid, stale, unstable, or cross-contaminated
transactions. The sideband classification matches the historical report
and is not used as a substitute for the continuous Step 5 lock measurement.

## Continuous F4L runtime validation

One single-reader, read-only capture reached the requested 300,000 ms target
and ended at 301,253 ms with TARGET_REACHED and STOP_REASON=NONE. It recorded
317 Slave cycles, 317 valid primary Main F4L frames, and 80 Master status
samples. There was no reset, link loss, terminal state, or SoftPLL delock.

| Acceptance gate | Result | Evidence |
|---|---|---|
| Helper/HPLL lock | PASS, 317/317 cycles | HELPER_LOCKED=1 and lock count at threshold for every cycle |
| Main frequency lock | PASS, 317/317 frames | BRANCH_ID=2 and FREQ_LOCK_AFTER set in every Main frame |
| Main phase lock | PASS, 317/317 frames | PHASE_LOCK_BEFORE, PHASE_LOCK_AFTER, PHASE_CALLED, and PHASE_IN_BAND set; PHASE_OUT_OF_BAND clear |
| PSTAT lock | PASS, 317/317 cycles | PSTAT_LOCKED=1 in every Slave WR-core sample |
| Fresh-data coverage | PASS | 155 unique observations spanning 300,291 ms; 31 valid 10-second bins |
| Link/reset/runtime stability | PASS | PHY_LINK_USABLE=1, RESET_CHANGED=0, BOOT_GENERATION=1, TERMINAL=0, and SPLL_DELOCK_COUNT=0 in all 317 cycles |

The Main diagnostic flags were 383 decimal (0x17F) on all 317 frames. Per
the frozen source header, this means valid; frequency lock before/after;
phase lock before/after; phase detector called; phase in-band; and DAC write.
The phase-out-of-band bit was clear. The analysis retained the phase-branch
and lock evidence directly from the coherent Main F4L frames.

## Preserved F4L accounting caveat

The strict offline F4L parser found 309 schema-consistent frames and 8
HISTOGRAM_PHASE_COUNT_MISMATCH rows. These are four repeated page-2 source
epochs, each observed twice, at cycles 19/20, 109/110, 241/242, and 301/302.
All eight rows still contain FLAGS=383 and the same source epoch within each
pair. They remain unmodified in the raw log and analysis JSON; none were
silently dropped. The 309 schema-consistent fresh rows cover the full
300,291 ms span and all 31 ten-second bins.

The strict F4L diagnostic JSON therefore reports FRAME_SCHEMA_INVALID and
diagnostic_pass=false for the histogram accounting issue. That diagnostic
verdict is not treated as the Step 5 verdict: the four functional lock gates
are independently counted from the raw per-cycle/per-frame records, and the
valid fresh coverage exceeds 300 seconds. The auxiliary Main schedule fields
remain unavailable in this source/observer combination, as they also were in
the historical accepted capture; they are not used to infer Main lock.

## Timing and limitations

Timing closure is NO and is not a functional Step 5 gate. Master worst setup
slack was -0.289 ns and Slave worst setup slack was -0.361 ns; the values are
reported, not hidden or reclassified. This milestone proves the four
functional locks for the required continuous interval only. It does not
claim timing closure, Step 6 global-time agreement, or physical SMA edge-skew
validation.

## Evidence

- Raw build, firmware, and build metadata: raw/build/rebuilt/.
- Programmer attempts and successful programming: raw/program/.
- Read-only preflight and full F4L capture: raw/observe/.
- Machine-readable paged-frame analysis: analysis/f4l_300s_analysis.json.
- Per-gate raw audit: analysis/lock-audit.md.
- The frozen source package and its source checksum manifest: source/.
