# Current TIME_VALID 300-second qualification

## Verdict

**PASS_TIME_VALID_300S on both boards, for the user's revised sampled-bit criterion.**
This is a fresh root build/compile/program result, not reuse of a historical
PASS log. The failed Master Helper recovery diagnosis remains NOT PASS.

| Board | Qualified rows | Observed span | Max sample gap | Invalid rows |
| --- | ---: | ---: | ---: | ---: |
| Master 1-11.1 | 1190 / 1190 | 302871 ms | 256 ms | 0 |
| Slave 1-11.2 | 1190 / 1190 | 302876 ms | 257 ms | 0 |

All rows on both boards also showed PPS_VALID, snapshot time-valid,
snapshot-valid, and all seven Step1/link fields equal to 1. Live time advanced
monotonically. Sample sequences, named-board identities and DONE row counts
matched; there were no capture errors. No rows were dropped or selected to
manufacture a passing interval.

## Source and programmed images

Both full compilations: source `40c388010fff51991d958f50702f42b3d3437d61`.
Subsequent commits changed only observer/experiment documentation and labels;
Pain confirmed no difference against that commit in firmware/vendor/Quartus
or generated compile inputs before exporting the retained products.

| Role | SOF SHA-256 | MIF SHA-256 |
| --- | --- | --- |
| Master | `f4dd3b2357a23ed7ee4c36004b35a821a7d32b52eac3ec32f9cb9bb86568e690` | `18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea` |
| Slave | `e890caca31130ec930664c5e35e425b2244c72a3209d80133e19aa5f93806189` | `91c5d7f9629a8a5d2a05116f12efd9515326ad25eee897a85ab97c71fc242c379` |

Fresh programming succeeded Slave at 13:48:28, then Master at 13:48:46 +08:00
on 2026-10-02. The read-only qualification began with run tag 20261002T055648Z.
No reprogramming, reset, mode change, timing-output forcing, calibration write,
PI/gain change or threshold relaxation occurred during this qualification.

## Actual workflow

Laptop change/test/push -> Pain pull -> build_current.sh -> compile_current.sh
-> program_current.sh -> single-session read-only dashboard/PLL queries
-> verify_time_valid_300s.sh -> raw/SOF transfer to Laptop -> independent
Laptop re-analysis -> report/products publication through GitHub.

The full current source and observer regression suite passed 52 tests.
The dashboard layout is preserved; Master Helper now shows its real value
instead of NA. Test-after-capture dashboard again showed both TIME_VALID and
PPS_VALID 1, with all five Slave lock fields 1. Pre/post explicit PLL queries
both reported boot generation 1, CPU reset 0 and reset_changed=0.

## Important limitations

- Master Helper remains unlocked (HY=5, ptracker not ready). The 2048-step
  origin change moved it from the upper to the lower rail, NOT into a proved
  locked operating point. Do not call this a Helper repair or infer causality
  for the older startup failure from one successful TIME_VALID capture.
- This is one fresh programmed-session qualification. Repeatability across
  every future rebuild, startup or physical power-cycle is not established.
- Boards were observed sequentially, each for a complete 303-second window.
  The evidence establishes every sampled TIME_VALID row over >300 seconds,
  not cycle-by-cycle continuity between reads or simultaneous edge skew.
- Fine timestamp correctness, absolute/civil time accuracy, dual-board trigger
  skew and sustained offset <60 ps were not established by this test.
- Timing remains not closed and is not the user's present acceptance gate.
- Step5 INFO in the short dashboard does not negate the five instantaneous
  Slave lock bits; the dashboard's short window does not prove a 300-second
  Step5 lock dwell. That separate milestone is not redefined here.

## Retained evidence and integrity

Primary capture: `raw/observe/20261002T055648Z-current-time-valid-303s.log`.
Result: `analysis/20261002T055648Z-current-time-valid-300s.json`.
Both have retained SHA256 sidecars. Raw build, program and post-capture
dashboard/PLL logs are included. The downloaded archive SHA256 is
`a1a650e3169bcc4d33a9c86cdcd0903212053cce720294165a42e0c8004214bd`;
Laptop verified it before extracting and independently obtained the same PASS.

Current SOFs and complete retained compile reports are in output/; firmware
products are in build/. PUBLISHED_SHA256SUMS covers these products plus the
twelve existing Step1–6 milestone SOFs, which remain unchanged. The protected
Pain archive was not accessed or modified. No advisor was consulted.
