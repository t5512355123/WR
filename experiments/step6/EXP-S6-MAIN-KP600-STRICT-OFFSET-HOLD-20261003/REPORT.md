# Main Kp600 under the current strict-validity baseline

2026-10-03, Asia/Taipei. Completed on the operational root, no advisor contact.

## Verdict

```text
NATIVE_AND_BUILD_ISOLATION       = PASS
FRESH_TWO_BOARD_COMPILE_PROGRAM = PASS
PHASE_HISTORY_DIAGNOSTIC        = PASS_POST_ACCEPT_PHASE_DATA_ONLY
MAIN_PHASE_RESIDUAL_DIRECTION   = IMPROVED_IN_THIS_WINDOW
STRICT_OFFSET_TIME_VALID_300S   = NOT_ESTABLISHED
360S_EXTENSION                  = NOT_RUN (postflight <10s gate)
MILESTONE_OR_MERGE              = NO
```

Main residual is substantially smaller in this boot, but WR CKO still leaves
the inclusive +/-120ps hold band. This is not a strict300s success. Every
observed trusted valid-outside-retention count was zero. No raw row or
freshness/completeness/60-120ps threshold was removed or relaxed.

## Exact source and products

Baseline report/source: `8983d6e4ac042c719d9216e67f87b2aeafff1bea`.
Laptop edit/test/push, Pain exact pull/native/role build source:
`c67f3a7ad04f358d4c9b65035482aed7148b4130`.
Laptop actual-MIF pin/precheck push, Pain exact pull/full Quartus compile:
`78948729bc18c5a78aaede3b6a8f7a363042efc7`.

Exactly one functional source change: Slave shared Main Kp300->600. It affects
both frequency and phase branches. Ki1, boost20, frequency threshold20,
bumpless preload1, WR acquire/2 and track/12, strict validity, Helper/DCO,
arbiter/bootstrap/timeout/PHY/reset/RTL/constraints/512-average remain fixed.
Master firmware MIF is byte-identical. Actual Slave binary changed only two
bytes in the RV32 `li a4,600` instruction; see BUILD_PRECHECK and raw/build.

| Actual product | SHA256 |
| --- | --- |
| Master MIF | 8913615c374fdb88a5c107fe7422f5f5c30d4a6aba7429ed2c502bf83a9d4ea5 |
| Slave MIF | 006d798a02699167337c6a417f14fd898b0ffad872e35a2c2e9250fbededd4e5 |
| Master SOF | 617c479a2f8517d96a252321205848562e860da843c01acf4fbfc6c57cfcd851 |
| Slave SOF | a070c67d845605eefd1a9721e650312e6eeccb60875f0b56e81db8435d5ce3bc |

Both full compiles succeeded. Master finished11:17:41, Slave11:29:32.
Reported setup/hold: Master +0.192/+0.040ns, Slave -0.659/+0.035ns;
full timing remains NO and is not an acceptance gate. Root output contains
these actual latest candidate SOFs, not a PASS milestone.

One programming pair only, Slave11:30:33-11:30:52 then Master11:30:52-11:31:11.
Both configured one device successfully. No powercycle, additional reset,
port change, live calibration, or second JTAG reader.

## Tests and bounded strict observation

Laptop scope4/history9/strict9 tests passed. Pain scope4 and actual native
history/ptracker512/TS4/WR-servo35/fixed-SETP tests passed; raw/tests/native.log.

| UTC capture start | Duration | Rows / rejected | Fresh <60ps entries | Longest qualified span | Trusted CKO range |
| --- | --- | --- | --- | --- | --- |
| 03:31:27 | 20s smoke | 23 / 23 | 0 | 0ms | none (startup not locked) |
| 03:32:16 | 120s acquisition | 130 / 61 | 9 | 2109ms | -6781..+9936ps, includes acquisition |
| 03:37:40 | 20s postflight | 22 / 10 | 4 | 901ms | -189..+149ps |

All three complete transport sessions had timeout_count=0, invalid_count=0,
analysis errors=[], observed trusted valid-outside-retention=0. Rejected rows
remain in raw evidence and cannot extend dwell. The final postflight failed
the predeclared >=10s extension gate, so no360s/300s attempt was claimed.

## Main/tracker history and comparison

Capture03:34:34UTC completed32 immutable rows over162520ms host time;
actual frozen firmware window32473ms, accepted WR UCNT131..162. All source
group/schema/snapshot/serial/progress/health guards passed. Both boards'
bracket reset signatures stayed `{1 1 1 0 1}`, link/clock health remained
good, Master validity stayed1, and all five Slave lock fields stayed1.
SPLL init1, Main frame init1, tracker generation4 throughout.

The independent Laptop comparison is `analysis/laptop-kp-comparison.json`:

| Matched descriptive metric | Previous Kp300 | Current Kp600 |
| --- | --- | --- |
| Main phase rows | 32/32 | 32/32 |
| Main/tracker forward intervals | 31/31 each | 31/31 each |
| Main actual phase error range | -411.13..+501.95ps | -198.24..+228.52ps |
| Main error mean absolute / population SD | 219.39 / 250.24ps | 87.55 / 108.63ps |
| Main error within inclusive120ps | 7/32 | 22/32 |
| WR CKO range | -306.50..+242.49ps | -300.51..+274.49ps |
| WR CKO mean absolute / population SD | 116.25 / 134.08ps | 91.12 / 123.07ps |
| WR CKO strict<60 / inclusive120 | 8/32, 20/32 | 14/32, 24/32 |
| WR state4 TRACK / state5 WAIT | 11 / 20 | 17 / 15 |
| Main completed sample increment | 119436 | 123868 |
| Tracker publication increment / age | 234 / 1..126ms | 242 / 3..128ms |
| PI/DAC command range | 11773..11935 | 11408..11624 |

Both windows have Main flags0x17F on32/32 rows. Actual phase LD threshold
1200 is about1171.875ps (16ns/16384 per Main error unit), so phase lock1
does not promise +/-120ps. Producer progress and normal tracker age argue
against a sustained frozen producer within these windows, not against all
unsampled stalls. PI output is a command, not a measurement of applied DCO.

These are different boots and independently copied post-WR source groups,
not packet-time atomic phase samples or randomized causal proof. We cannot
declare Kp the sole cause, an analogue clock-skew improvement, or a general
reproducibility claim from32 rows. Broadly narrowed Main error with residual
CKO excursions means Main gain alone has not solved the requested gate.

## Final dashboard and historical meaning

One-shot dashboard exited0, both TIME_VALID/PPS_VALID1; Slave all five lock
fields1, TRACK_PHASE, CKO-105ps. This is pointwise, not sustained PASS.
MasterTAI436/Slave440 were sequential JTAG PPS snapshots, not simultaneous
global-time alignment evidence. No continuous dashboard/JTAG owner left.

Historical Step5 Ki1 four-lock300s is retained as valid for its own gate;
the old TIME_VALID-only300s milestone also remains a historical result.
Neither proves today's stricter CKO60-entry/120-hold objective. Older Ki0
mechanism work did not establish sustained phase lock. Thus this round
provides no basis to blame Ki or blindly disable the integrator.

## Return, publication, and next boundary

Archive87 entries (86 manifest-covered products plus manifest), SHA256:
`d1ecace096df02b10cb019f4895336424a5280eb1ef5a976e115db238639dbcd`.
Laptop verified all86 and independently re-analyzed all four sessions;
JSON values exactly match Pain (newline bytes need not match). Additional
Laptop analyses/comparison script are explicitly not in that original
transfer manifest. build/output source/SOF/publication manifests retained.
Protected Pain archive and all frozen milestones untouched.

The next safe boundary is actual Main command-to-DCO application/service,
not an automatic gain/Ki sweep: existing history proves completed controller
progress but does not record the actual applied DCO value and its timing.
Audit existing request/applied/pending/start/completion probes first, then
one minimally scoped passive same-session correlation if a trustworthy
mapping is available. Service correlation must not be called causality or
packet-specific clock phase. Do not weaken the goal to keep TIME_VALID high.
