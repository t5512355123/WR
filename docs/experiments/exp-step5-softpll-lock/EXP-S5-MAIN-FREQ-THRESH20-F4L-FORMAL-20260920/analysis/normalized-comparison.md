# Threshold20 F4L formal normalized comparison

Experiment: `EXP-S5-MAIN-FREQ-THRESH20-F4L-FORMAL-20260920`

The capture was read-only in the same admitted live session.  The frozen
comparison baseline is the threshold50/Ki=0 formal result recorded by
`EXP-S5-MAIN-PHASE-KI0-F4L-MECHANISM-SMOKE-20260919`.  Raw totals are not
compared directly; each metric is normalized by its own eligible count.

| Metric | Frozen threshold50/Ki=0 baseline | Threshold20 candidate | Change | Interpretation |
|---|---:|---:|---:|---|
| Mean phase-conditioned frequency error | `19,398,454 / 440,976 = 43.989818` | `4,501,457 / 434,577 = 10.358250` | -76.4531% | improved |
| Mean modulo phase drift magnitude | `abs(-19,396,058 / 440,966) = 43.985382` | `abs(-4,501,364 / 434,577) = 10.358036` | -76.4512% | improved |
| Boundary crossing rate | `1,184 / 440,966 = 0.268501%` | `560 / 434,577 = 0.128861%` | -52.0074% | improved |
| Phase in-band ratio | `59,264 / (59,264 + 381,712) = 13.439280%` | `45,482 / (45,482 + 389,095) = 10.465809%` | -2.9735 percentage points | worse |

The first three normalized quantities improve substantially, but the in-band
ratio moves in the opposite direction.  This is therefore a mixed directional
result, not a demonstrated phase-lock solution.

## Branch and integrator observations

The 64 unique coherent F4L frames were all `BRANCH_ID=2` (phase).  The
unique-frame sequence contained `FREQ_TO_PHASE=0` and `PHASE_TO_FREQ=0` sample
transitions.  This is a frame-level observation, not an independent full-rate
handoff counter.

The page-0 counter window reported:

```text
frequency_updates_delta = 0
phase_updates_delta     = 434577
```

The independently sampled page-1 window reported:

```text
phase_i_count_delta             = 456306
phase_actual_i_sum_delta        = 0
phase_ki_x_sum_delta            = 0
frequency_i_count_delta         = 0
frequency_actual_i_sum_delta    = 0
frequency_ki_x_sum_delta        = 0
clamp_event_count_delta         = 0
anti_windup_event_count_delta   = 0
actual_delta_mismatch_count_delta = 0
```

The page windows are intentionally treated as non-atomic; their different
endpoints are not combined into one per-cycle causal claim.

