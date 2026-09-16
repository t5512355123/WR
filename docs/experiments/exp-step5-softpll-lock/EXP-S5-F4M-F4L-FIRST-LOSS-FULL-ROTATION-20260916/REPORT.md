# EXP-S5-F4M-F4L-FIRST-LOSS-FULL-ROTATION-20260916

## Result

This run is a **diagnostic closure pass**, not a Step5 lock pass.

```text
CLASSIFICATION       = DIAGNOSTIC_COMPLETE
DIAGNOSTIC_PASS      = YES
STEP5_PASS           = NO
STEP5_COMPLETE       = NO
```

The observer proved that the existing F4L paged Main frame can be read with
full page rotation and that the WRS_S_LOCK trace remains valid throughout the
entire 120 s window. Main phase lock was not established:

```text
PSTAT_LOCKED         = 0 for all correlated samples
S_LOCK terminal      = not reached
first-loss           = not observed before target end
```

## Question under test

The previous F4L capture saw only page 0 and page 1. This experiment tested
whether that was an observer/page-rotation coverage artifact and collected a
passive first-loss correlation window without changing the controller.

The observer-side page counters use only unique, coherent frame keys
`(page, source_epoch, update_id)`. A page mismatch is labelled an observer
expected-next-page mismatch; it is not promoted to a firmware scheduling fault.

## Frozen control scope

No production control parameter or control ordering was changed.

```text
Main Kp / Ki                         +300 / +1
Main frequency pre-lock gain boost  20
Helper Kp / Ki                      -2250 / -2
Slave bootstrap                     3388
Thresholds, lock samples, timeout   unchanged
PI, anti-windup, DAC behavior       unchanged
Arbiter/mailbox/PHY/reset/RTL/SDB   unchanged
```

The only source change in this experiment was the read-only JTAG observer and
its offline analyzer/test. No production C or RTL was modified.

## Required workflow evidence

1. Laptop committed and pushed observer/analyzer changes:

   ```text
   branch = exp/step5-softpll-lock
   commit = e1ac5ca1e9aaacef08c7441745271430ec2da432
   ```

2. Pain pulled that commit, compiled both JTAG images, and programmed both
   boards. Both Quartus compiles and both Programmer operations reported
   success.

3. WDIAGS mapping preflight passed for both boards.

4. One F4M observer process ran:

   ```text
   timeout 180s quartus_stp -t \
     scripts/jtag/read_step5_main_frequency_prelock_observability.tcl \
     100 1000 "" 120000 130000 f4m
   ```

   The run ended normally at the 120000 ms target (`session_elapsed_ms=120095`),
   not at a transport or observer timeout.

## Build and program identity

Both images were compiled from the pushed commit with Quartus 17.0.0 Build
595. Timing was not closed, as in the prior baseline; this experiment did not
change timing constraints.

```text
Master compile = Full Compilation was successful
Slave  compile = Full Compilation was successful
Master TIMING_CLOSED = NO, WNS = -0.047 ns
Slave  TIMING_CLOSED = NO, WNS = -0.268 ns

Master MIF SHA256 = f9c68c2c644846f382ec52425406f5b726c5c13088b841d415fe2c62c8652363
Slave  MIF SHA256 = 730629963f410d23b0466fff9fde9663ef212a3e131f9b41fc02bbc04de2b2b5
Master SOF SHA256 = e6782288f0da27485c52a4c6aa5947429b6fadabf5cd3528ed5bc4dd805bbc6b
Slave  SOF SHA256 = f6ff95ebf0728efed96b55929d0a49d965923f2e634d949f0e9d05f8e7fce729
```

## F4M observation

```text
valid Main frames                 64
unique Main frames                64
unique span                       119095 ms
10 s time bins                    13
generation                        [1]
Main-valid Slave cycles           64
Main progress intervals           63
Helper-valid Slave cycles         64
Helper unlocked with Main valid   0
Helper residual with Main valid   41
```

Page closure was complete and internally consistent:

```text
page 0 observed/published          21
page 1 observed/published          21
page 2 observed/published          22
page2 due                         22
page2 skip                         0
rotation count                    63
transition mismatches              0
```

The page sequence was therefore a complete `0 -> 1 -> 2` rotation for the
whole valid capture. The earlier 0/1-only pattern was not reproduced under
this full-rotation observer run.

The passive first-loss/S_LOCK correlation was also valid:

```text
S_LOCK samples                    64
trace-valid samples               64
observed S_LOCK stages             2
remaining-ms range                135091 .. 15999
terminal samples                   0
first-loss before target end       no
PSTAT_LOCKED                       0
```

The S_LOCK multi-word record is explicitly non-atomic across individual JTAG
reads; it is used for firmware-time alignment only, not as a single-cycle
causal claim. The single observer also sampled existing L2 probe 61
(`FIRST_LOSS`) without requesting a PI snapshot or starting another reader.

## Offline checks

```text
test_step5_f4m.py                  PASS
test_step5_f4l.py                  PASS
test_step5_wdiags_transport...     PASS
Python syntax checks                PASS
diff check                         PASS
```

The machine-readable verdict is in `analysis/f4m-verdict.json`.

## Conclusion and next experiment

The diagnostic gate is closed: Main keeps progressing, Helper remains valid,
all three F4L pages are present, the generation is stable, and no first-loss
occurred before the target end. This run does **not** satisfy Step5 because
`PSTAT_LOCKED` stayed zero.

The next functional experiment should therefore be the first bumpless
frequency-to-phase handoff change, while keeping Kp/Ki and all other control
parameters frozen. At the first valid phase handoff, preload the phase
integrator using:

```text
I_phase0 = u_freq - Kp * e_phase0
```

That change must be evaluated first for handoff discontinuity, then residual
phase drift, and only then for an actual `PSTAT_LOCKED=1` window. No Step5
merge is approved by this diagnostic run.

## Raw artifacts

```text
raw/observer-f4m.log
raw/wdiags-preflight.log
raw/build/build_info_jtag_master.txt
raw/build/build_info_jtag_slave.txt
raw/build/quartus_jtag_master_compile.log
raw/build/quartus_jtag_slave_compile.log
analysis/f4m-verdict.json
```

SHA256 of the two primary raw logs:

```text
observer-f4m.log       b452f4be0cc768224a93e73ac3cd12aff1e5ad5d335b0bf6eaaeaa78a999ac9a
wdiags-preflight.log   c3e75b3587772a10dfd490b777fa5b3e15df25ee97675d1a7f20e6bcefed6f20
```
