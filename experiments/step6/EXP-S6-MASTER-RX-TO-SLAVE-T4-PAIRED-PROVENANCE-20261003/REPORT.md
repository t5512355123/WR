# Paired Master RX→Slave T4 — candidate prepared, hardware pending

Baseline3dd3604d. This round changes only root observer/analysis/tests and
experiment metadata; firmware/RTL/PI/Ki/threshold/calibration inputs are
unchanged. Full production diff against baseline is empty. Actual MIF pins
remain4695471f…1a6 /85703796…d8d. Root retained output still belongs to the
preceding completed TS4 experiment until the new full compile/export finishes.

The previous round showed action-free~8.2ns return-leg/~4.2ns CKO jumps.
Source msg_pack_delay_resp encodes only `scaled_nsecs &0xffff` in its WR
correction field (fractionalns). Pair the Master's actual linearized RX with
Slave accepted raw T4 next; do not guess a new Ki or copy Slave calibration.

No new firmware RAM/API is needed: send existing Slave TS4page0 and Master
RXTSpage0 before draining either. Existing complete16/32 frozen histories
are retained. Current MAC queries, source-proven EUI64 construction, domain/
port/DelayResp sequence and exact full64 time equality identify overlap.
Host request intervals are not cross-board atomicity. Every unpaired update
stays unpaired. Gates8paired accepted updates/4consecutive differences,
360s actual deadline and reset/health/math stops are fixed before hardware.

Laptop tests:11paired tests passed, including actual whole Tcl observer,
two requests before any page read, no second page0, stopped bad RX math and
changed reset identity, high TAI, exact time/source/domain/port matching,
nonoverlap rejection and1024-byte FIFO bounds. Existing14TS4 tests passed.
Initial whole-observer fixture failed because Tcl numerically converted the
mock MAC suffix"01" to"1". Fixed only fixture formatting, and strengthened
negative tests to assert their intended failure reasons (not a generic error).
Initial/repaired logs retained; no production gate relaxed. Native tests also
now reserve64bytes for echo/CRLF/prompt within the real1024-byte FIFO.
Exact partial-overlap boundary also tested:8 pairs accepted/7 pairs rejected.
Existing10 strict-offset/reader tests passed, preserving60/120/300s gates.

Next: Laptop commit/push -> Pain exact pull/native regressions -> root
build/compile/program once -> bounded health/startup -> single paired snapshot
-> strict postflight -> raw/checksum return -> Laptop report/push -> Pain sync.
No current hardware result or strict300s PASS claimed. Frozen milestones and
protected Pain archive unchanged. No advisors or power-cycle requested.
