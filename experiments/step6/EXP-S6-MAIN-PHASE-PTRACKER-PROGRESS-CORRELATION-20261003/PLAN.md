# Post-WR Main phase / ptracker publication correlation

Baseline: fbef317928f4c7717e3a73f76343be449b6f8cb0, actual prior paired images
compiled31bfaeb5. Prior14 exact Master RX/Slave T4 matches showed subnanosecond
CKO steps with constant WR SETP, constant coarse return leg and opposite changes
in forward/return measurements. This does NOT prove physical jitter or a Ki fault.

Only passive C instrumentation changes. Keep /2 acquisition,/12 tracking,
strict60ps entry/inclusive120ps hold, all PI/Kp/Ki/lock parameters, timeout,
bootstrap, arbiter, reset, topology, FPGA RTL/constraints unchanged.
No calibration or advisors. Frozen milestones/protected Pain archive untouched.

At each actually accepted normal WR E2E update, store32 chronological records.
Each has full signed64 CKO and DMS seconds/scaled-ns, actual WR SETP before/after,
coherent latest completed Main update/sample/error/output/flags, independent
coherent phase-tracker publication generation/count/time/phase and final-bin
input/reference tags. No shared-memory ABI extension. No history is control input.
Main and tracker copies are post-WR, NOT packet-time/cross-group atomic. Tracker
ready/enabled flags describe the last private metadata publication, not an
independent current liveness measurement. Average remains512. Last-bin endpoint
tags must not be mislabeled as all512 samples or packet-specific metadata.

Source conversion: PHY8bit125MHz, divided DMTD enabled, HPLL_N14. Main raw phase
error conversion is16000/16384ps per unit (phase branch only); phase_ld threshold
1200 is1171.875ps, much wider than the requested120ps hold. Do not lower this
threshold to manufacture better lock. Tracker uses its existing normalized,
doubled-modulo8ns conversion. Keep raw values for independent auditing.

Tests: actual native pointer-tracker512-average behavior/publication/invalid
seqlock/reset and history ring/frozen pages/signed64/FIFO; existing native TS4 and
strict/fixed control regressions. Python and actual Tcl malformed/missing/
duplicate/frozen-page/generation/health guards. Pages two36-word rows + echo/
CRLF/prompt MUST remain below actual1024-byte VUART FIFO.

Workflow: Laptop edit/offline test/push; Pain exact pull/native regressions and
role firmware builds; return actual MIF hashes to Laptop, commit pins/push/Pain
exact pull; root full compile/program once Slave then Master. No power cycle.
20s strict smoke; one bounded120s startup if needed; only if link/five locks/
Master validity good run ONE immutable history capture with page0 smoke and
maximum240s actual time. Stop on transport, image/source hash mismatch, bank
conflict, reset/init generation or upstream health change; no automatic retry.

Data gate:32 complete internally coherent chronological accepted WR records,
31 consecutive UCNT differences, same SPLL/Main/tracker generations, validated
bracketed Master/Slave health. Report Main sample_n and tracker publication
progress/age, phase error/DAC range, and CKO changes with/without WR action.
Stationary Main/publication counts are findings, not silently dropped rows.
No data-only gate is a Step6 PASS. Fine-phase associations do NOT establish cause.

Strict postflight20s; extend to300s only if it establishes usable fresh entry and
at least10s uninterrupted strict qualified span without reset/transport issue.
Otherwise stop this round, return exact products/raw/checksums to Laptop,
write REPORT, push and ff sync Pain. Do not auto-adjust gains from a correlation.
Goal remains NOT_ESTABLISHED until actual audited strict300s is obtained.
