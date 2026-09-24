# Step 5 milestone reproduction plan

## Objective

Independently reproduce the historical Step 5 functional-lock milestone from
its frozen source, then clean-build, program both DE5a boards, and validate a
continuous observation window of at least 300 seconds.

Historical candidate:

- Experiment: `experiments/legacy/exp-step5-softpll-lock/EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/`
- Firmware/Quartus source commit: `26e138fdc0bfc8426704b397141d563cf4d580a2`
- Observer-only 300-second contract: `47d9a394e53eda31476c82de2a85ad82573494ed`

The historical report and raw capture remain the reference evidence. They are
not a substitute for this reproduction.

## Acceptance criteria

All items must be demonstrated on the newly rebuilt source snapshot:

1. Clean full compilation succeeds for Master and Slave using Quartus 17.0.0
   Build 595; intended QSF, SDC, firmware configuration, and MIF provenance
   are recorded.
2. The rebuilt SOFs are programmed to Master `DE5 [1-11.1]` and Slave
   `DE5 [1-11.2]` using the historical Step 5 order: Master, prescribed
   settling interval, then Slave.
3. Read-only preflight confirms both boards are in the expected live session
   with healthy link, trusted JTAG/Wishbone access, and no reset or terminal
   condition.
4. A single F4L observer session reaches at least 300,000 ms and has valid
   fresh captures throughout the required window.
5. Across the same continuous valid window, all four gates remain true:
   Helper/HPLL lock, Main frequency lock, Main phase lock, and PSTAT lock.
6. Link/reset/generation stability is maintained; raw capture, analysis,
   build/program identities, and checksums are retained.

Timing closure is recorded but is not a functional Step 5 gate. The known F4L
page-accounting caveat must be checked and reported; raw rows must not be
rewritten or dropped.

## Frozen-source boundaries

- The Step 5 candidate source is assembled from Git blobs at the exact
  historical source commit above.
- Historical QSF/top-level VHDL receive only repository-layout path
  relocations. A separately identified build wrapper pins the upstream
  firmware's embedded Git-description metadata to the frozen source commit;
  it does not modify firmware, RTL, or controller behavior.
- The observer Tcl and its matching offline test are taken from the later
  observer-only commit above; no firmware or hardware-control source is taken
  from that commit.
- Quartus build/program wrappers are copied byte-for-byte from the already
  validated Step 4 frozen package. The firmware wrapper is Step 5
  reproduction tooling used only to make the source identity independent of
  the enclosing Git checkout.
- The candidate source is not a formal milestone until this experiment passes
  every compile, program, and runtime criterion.

## Stop conditions

Stop before programming if source verification, offline tests, clean build, or
source/config/MIF identity checks fail. Stop observation and preserve the raw
reason if image identity is wrong, transport is untrusted, reset/generation
changes, link becomes unusable, the observer reports invalid/inconsistent
frames, or the runtime session terminates. Any failure remains Step 5
`NOT_PASS`; identify the first inactive boundary before a minimal retry.
