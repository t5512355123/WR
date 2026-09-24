# EXP-S5-F4L-MAIN-PHASE-DRIFT-INTEGRATOR-BALANCE-20260917

日期：2026-09-17（Asia/Taipei）  
Branch：`exp/step5-softpll-lock`  
Source commit：`b1ac0cd7eb8eac8268f9d7e540f76932c9bb1712`

## Verdict

```text
CLASSIFICATION = DIAGNOSTIC_STOPPED_F4L_SMOKE_SCHEMA_NOT_READY
DIAGNOSTIC_PASS = NO
STEP5_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
```

本輪完成了 Laptop → GitHub → Pain build → program → 單一 F4L observer
session → raw 回傳 → offline analyzer，但沒有取得完整的三頁 F4L capture，
因此不能宣稱 F4L diagnostic pass，更不能宣稱 Step5 pass。

## Scope and frozen control

四條 QSFP 實體光纖均保持已插入狀態。本輪使用既有
`quartus/jtag_runtime_diag` 的原本 Master/Slave 路徑；QSFP-B startup-gate
結果仍是另一個獨立實驗，不與本輪混合。

本輪只調整 observer 的 10 秒 smoke/no-valid stop window，沒有修改
production control：

```text
Main/Slave Kp = 300, Ki = 1, prelock boost = 20
Master Kp = 300, Ki = 1, prelock boost = 20
Helper Kp = -2250, Ki = -2
phase guard = 8 s
Slave bootstrap = 3388
Master bootstrap = disabled
PI/gain/threshold/lock samples/anti-windup/DAC/timeout/bootstrap/arbiter/mailbox
PHY/reset/RTL/SDB = unchanged
```

Observer contract recorded in the raw config:

```text
read_only_observer=1
one_reader=1
no_control_write=1
no_helper_pi_snapshot=1
no_debug_fifo_drain=1
no_shared_control_struct_extension=1
no_rtl_or_sdb_change=1
control_parameters_unchanged=1
smoke_duration_ms=10000
no_valid_timeout_ms=10000
target_duration_ms=120000
hard_duration_ms=130000
```

## Laptop validation and Pain build

Laptop offline F4L tests passed by directly invoking all five existing test
functions (`F4L_OFFLINE_TESTS=PASS 5`). Pain pulled the exact source commit and
repeated the same five checks.

Both original JTAG images compiled successfully with Quartus 17.0 Build 595:

| image | result | SOF SHA-256 | worst setup slack |
|---|---|---|---:|
| Slave `DE5 [1-11.2]` | Full Compilation successful | `d2c7c052624d1fad64f9211d2e3b324b3ee4f8b9538f914e01580606f71309e2` | `-0.268 ns` |
| Master `DE5 [1-11.1]` | Full Compilation successful | `9c037f9cd7d7f565d7a54cfa4e42ba91b2ddf124f53271a1c2df74525cdf70ec` | `-0.047 ns` |

F4L compile-time markers were present in both images:

```text
DE5A_F4L_MAIN_PHASE_DIAG=1
DE5A_MAIN_PI_KP_OVERRIDE=300
DE5A_MAIN_BUMPLESS_FREQ_PHASE_PRELOAD=1
```

Timing is still not closed; this is recorded as an implementation caveat and
was not used as the Step5 verdict.

## Programming

Programming was successful once per board, in the required order:

```text
Slave  cable = DE5 [1-11.2], configuration succeeded
Master cable = DE5 [1-11.1], configuration succeeded
JTAG_F4L_STEP5_PROGRAM = PASS
```

The complete programmer output and cable list are in
[`raw/program`](raw/program).

## Observer result

The single observer command was:

```text
quartus_stp -t scripts/jtag/read_step5_main_frequency_prelock_observability.tcl 100 2000 "" 120000 130000 f4l
```

The observer stopped at `11.645 s` during the smoke gate:

```text
STEP5_F4L_SMOKE_SCHEMA_NOT_READY
run_end_reason=STOP_F4L_SMOKE_SCHEMA_NOT_READY
```

Offline analyzer output (`analysis/f4l-analysis.json`):

| metric | result |
|---|---:|
| valid F4L frames | 5 |
| invalid F4L frames | 0 |
| unique frames | 5 |
| valid span | 10,945 ms |
| generation set | `{1}` |
| page 0 / 1 / 2 | `2 / 3 / 0` |
| cycle Main-valid count | 5 |
| Main update progress intervals | 4 |
| Main-valid with Helper unlocked | 0 |
| Main-valid with Helper residual present | 2 |
| diagnostic classification | `DIAGNOSTIC_STOPPED_F4L_SMOKE_SCHEMA_NOT_READY` |

The five accepted frame pages appeared as:

```text
INTEGRATOR → SUMMARY → INTEGRATOR → SUMMARY → INTEGRATOR
```

The histogram page never appeared. The observer therefore correctly stopped
before the formal 120-second window; the return code `0` only means the Tcl
program exited normally and is not a diagnostic pass.

## What this run does and does not show

The upstream physical/WR path was usable in this capture:

```text
CORE_TM_LINK_UP = 1
CORE_LINK_OK    = 1
WR_RX_READY     = 1
WR_TX_READY     = 1
PSTAT_LINK      = 1
PHY_LINK_USABLE = 1
SI_CONFIG_DONE  = 1
WR_CORE_RESET_COUNT = 0
SI_CONFIG_DROP_COUNT = 0
```

The sampled F4L frames were coherent and schema-valid, and they exposed useful
but short-window values such as positive frequency errors `43, 34, 59, 62, 19`.
Page 1 also reported zero clamp events, zero anti-windup events, and zero
actual-integrator-delta mismatches in the sampled rows. These values are not
enough for a causal Step5 conclusion because the capture is shorter than the
required span and lacks page 2.

Source audit shows that the F4L publisher resets its page selector to Summary
whenever `softpll.mpll.enabled` is false. The observed page sequence never
reached page 2, which is consistent with the page selector being restarted
before a complete rotation. However, the observer's direct Main state fields
were `MAIN_STATE_RAW=INVALID` / `MAIN_ENABLED=INVALID` in the cycle records, so
this is a boundary hypothesis, not proof that Main disable is the root cause.
No control parameter is changed on the basis of this hypothesis.

## Interpretation

This run rules out “the current session has no usable PHY/WR link” for the
captured window, but it does not yet answer whether Helper unlock, residual
service demand, or phase PI/integrator behavior prevents sustained Main lock.
The missing histogram page is now the immediate observability boundary. It is
not valid to extend the run or adjust gain and call the result Step5 progress
until the three-page publication contract is satisfied.

## Evidence inventory

- [`PLAN.md`](PLAN.md)
- [`analysis/f4l-analysis.json`](analysis/f4l-analysis.json)
- [`raw/observe/observer-f4l.log`](raw/observe/observer-f4l.log)
- [`raw/observe/observer-command.txt`](raw/observe/observer-command.txt)
- [`raw/build`](raw/build)
- [`raw/program`](raw/program)

下一步暫停在這個 diagnostic boundary：不調 PI、不改 timeout、不改 PHY，先請
`分析下一步鎖定相位` 根據「page 0/1 可讀、page 2 未發布且 Main state direct
read 無效」這個新證據決定下一個只讀實驗。Step5 仍為 NO，沒有 merge。
