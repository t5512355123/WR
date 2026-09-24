# Ki=0 formal normalized comparison

Experiment: `EXP-S5-MAIN-PHASE-KI0-F4L-MECHANISM-SMOKE-20260919`

The candidate was captured for 120 seconds in the same freshly programmed session as the 10-second smoke. Raw totals are not compared directly because the baseline and candidate have different update counts; the comparison uses normalized metrics.

| Metric | Frozen baseline | Ki=0 candidate | Change | Interpretation |
|---|---:|---:|---:|---|
| Mean phase-conditioned frequency error | `19,398,454 / 440,976 = 43.989818` | `19,599,453 / 455,398 = 43.038074` | -2.1636% | Improved |
| Mean phase drift magnitude | `abs(-19,396,058 / 440,966) = 43.985382` | `abs(-19,597,677 / 455,398) = 43.034175` | -2.1626% | Improved |
| Boundary crossing rate | `1,184 / 440,966 = 0.268501%` | `1,196 / 455,398 = 0.262627%` | -2.1877% | Improved |
| Phase in-band ratio | `59,264 / (59,264 + 381,712) = 13.439280%` | `61,123 / (61,123 + 394,275) = 13.421886%` | -0.017394 percentage points | Slightly worse |

The first three metrics improve slightly, but the in-band ratio decreases slightly. Therefore the candidate is not a consistent directional improvement over the frozen baseline.

## Formal mechanism gate

```text
phase_updates_delta           = 433712 (> 0)
phase_actual_i_sum_delta      = 0
phase_ki_x_sum_delta          = 0
frequency_actual_i_sum_delta  = 0
frequency_ki_x_sum_delta      = 0
clamp_event_count_delta       = 0
anti_windup_event_count_delta = 0
actual_delta_mismatch_delta   = 0
```

The frequency branch had zero updates in this already-frequency-locked window, so its equality is zero-to-zero. The phase branch had sustained nonzero updates while both phase integrator terms remained zero.

## Verdict

```text
PHASE_KI0_IMPLEMENTATION    = PASS
PHASE_KI0_DIRECTION         = MIXED_NEAR_BASELINE
PHASE_KI0_CAUSAL_HYPOTHESIS = INCONCLUSIVE
MAIN_PHASE_LOCK_OBSERVED    = NO
STEP5                       = NO
```
