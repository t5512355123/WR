# All-corner STA summary

The clean Master and Slave builds used Quartus Prime 17.0.0 Build 595 and
source/build commit `54919aa7b9a4048228d6f121a205898c804e1aee`.

## Design-wide worst slack by corner

All values are ns. The values come from the post-clean-build `.sta.rpt`
files, not from the previous fitted database.

| Image | Corner | Setup | Hold | Recovery | Removal |
| --- | --- | ---: | ---: | ---: | ---: |
| Master | Slow 900mV 100C | +0.146 | +0.036 | +1.295 | +0.227 |
| Master | Slow 900mV 0C | -0.246 | +0.034 | +2.299 | -0.204 |
| Master | Fast 900mV 100C | +0.534 | -0.502 | +1.248 | +0.203 |
| Master | Fast 900mV 0C | +1.659 | +0.010 | +3.033 | +0.170 |
| Slave | Slow 900mV 100C | +0.188 | +0.034 | +0.751 | +0.248 |
| Slave | Slow 900mV 0C | -0.279 | +0.036 | +1.254 | -0.216 |
| Slave | Fast 900mV 100C | +0.437 | -0.486 | +1.581 | +0.206 |
| Slave | Fast 900mV 0C | +1.766 | +0.010 | +3.270 | +0.169 |

## Remaining boundary

The worst remaining negative timed category is Fast 900mV 100C hold on
`u_sys_clk_625|u_altpll|auto_generated|wire_generic_pll1_outclk`:

```text
Master WNS = -0.502 ns, TNS = -30.718 ns
Slave  WNS = -0.486 ns, TNS = -36.233 ns
```

The same corner also has `qsfp_ref_125m` hold violations of `-0.469 ns`
(Master) and `-0.422 ns` (Slave). Slow 900mV 0C has the first setup
violation on `qsfp_ref_125m`: `-0.246 ns` Master and `-0.279 ns` Slave.

## Constraint coverage remaining

| Image | Unconstrained clocks | Unconstrained input paths | Unconstrained output paths |
| --- | ---: | ---: | ---: |
| Master | 6 | 1852 | 83 |
| Slave | 6 | 2626 | 79 |

Both compile logs and STA reports still state that the SDC
`create_generated_clock` for `wr_core_dmtd_62m496` resolves an empty target
collection. This experiment did not modify that constraint.
