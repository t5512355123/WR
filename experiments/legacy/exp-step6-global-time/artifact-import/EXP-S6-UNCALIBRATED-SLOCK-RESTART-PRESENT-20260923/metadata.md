# Reproducible Step5 / Step6 milestone artifacts

```text
EXPERIMENT = EXP-S6-UNCALIBRATED-SLOCK-RESTART-PRESENT-20260923
SOURCE_COMMIT = 74dc28862653d306e0450cf437ba6d3a230d979d
QUARTUS = 17.0.0 Build 595
PROGRAM_ORDER = SLAVE_THEN_MASTER
STEP5_FIVE_LOCKS = PASS, 340 seconds
STEP6A_GLOBAL_TIME_AND_SAME_PPS = PASS
STEP6B_DIGITAL_SCHEDULED_TRIGGER = PASS
STEP6_PHYSICAL_EDGE = NOT_EVALUATED
TIMING_CLOSED = NO
```

| Board | SOF | SOF SHA-256 | Firmware MIF | MIF SHA-256 | Programmer checksum |
|---|---|---|---|---|---|
| Slave (`DE5 [1-11.2]`) | `DE5a_wr_slave_jtag.sof` | `4775de6007af90e2049bcff573fa4173d843c4d84d25b88490c89a8635adc5ca` | `wrc_slave.mif` | `066761f51af3cc279923bd1e349b33d2d311faa7d2fa23e43745d9a1da3ca33c` | `0x30B1E229` |
| Master (`DE5 [1-11.1]`) | `DE5a_wr_master_jtag.sof` | `6521eb861051ce2fbe283269169992ecb88e093d734012a97500682d74329845` | `wrc_master.mif` | `00cf52190ae60392fce14fcb23ffac6adcb82b3a9ca4de5d1e968d21e3c68681` | `0x30B18F28` |

The binaries are intentionally retained as a Pain-side experiment artifact,
not committed to GitHub. Their hashes, compile provenance, functional results,
and raw observer logs are versioned in the repository experiment report.
