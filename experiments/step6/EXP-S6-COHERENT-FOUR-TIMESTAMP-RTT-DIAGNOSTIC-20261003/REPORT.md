# Coherent T1..T4/RTT — candidate prepared, hardware pending

Baseline4687d6b6. Normal /2 acquisition + /12 tracking restored by disabling
the opt-in fixed-SETP diagnostic. Strict full64 acquisition/revocation unchanged.
Only passive producer RAM/paging and a read-only observer added. No Ki/PI,
threshold, calibration, timeout, RTL, SDC or frozen-milestone change.

Laptop TS4 decoder/native-source contracts and actual Tcl observer tests:
14tests OK after repairs; strict observer/300s tests10OK; VUART tests25OK;
WR strict/fixed source tests6OK with1 native-compiler skip.
Initial failed fixtures are retained: a Main-lock fault was incorrectly applied
to Master rather than Slave; mock page array conflicted with observer scalar.
The whole-observer test also found a real Tcl64-bit STATUS output narrowing:
fixed by formatting both32-bit halves, not by removing the high-bit gate.
Actual full observer now verifies same-snapshot smoke/extension and immediately
stops on changed math or reset identity. Data-only PASS cannot become Step6 PASS.

Fresh Pain native C, firmware, full compile/program and actual observation
are still pending. Existing output belongs to the preceding fixed-SETP image.
No current strict300s PASS claim. Next steps must follow PLAN.md and the
Laptop→GitHub→Pain→raw back to Laptop→report/push workflow.
