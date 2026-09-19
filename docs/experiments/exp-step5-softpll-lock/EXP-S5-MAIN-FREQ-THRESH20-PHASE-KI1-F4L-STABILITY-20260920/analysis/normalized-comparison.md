# Threshold20 + phase-Ki1 F4L stability normalized comparison

The corrected capture is compared with the frozen threshold20 + phase-Ki0
formal using the same independently sampled page-0 counter method.  The
corrected page-0 deltas are:

```text
phase_freq_error_count_delta = 434852
phase_freq_error_sum_delta   = 1122
phase_delta_sum_delta        = 93
positive_boundary_delta      = 0
negative_boundary_delta      = 0
phase_in_band_delta          = 434852
phase_out_of_band_delta      = 0
```

| Metric | Frozen threshold20 + Ki0 | Corrected threshold20 + Ki1 | Change |
|---|---:|---:|---:|
| Mean phase-conditioned frequency error | 10.358250 | 0.002580 | -99.9751% |
| Mean modulo phase drift magnitude | 10.358036 | 0.000214 | -99.9979% |
| Boundary crossing rate | 0.128861% | 0.000000% | -100.0000% |
| Phase in-band ratio | 10.465809% | 100.000000% | +89.5342 percentage points |

Page-1 integrator deltas in the corrected capture are:

```text
phase_i_count_delta             = 456594
phase_actual_i_sum_delta        = 189886
phase_ki_x_sum_delta            = 189886
clamp_event_count_delta         = 0
anti_windup_event_count_delta   = 0
actual_delta_mismatch_delta     = 0
```

These metrics are window-normalized only.  Page 0 and page 1 are published
independently, so they are not a claim that all values came from one atomic
firmware cycle.  The strict offline analyzer also reported four repeated rows
with page-counter consistency warnings; those rows are recorded in the main
report and do not alter the 64/64 producer lock flags.
