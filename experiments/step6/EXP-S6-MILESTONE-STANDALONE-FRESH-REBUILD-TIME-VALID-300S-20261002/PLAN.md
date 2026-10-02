# Fresh standalone Step6 milestone reproduction

Request: rebuild firmware, fully compile both FPGA projects, program and verify
the newly frozen milestone, not reuse main-root build products.

Frozen archive SHA256:
`54950148ab09c0a5367f9779e59eaf993fcbef66877b8e7e461d642f8c7e2598`.
Run only in
`/home/b10504072/04_WR/artifacts/milestones/step6_global_time/source/`.
The original archive and root-level qualified SOF aliases stay unchanged;
only the extracted source's generated build/output/cache/evidence may change.
No production source, control parameters or validity predicates change.

Use the packaged `run_step6_reproduction_cycle.sh cycle1` driver: fresh
`build_current.sh` → `compile_current.sh` (full clean two-board compiles) →
`program_current.sh` (Slave then Master) → dashboard → bounded acquisition →
`verify_time_valid_300s.sh` → dashboard. The driver's cycle1 label identifies
this standalone run, not an additional main-root qualification.

Acceptance: independently capture Master and Slave STATUS_TIME_VALID=1 on
every trusted sample for ≥300000 ms sample span, ≥301 samples, max gap ≤1000 ms,
complete correctly identified board records and no transport errors. The
303000 ms capture request at 250 ms interval is sequential per board.
Readiness is bounded to 1800 s; invalid capture is FAIL, not hidden or retried
automatically. Stop on build/compile/program error or conflicting JTAG reader.

Record actual standalone Git identity, all 3110 input hashes, fresh MIF/SOF
hashes, compile logs, program results, pre/post dashboards, raw capture and
independent verdict. Verify archive/alias identities remain unchanged. Copy
new evidence back to this main-root experiment directory on Laptop and publish
the report. Do not overwrite the previously qualified root output or archive.
Do not access the protected server archive, power-cycle or consult advisors.

PASS is sampled TIME_VALID only: not physical timing accuracy, equal absolute
time labels, offset <60 ps, timing closure or universal startup reliability.
