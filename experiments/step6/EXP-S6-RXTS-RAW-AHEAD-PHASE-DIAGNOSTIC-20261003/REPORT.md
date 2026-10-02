# RXTS packet diagnosis — work in progress, not a strict Step6 PASS

Baseline and rationale: see PLAN.md. The preceding strict660s result was
NOT_ESTABLISHED; current control/validity behavior is unchanged.

Laptop source `fb3a5bce`, test repairs `8778537b`/`62c82492`, pushed before
Pain pull. A native test initially failed because the firmware include path
shadowed the host assert.h; fixed by quote-only include paths, before build
or programming. Original failed log is retained rather than suppressed.

Offline outcomes:

- Laptop 48 tests: OK, one skip (no native C compiler); following addition
  includes a production-function comparison test, skipped on Laptop.
- Pain actual recorder C with UBSan: PASS, immutable input, filtering,
  field packing, ring overwrite, frozen pages, bounded response size.
- Pain actual entire WR servo C with UBSan: 35 cases PASS.
- Pain RXTS tests: 10 OK, four skips (Tk unavailable). Actual unchanged C
  linearizer compared to Python decoder for96000 combinations: three T24P
  values, both ahead states, all8000 phases and two raw nanosecond positions.
- Fresh firmware source `62c82492a72d08dbf9d019110f358d1e511759ce` succeeded.
  Master MIF: `3f18256245691266d02536efd8a85848bf7b6aad2651fe81f644fb8c6e44eaba`;
  Slave MIF: `fb2837b211b488f44a017ccf9ac6f7f3eddfbdf51daa0ee20fcc13b5877b9e2c`.
  text+data+bss:147172 /147132 bytes within196608-byte memory.

Full FPGA compile/program and actual timestamp capture are pending. Retained
root output currently still belongs to strict revision2, not this new code.
No timestamp selection/calibration/gain/RTL changes; no advisor messages.
