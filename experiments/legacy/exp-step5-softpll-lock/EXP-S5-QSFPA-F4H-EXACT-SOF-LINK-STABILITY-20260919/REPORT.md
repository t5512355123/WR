# EXP-S5-QSFPA-F4H-EXACT-SOF-LINK-STABILITY-20260919

## Verdict

```text
QSFP_A_STABLE_LINK = FAIL
STEP5_PASS = NO
```

The A-path did not regain a stable WR link after programming. Both boards
were programmable and the diagnostic transport was healthy, but the required
PHY/link gate never became valid. Slave Step4B and Step5 consequently did not
start.

This run was **not** performed with the historical exact SOF binaries. Those
binary artifacts were unavailable. It was a source-equivalent rebuild from the
same documented source commit, so the result is a valid diagnostic result for
that rebuild but cannot be claimed as an exact-binary replay.

## Provenance and execution

```text
source_commit = 898b041afa2fcd6ca48a84eb7326eebc419ac4a3
execution_class = SOURCE_EQUIVALENT_REBUILD_NOT_ORIGINAL_EXACT_SOF
master_target = DE5 [1-11.1]
slave_target = DE5 [1-11.2]
topology = QSFP-A path
```

Historical hashes recorded by the previous F4H report:

```text
master_exact_sof_sha256 = fe73fe54e702e974ed4452e517751ebf8a1cbcd93d7a19207839ed13a9bed7
slave_exact_sof_sha256  = 30c78989caa9496b5a34bc771f4c0a238ebd9c271045f55c6a7d4963c13df7bc
```

Fresh rebuild hashes actually programmed:

```text
master_rebuild_sof_sha256 = f40eeb1046381fcfd186618a4f66a0cbe6571fa449f5e4fc525b679a064b5532
slave_rebuild_sof_sha256  = 1a3201d001355944d74fc4191317f79711ec9389c2f4410e93e727be9e881750
```

Both Quartus builds completed successfully. Programming also completed on
both targets; the programmer reported configuration checksums `0x30B89B19`
(Master) and `0x30B84088` (Slave). No source, production-control, PI, gain,
threshold, timeout, bootstrap, QSFP mapping, or reset changes were made, and
no additional power cycle was used.

## Read-only observations

### Repeated status probes

Twelve `read_probe.tcl` samples were collected for each board. Every JTAG
request completed, and the WB diagnostic transport reported:

```text
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
UNSTABLE_TRANSACTION_COUNT = 0
```

The required link bits did not become valid. Across the probe samples, the
low status word retained `SI_CONFIG_DONE=1`, while `CORE_TM_LINK_UP` and
`CORE_LINK_OK` were not asserted. The raw status samples are preserved in
`raw/read-probe-12x.log` and `raw/probe-hex-summary.txt`.

### Full runtime gate

The authoritative runtime read classified both boards as Step 1 error:

```text
                    Master       Slave
wr_ready               0            0
core_tm_link_up        0            0
core_link_ok           0            0
wr_rx_ready            0            0
wr_tx_ready            0            0
si_config_done         1            1
wr_rx_locked_to_data   0            0
```

The read itself was internally healthy. It completed 352 WB requests with
`PRELOAD_PROTOCOL_RUNTIME_REVALIDATION=PASS`, zero timeouts, zero invalid
transactions, and no address cross-contamination. Therefore this is not a
JTAG reader failure masquerading as a link failure.

### Clock activity

The 2000 ms clock-activity capture showed reference/DMTD/RX counters moving on
both boards, but `PHY_READY=0` at both endpoints. Master RX-data lock changed
from `1` to `0`; Slave reported RX-data lock at the end of the window, but its
top-level link gate remained deasserted. Activity alone therefore did not
constitute a WR link.

### Runtime milestone boundary

The Master event chain continued to operate:

```text
STEP4A_MASTER_EVENT_CHAIN = PASS
BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0
```

The Slave remained upstream-blocked:

```text
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP1
STEP5_RESULT = UPSTREAM_NOT_READY
```

This means the observation reached the expected boundary: the diagnostic and
Master SoftPLL event machinery were alive, but the A-path PHY/link prerequisite
was absent. It is not evidence for or against the later Main phase-lock loop.

## Conclusion

QSFP-A is **not stably linked in this run**. Returning to the source revision
associated with the earlier successful A-path report did not reproduce a valid
link with the available source-equivalent rebuild. Because the historical
SOF files are missing, the next investigation should distinguish binary
identity/artifact reproducibility from the common A-path hardware/startup
failure before resuming Step5 experiments. No Step5 tuning or phase-control
change was justified by this run.

## Raw evidence

- `raw/read-wb-runtime-raw.log`
- `raw/read-probe-12x.log`
- `raw/probe-hex-summary.txt`
- `raw/clock-activity-2000ms.log`
- `raw/slave-program.log`
- `raw/master-program.log`
- `raw/experiment-manifest.txt`
- `raw/raw-sha256.txt`
