# First-entry fixed setpoint — prepared, hardware pending

Baseline a1694e85, source1c54bb78. No gain/threshold/RTL/SDC change.
Laptop30 Python/Tcl tests passed,2 skipped (no native compiler).
After Laptop push and Pain exact ff pull:
- Actual baseline entire-servo C with UBSan:35cases PASS, Master preserved.
- Actual fixed diagnostic C with UBSan:100 in-band updates,8 full64/busy
  revocations, IPC/init/modulo/reset/coarse/loss guards PASS.
- Both fresh role firmware builds succeeded. Actual MIF pins:
  Master1777c0d61dc12a5c639e9e8502294b56d7c9bef905b860f0a84c6d90b85aa91d,
  Slave406a7cabddd30417aba1556eaf7bb5c2f7d741809eb30bc60daf1a147589b48a.

Full FPGA compilation/program/diagnostic not yet performed.
Strict300s goal remains NOT_ESTABLISHED. No milestone/archive changes.
