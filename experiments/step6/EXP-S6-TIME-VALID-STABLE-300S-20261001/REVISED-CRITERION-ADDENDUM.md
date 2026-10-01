# Revised Step 6 criterion — 2026-10-01

The user changed the functional target from sustained phase-offset tolerance to
maintaining Global-Time `TIME_VALID` for 300 seconds. The current project gate
requires both Master `1-11.1` and Slave `1-11.2` to pass independently. For
each board the decisive field is exported `STATUS_TIME_VALID`; every sampled
row must equal 1 across a sample-to-sample interval of at least 300,000 ms.

This experiment observed only Slave `1-11.2`. Its `STATUS_TIME_VALID` was
0/1,186 rows over 301,860 ms, so it does not pass. The post-capture Master
dashboard sample is not a 300-second record. Phase offset, TAI/cycle progress,
snapshot flags, PPS validity, link/lock fields, and timing closure do not alter
this result.

The new multi-board analyzer tests are in
`scripts/tests/test_step6_time_valid_300s.py`. Re-evaluation of the earlier
quarter-step capture found 957/957 valid Slave samples but a 299,984-ms
first-to-last sample span (16 ms short); no matching 300-second Master capture
exists. That result is a near-pass only. The planned repeat is documented in
`../EXP-S6-TIME-VALID-300S-QUARTER-ACQUIRE-20261001/PLAN.md`.
