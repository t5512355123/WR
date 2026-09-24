# EXP-S5-QSFPB-F4M-STARTUP-20260917

## Verdict

**INCONCLUSIVE — Step5 未通過；本輪未取得可判讀的 Main F4L frame。**

這不是 QSFP-B PHY/link failure，也不是 phase-lock failure 的證據。F4M
在約 14.3 秒因 `STOP_DATA_UNRESOLVED` 停止：兩端 WR/PHY 狀態仍有效，
但 Main F4L frame 從未通過 observer 的 schema/transport 驗證，因此不能
對 Main frequency、phase、PI 或 `PSTAT_LOCKED` 做因果判斷。

## Experiment boundary

- Branch: `exp/step5-softpll-lock`
- Laptop/Pain source HEAD: `17d69d8db88bc69f75d20b0b19fd81d81099805d`
- Project: `quartus/jtag_runtime_diag_portb`
- Physical path: QSFP-B lane 0 for WR data and 125 MHz PHY reference;
  QSFP-A remains the 124.992 MHz DMTD reference.
- Observer: existing read-only `f4m`; no firmware/RTL/SDB/control-parameter
  change was made in this round.

## Build and program

Both port-B Quartus builds completed successfully:

- Slave: exit `0`, `0 errors`, `340 warnings`, elapsed `00:04:46`.
- Master: exit `0`, `0 errors`, `339 warnings`, elapsed `00:08:17`.
- Slave program: checksum `0x30B8FA68`, configuration succeeded, exit `0`.
- Master program: checksum `0x30B06CFD`, configuration succeeded, exit `0`.

The SOF SHA-256 values were:

```text
62473c0459535660597f92a93af1ce3ff6dda8c81299722885256c9c2130d603  output_files_slave_portb/DE5a_wr_slave_portb.sof
95c1c8c246e0d13515d8da0c6f65351d80569fc5c2f6395f80b98bd2bca74c77  output_files_master_portb/DE5a_wr_master_portb.sof
```

The manifest found no `.mif` files under the Quartus output directories;
therefore no MIF hash is claimed here. The top-level project references
`../../build/firmware/{slave,master}/wrc.mif` and its identity must be recorded
separately in the next rebuild.

## Preflight and F4M result

The post-program read-only probe was successful:

```text
Master probe_hex: F102606130DC82FF
Slave  probe_hex: 511E74E137BC82EF
```

The decisive low bits show `si_config_done=1`, `phy_ready=1`,
`tm_link_up=1`, `link_ok=1`, `rx_ready=1`, and `tx_ready=1` on both boards.

F4M then produced four Slave cycles and three Master samples. Every Main
diagnostic read had:

```text
MAIN_F4L_VALID=0
TRANSPORT_COHERENT=0
ATTEMPTS=6
UNIQUE_OBSERVATION=0
```

The final observer result was:

```text
session_elapsed_ms=14258
slave_cycles=4
master_samples=3
diag_valid=0
diag_unique=0
page0=0 page1=0 page2=0
run_end_reason=STOP_DATA_UNRESOLVED
step5_complete=NO
step5_pass=NO
merge_approved=NO
```

At the same time, the WR core health samples remained valid. Representative
Slave and Master samples both had `PHY_LINK_USABLE=1`, `PSTAT_LINK=1`,
`BOOT_GENERATION=1`, `WR_CORE_RESET_COUNT=0`, and `SI_CONFIG_DROP_COUNT=0`.
Both had `PSTAT_LOCKED=0`, but that value is not interpretable as a Step5
failure while the Main F4L source frame is unavailable.

## Diagnosis and next boundary

The QSFP-B physical mapping is still healthy. The immediate missing prerequisite
is a Step5-capable firmware image containing the F4L producer, plus an explicit
firmware MIF hash in the experiment manifest. The B images were recompiled, but
this round did not rebuild `build/firmware/{slave,master}/wrc.mif` before the
Quartus compile. Since the F4L producer is firmware-side and the Quartus top
loads those MIFs, a stale MIF can yield exactly this combination: healthy WR
link probes with no valid F4L frame.

Therefore the next experiment must keep the B port mapping and all Step5
controls frozen, rebuild both WRPC firmware images from the pushed identity
headers (`DE5A_F4L_MAIN_PHASE_DIAG=1`), record their hashes, then recompile and
program the same two port-B projects before repeating the same F4M smoke.
Do not sweep QSFP-C and do not tune PI/gain/threshold/timeout from this result.

## Raw evidence

- [PLAN.md](PLAN.md)
- [build logs](raw/build)
- [program logs](raw/program)
- [preflight and F4M observer logs](raw/observe)

