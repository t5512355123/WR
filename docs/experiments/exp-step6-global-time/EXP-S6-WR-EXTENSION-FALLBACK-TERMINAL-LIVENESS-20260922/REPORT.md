# EXP-S6-WR-EXTENSION-FALLBACK-TERMINAL-LIVENESS-20260922

## 結論

本輪完成 adviser 指定的純唯讀 WR-extension fallback liveness diagnostic。

```text
RESULT                              = PASS_TERMINAL_WR_FALLBACK_WITH_PLL_READY
FAILURE_CLASS                      = WR_EXTENSION_DISABLED_WHILE_SOFTPLL_READY
WR_EXTENSION_FALLBACK_LIVENESS     = TERMINAL_NO_AUTONOMOUS_RETRY
STEP6A_RECOVERY_EVENT              = NOT_OBSERVED
STEP6A                              = NOT_PASS
STEP6B                              = NOT_RUN
```

這表示目前 Slave 的 WR extension 在觀測窗口內停留於 terminal fallback，
沒有自行重新進入 handshake；但底層 SoftPLL 已經準備完成。這不是
Global Time PASS，也沒有執行雙板 scheduled trigger。

## Source and hardware contract

- Laptop/GitHub source commit: `21e94006`
- Branch: `exp/step6-Global-Time-Testing`
- Pain worktree pulled the exact same commit before observation.
- Existing programmed images and runtime state were preserved.
- No compile, firmware build, programming, reset, PTP restart, mode command,
  power-cycle, fiber/QSFP change, polarity/bitslip change, autonegotiation
  change, SI5340 change, or MDIO write was performed.
- Only read-only JTAG/Wishbone diagnostic reads were used.

## Gate

Five paired precondition samples passed:

```text
GATE_PAIRS                 = 5/5
MASTER_PRECONDITION        = PASS
SLAVE_PRECONDITION         = PASS
```

The Slave retained the required recovered-link and fallback state:

```text
CORE_LINK_OK               = 1
CORE_TM_LINK_UP            = 1
RX_LOCKED_TO_DATA          = 1
RX_PATTERN_READY           = 1
RX_ACTIVITY_CHANGED        = 1 in every accepted sample
PTP_STATE                  = 9
PD_STATE                   = 4
EXT_STATE                  = 2
WRC_MODE                   = 3
TIME_VALID                 = 0
```

## Liveness capture

The nominal 15,000 ms capture ran for 15,775 ms and produced 13 paired
samples, 26 board rows total.

```text
MASTER_ROWS                = 13
SLAVE_ROWS                 = 13
READ_VALID                 = 26/26
CAPTURE_HEALTHY            = 26/26
RESET_CHANGED              = 0
COUNTER_DECREASE           = 0
AUTONOMOUS_REENTRY         = false
```

Slave fallback state remained terminal for all 13 samples:

```text
WR_STATE                   = WRS_IDLE (0) throughout
PTP_STATE                  = 9 throughout
PD_STATE                   = 4 throughout
EXT_STATE                  = 2 throughout
WRC_MODE                   = 3 throughout
TIME_VALID                 = 0 throughout
WR_LOCK_POLL_COUNT         = 3297313 throughout
LOCK_ENABLE_COUNT          = 4 throughout
SLOCK_TRACE_SEQ            = 3599673 throughout
```

No `WR_STATE != WRS_IDLE`, extension-state change, lock-poll increase,
lock-enable increase, S_LOCK trace-sequence increase, or `TIME_VALID=1`
event was observed.

## SoftPLL tail

The Slave was ready for the next recovery action in every accepted capture
sample:

```text
SPLL_SEQ_STATE             = SEQ_READY (8), 13/13
HELPER_LOCKED              = 1, 13/13
PSTAT_LOCKED               = 1, 13/13
MAIN_ENABLED               = 1, 13/13
MAIN_FREQ_LOCKED           = 1, 13/13
MAIN_PHASE_LOCKED          = 1, 13/13
MAIN_LOCKED                = 1, 13/13
```

The offline analyzer replayed the copied Pain raw log on Laptop and produced
the same classification. The full raw capture, protocol record, analyzer
output, and JSON summary are stored beside this report.

## Boundary and next action

The evidence now separates the problem from SoftPLL acquisition:

```text
Recovered WR link       = healthy
Slave SoftPLL           = ready and locked
WR extension            = terminal fallback, no autonomous retry
Global-Time Step6A      = not yet passed
```

Per the adviser contract, this run stops here. No recovery write action,
PTP restart, mode command, reset, or programming is performed automatically.
The next experiment must be specified separately and must preserve the
Step6A/Step6B boundary.
