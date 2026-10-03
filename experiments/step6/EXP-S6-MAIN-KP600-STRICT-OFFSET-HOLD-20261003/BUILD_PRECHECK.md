# Actual firmware precheck

Source: c67f3a7ad04f358d4c9b65035482aed7148b4130, Laptop-pushed and
Pain-pulled before actual role builds. This pin update is metadata only.

Both role firmware builds succeeded. Native scope (4 cases), actual phase
history, ptracker 512-average publication, TS4 recorder, WR servo (35 cases),
and fixed-SETP regression tests passed. Laptop history/strict tests also passed.

| Actual product | SHA256 |
| --- | --- |
| Master MIF, byte-identical to baseline | 8913615c374fdb88a5c107fe7422f5f5c30d4a6aba7429ed2c502bf83a9d4ea5 |
| Slave MIF, Kp600 | 006d798a02699167337c6a417f14fd898b0ffad872e35a2c2e9250fbededd4e5 |
| Slave binary, Kp600 | 20e4bd211e6cfc695054840f813010aeab30b9ce863c57a365ad4f8238b0ebbd |
| Saved baseline Slave binary, Kp300 | 22bc17737a939b76fe4db0ea932da4e17d07babf278c89a5e9ff32af8421f72a |

Actual `cmp -l` found only two changed bytes (one-based offset; octal values):

```text
2435 300 200
2436  22  45
```

Actual RV32 `mpll_init` disassembly at 0x980 is `25800713 li a4,600`,
followed by `sw a4,12(a0)` (Main PI Kp). The old instruction is `12c00713`
(300). The rest of the binary is identical. Master is unchanged.

This proves build isolation, not hardware performance. Full Quartus compile,
one programming pair, and actual bounded observation remain required.
No Step6/300s PASS is claimed by these prechecks. See PLAN for the audited
historical Kp600 result and the unchanged strict 60/120ps acceptance gate.
