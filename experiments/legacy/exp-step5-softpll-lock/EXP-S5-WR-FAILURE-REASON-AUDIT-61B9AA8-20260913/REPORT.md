# EXP-S5-WR-FAILURE-REASON-AUDIT-61B9AA8-20260913

## Classification

```text
INVALID_MIF_BUILD = YES
AUTHORITATIVE_STEP5_VERDICT = NOT_DETERMINED
```

This preliminary run is retained only to document a process error. Quartus
was run before rebuilding firmware, so its MIF hashes remained unchanged from
the preceding image. Its `fail_reason=NEVER` observation cannot be used to
diagnose the source change or White Rabbit Step5.

The corrected authoritative run is recorded in
`EXP-S5-WR-FAILURE-REASON-AUDIT-61B9AA8-VALID-MIF-20260913`.

