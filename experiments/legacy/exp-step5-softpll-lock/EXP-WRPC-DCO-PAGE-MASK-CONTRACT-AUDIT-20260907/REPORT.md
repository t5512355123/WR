# DCO page/mask contract audit — 2026-09-07

## Result

Baseline defect reproduced with the production I2C bit engine and an SCL/SDA
page-aware slave model. This is simulation evidence, not physical clock isolation
or Step5 PASS. No FPGA programming was performed in this prerequisite round.

Source: `7ba0acc`, branch `exp/step5-softpll-lock`. Laptop authored and pushed
test code; pain pulled, compiled and executed it with user-local Icarus 10.3.
Questa compiled successfully but could not obtain a simulator license. The first
Icarus run lacked an explicit reset edge for derived-clock state; the corrected
test uses an explicit reset pulse. Both failed attempts are retained in raw.

## Pin-level findings

The Main request transmitted `(01,00), (39,0e), (1d,01)`. The Helper request
transmitted `(01,00), (39,0d), (1d,02)`. Both mask writes went to page zero.
With the static initialization mask 0x0c, a Main FINC moved BOTH model N0 and N1.
The Helper FDEC also moved BOTH. Expected-defect test passed: six writes,
two wrong-page mask writes. A page-aware model applies the mask only at 0x0339.

A Main code jump 100→10000 completed exactly ONE step. Ten subsequent writes
of the unchanged target completed no further step. This confirms the current
edge/direction interface is not an absolute target actuator. It does not measure
physical tuning authority or establish a replacement code/step scale.

Static initialization is explicitly bypassed in this runtime test; the static
controller, reset sequencing, physical silicon and oscillator plant are not
validated by this test. Actual serializer and bus engine are not mocked.

## Next round

Change only the page/mask sequence to page3→mask→page0→FINC/FDEC, preserving
Main/Helper PI, bootstrap and tracker scale. Re-run the same pin model with
`+fixed`, requiring eight writes and zero off-target model movement. Then full
compile on pain and program the two boards; collect fresh preflight evidence.
Physical isolation remains a separate measurement requirement. No merge.

`STEP5_COMPLETE=NO`
