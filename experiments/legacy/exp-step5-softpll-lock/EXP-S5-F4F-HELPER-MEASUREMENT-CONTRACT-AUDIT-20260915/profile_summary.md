# F4F profile summary

Source: `analysis/replay-e550e57d-f4f-jtag-runtime/verdict.json`  
Raw: `raw/attempt-e550e57d-f4f-jtag-runtime/tmp/observer.log`

```text
classification=COMPACT_HELPER_CORE_OBSERVABLE
diagnostic_pass=true
session_elapsed_ms=120380
cycles=103
attempts=478
FULL attempts=416 accepted=0 epoch_changed=416 arithmetic_mismatch=81
CORE attempts=62 accepted=51 fresh=50 stale=0 ambiguous=0 epoch_changed=11
CORE accepted_span_ms=116909
payload_isolation_pass=true
alternating_profiles_pass=true
retry_bound_pass=true
reset_changed=0
terminal=0
step5_pass=false
merge_approved=false
```

Interpretation: the CORE contract is observable and fresh for more than ten
seconds; the FULL contract remains unresolved because its live read span never
finished under an unchanged epoch. This is a diagnostic milestone only.
