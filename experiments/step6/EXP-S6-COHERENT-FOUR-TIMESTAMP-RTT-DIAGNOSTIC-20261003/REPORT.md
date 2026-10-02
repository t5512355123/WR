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

After Laptop source push4bec6e32 and Pain exact pull, actual recorder C with
UBSan passed immutable-field packing, filtering, pre/post action boundary,
overwrite, frozen pages and full signed64 tests. Actual strict entire-servo C
passed35cases; fixed diagnostic regression passed100in-band updates and8full64
revocations. Pain TS4 Python14tests OK,5Tk skips (executed on Laptop).
Both fresh role firmware builds succeeded; actual text+data+bss159844/159804
bytes within196608-byte memory. Measured MIF SHA256:

- Master4695471fd7f6c1ff1fd845574406741474a36deb59e6c8a748c416569561c1a6
- Slave857037966187a1a551be92a67fa05b815e3e1ff096d863888897896dabc43d8d

Pins returned to Laptop for this update/push before Pain build_current rerun.
Full FPGA compile/program and actual observation still pending.
Existing output belongs to the preceding fixed-SETP image.
No current strict300s PASS claim. Next steps must follow PLAN.md and the
Laptop→GitHub→Pain→raw back to Laptop→report/push workflow.
