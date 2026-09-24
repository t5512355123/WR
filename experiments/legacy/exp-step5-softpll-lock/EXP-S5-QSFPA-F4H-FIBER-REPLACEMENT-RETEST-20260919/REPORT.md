# EXP-S5-QSFPA-F4H-FIBER-REPLACEMENT-RETEST-20260919

## Verdict

```text
QSFP_A_LINK_ESTABLISHED = NO
QSFP_A_STABLE_LINK = NO
STEP5 = UPSTREAM_NOT_READY
```

Replacing the QSFP-A fiber did not establish a usable White Rabbit link in
this retest. The previously programmed source-equivalent image was left in
place; this was a read-only retest with no source change, reprogramming,
control-parameter change, or power cycle.

## Test identity

```text
source_commit = 898b041afa2fcd6ca48a84eb7326eebc419ac4a3
image = previously programmed source-equivalent rebuild
topology = QSFP-A
master_target = DE5 [1-11.1]
slave_target = DE5 [1-11.2]
physical_change = user replaced QSFP-A fiber before this retest
```

## Runtime link result

The full runtime reader completed successfully, but the required link gate
was still down on both boards:

```text
                         Master   Slave
wr_ready                    0        0
core_tm_link_up             0        0
core_link_ok                0        0
wr_rx_ready                 0        0
wr_tx_ready                 0        0
si_config_done              1        1
wr_rx_locked_to_data        0        0
```

The diagnostic transport itself was trusted: 352 WB requests completed with
zero timeout, invalid, unstable-transaction, or address-cross-contamination
events. Thus the result is a real PHY/link-gate failure, not a failed reader.

The Master event counters continued to advance and its Step4A event chain
was reported as PASS, but this does not imply a WR link. The Slave remained:

```text
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_RESULT = UPSTREAM_NOT_READY
```

## Clock/PHY activity

The additional 2000 ms activity capture showed counters changing, but
`PHY_READY=0` on both endpoints throughout the reported endpoints:

```text
Master: RX_LOCK_DATA 1 -> 1, PHY_READY=0
Slave:  RX_LOCK_DATA 0 -> 0, PHY_READY=0
```

Clock activity without `PHY_READY`, `core_tm_link_up`, and `core_link_ok` is
not a White Rabbit link.

## Conclusion

QSFP-A is still not linked after the fiber replacement. The replacement did
not move the system past Step 1, so no Step5 conclusion can be drawn. The
remaining failure is upstream of SoftPLL closed-loop lock; further Step5
tuning is not justified until the A-path PHY/link gate is restored.

## Raw evidence

- `raw/read-wb-runtime-raw.log`
- `raw/clock-activity-2000ms.log`
- `raw/experiment-manifest.txt`
