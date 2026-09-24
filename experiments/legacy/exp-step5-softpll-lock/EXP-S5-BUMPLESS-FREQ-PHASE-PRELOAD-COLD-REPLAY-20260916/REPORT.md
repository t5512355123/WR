# EXP-S5-BUMPLESS-FREQ-PHASE-PRELOAD-COLD-REPLAY-20260916

## Verdict

```text
SESSION_START_INVALID = YES
DIAGNOSTIC_COMPLETE = NO
STEP5_PASS = NO
MERGE_APPROVED = NO
```

This is the exact-image cold-session replay requested after the prior F4M run
terminated at startup. The physical power cycle and reprogramming completed,
but the required entry gate never became valid. Formal F4M was therefore not
started.

## Fixed treatment

```text
source_commit = 6fa075bdbd5bfaba5fd7e53c9bad026ee217097
Master SOF   = 0x30B89B19
Slave SOF    = 0x30B84088
preload      = unchanged and enabled
control      = unchanged
```

No recompilation and no production-code modification was made for this
replay. The same built images were used.

## Physical power-cycle procedure

The authorized Pain shutdown workflow completed successfully:

```text
Edge control located and validated
first click: Pain switched off
off wait: 10 seconds
second click: Pain switched on
on-state control: visually re-identified
restart wait: 120 seconds
SSH probe: PASS (hostname=pain)
original window restoration: PASS
```

After Pain returned, Master was programmed first and Slave second. Both
programming operations succeeded with the same checksums listed above.

## Entry-gate observations

The read-only F4G preflight was run once immediately after reprogramming,
again after approximately 30 seconds, and again after approximately 90
seconds. The readings remained in startup on both boards:

```text
                         Master       Slave
WR_CORE_VALID              1            1
TERMINAL                   0            0
PHY_LINK_USABLE            0            0
PSTAT_LINK                 0            0
PSTAT_LOCKED               0            0
CURRENT_WR_STATE           0            0
BOOT_GENERATION            1            1
CPU_RESET_COUNT            1            1
WR_CORE_RESET_COUNT        0            0
SI_CONFIG_DROP_COUNT       0            0
```

Representative raw values remained:

```text
Master PTP_META_RAW = 0201106
Master WR_STATE_RAW = A0200064
Slave  PTP_META_RAW = 03010104
Slave  WR_STATE_RAW = A0000044
```

Both boards had `TERMINAL=0`, but `PHY_LINK_USABLE=0` and `PSTAT_LINK=0`, so
the minimum clean-session gate was not satisfied. In accordance with the
diagnostic rule, the 120-second F4M observer was not launched and no preload
or Step5 causal conclusion was drawn.

## Interpretation

This replay does not show a preload failure. It shows that after the cold
restart and same-image programming, the WR/PHY session had not reached the
link-established state by the final preflight. The result is a startup/link
gate failure and is not comparable to a valid control-treatment arm.

The next action is intentionally pending the external phase-lock analysis:
no timeout extension, PI/gain change, preload revert, or additional formal
capture is authorized by this record until the startup boundary is diagnosed.

## Artifacts

```text
raw/terminal-preflight.log
raw/terminal-preflight-after-link.log
raw/terminal-preflight-after-90s.log
raw/build/build_info_jtag_master.txt
raw/build/build_info_jtag_slave.txt
raw/build/quartus_jtag_master_compile.log
raw/build/quartus_jtag_slave_compile.log
analysis/cold-replay-verdict.json
```

SHA-256:

```text
terminal-preflight.log             0F56A966CC570497C9214E6ACB8E0F5E56A2E200B6D86E69F7F766DABE20D12E
terminal-preflight-after-link.log  459661AE8CE1B13578BBB09918D8ED249C242915283AA85815C49529FD2080CC
terminal-preflight-after-90s.log  17319D13B1BA191B7E35E8DF06E4ED794942D2A26B6920F5B68C3118F45FCBB7
```
