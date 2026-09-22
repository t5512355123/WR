# EXP-S6-DASHBOARD-WR-HANDSHAKE-CLASSIFICATION-FIX-20260922

日期：2026-09-22（Asia/Taipei）

## Verdict

```text
STEP3_CLASSIFICATION_FIX       = PASS
SLAVE_STEP3                    = PASS
SLAVE_STEP4B_ALLOWED           = YES
SLAVE_STEP4B_RESULT            = PASS
SLAVE_STEP5_RESULT             = LOCK_ACQUIRED_NOT_STABLE
SLAVE_HELPER                   = 1
SLAVE_MAIN_FREQUENCY           = 1
SLAVE_MAIN_PHASE               = 1
SLAVE_MAIN_LOCK                = 1
SLAVE_PSTAT                    = 1
FAILURE_CLASSIFICATION         = NO_FAILURE_EVIDENCE
JTAG_WB_DIAGNOSTIC_PATH        = TRUSTED
POWER_CYCLE                    = NO
```

## Problem and correction

The old Step 3 reader required the last-observed RX/TX words to be exactly
`LOCK (0x1001)` and `SLAVE_PRESENT (0x1000)`. On a healthy, already-progressed
Slave, the same source-defined last-observed fields legitimately contained:

```text
RX = WR_MODE_ON  (0x1005), count=4
TX = CALIBRATED  (0x1004), count=4
state = WRS_IDLE -> WRS_IDLE
```

Those values were incorrectly promoted to a Step 3 error, which then blocked
Step 4B and made Step 5 report `UPSTREAM_NOT_READY` even though the direct lock
bits were all `1`.

The read-only classifier now:

- treats known WR messages `0x1000..0x1005` with a positive count as
  informational protocol-progress evidence;
- treats one `WRS_IDLE` mailbox sample as informational rather than a failure;
- prevents informational sub-observations from downgrading an otherwise valid
  Step 3 gate;
- keeps unknown messages, zero counts, invalid reads, and real gate failures as
  blocking conditions.

The focused repeated handshake reader remains the authority for multi-sample
handshake history. This dashboard change does not weaken the separate Step 5
stability/300-second requirement.

## Source and image provenance

```text
branch                         = exp/step6-Global-Time-Testing
final reader commit            = cf08f7c38f7b95152104fc53ec44ca8305faa0a3
FPGA build/program commit      = cc2cc95e82a46b11ae670839ed06e200f55f0755
change type                    = host-side read-only Tcl classification
Slave SOF SHA256               = 9d641d754b423ff80cc6862e297ab3c7b9b8a729ff02dd7b6e794cd4a778826e
Master SOF SHA256              = 4d140e6edb3d6d3257d59124d459a06f2572b70c71d7dc77b47aaee6346ea311
```

The final `cf08f7c3` change only altered the host-side aggregation of the
read-only dashboard. It did not alter FPGA RTL, firmware, MIF, QSF, SDC,
SoftPLL, PI, gain, threshold, timeout, PPS, PHY, reset, or DAC behavior; the
already-programmed SOF therefore remained valid and did not need to be
reprogrammed for that final reader-only aggregation change.

The preceding exact-commit FPGA build completed with zero Quartus errors:
Slave had 264 analysis warnings and Master had 262 analysis warnings; timing
closure remains an implementation caveat and was not changed in this experiment.

## Required workflow completed

1. Laptop committed and pushed the reader classification change.
2. Pain pulled the exact source and compiled/programmed the existing Slave and
   Master designs, Slave first and Master second.
3. An initial raw read immediately after programming was retained; it was
   correctly classified as a transient Step 2 startup block.
4. After the link/session settled, a final raw read and human-readable dashboard
   were run read-only.
5. Raw evidence was copied back to Laptop and this report was pushed.

No physical power-cycle was used.

## Final raw evidence

The final raw read contains:

```text
[info] WR_RX_SIGNAL_DEBUG  結果: WR_MODE_ON count=4/NA
[info] WR_TX_SIGNAL_DEBUG  結果: CALIBRATED count=4/NA
[info] WDIAGS_TEMP         結果: WRS_IDLE next=WRS_IDLE/NA
Step 3 pass
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP5_RESULT = LOCK_ACQUIRED_NOT_STABLE
FAILURE_CLASSIFICATION = NO_FAILURE_EVIDENCE
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

Final dashboard capture at `2026-09-22T16:29:11+08:00`:

```text
MASTER  DE5_1-11.1
  Step 3 WR Handshake         INFO
  Step 4 SoftPLL Startup      PASS
  Step 6 Global Time          VALID

SLAVE   DE5_1-11.2
  Step 3 WR Handshake         PASS
  Step 4 SoftPLL Startup      PASS
  Step 5 Closed-loop Lock     INFO
  Helper=1 MainFreq=1 MainPhase=1 MainLock=1 PSTAT=1
  TIME_VALID=1 PPS_VALID=1
  TAI=297 CYCLES=124999999 VALID
  Step5 result LOCK_ACQUIRED_NOT_STABLE
```

`LOCK_ACQUIRED_NOT_STABLE` is now the correct remaining status for a short
dashboard window: the lock bits are currently asserted, but this single read
does not prove the required long-duration stability. It is no longer an
upstream Step 3/Step 4 classification failure.

## Raw files and SHA-256

```text
raw/build/build.log
raw/program/program.log
raw/observe/runtime-raw-pre-aggregation.log
raw/observe/runtime-raw-final.log
raw/observe/dashboard-final.log
```

```text
3554C0E095659D62611144B4AE6A91CCECD2B3995928AEDDA85DE1C370614E97  raw/build/build.log
385499BD3185905EB2F15B99FC8BB1275C6ABE4F62B65419A171AE224BC88194  raw/program/program.log
639218806354E990CC5552E7989389C8C1A01BAC86770AF648851A1F26C618D9  raw/observe/runtime-raw-pre-aggregation.log
587F7B5D39DD342145036327A9E89E9C0F6D66C89CFB82F00DAF5E2288F9F72E  raw/observe/runtime-raw-final.log
DE2AE34BFFA8A494B7C4C3CAE99F675D530BC7B1AB65BE007370DAD832664883  raw/observe/dashboard-final.log
```

## Conclusion

The false Step 3 warning has been corrected. A progressed and healthy Slave is
now shown as `Step3 PASS` and `Step4 PASS`; the dashboard reserves `Step5 INFO`
for the remaining stability-window requirement while exposing the direct lock
bits clearly.
