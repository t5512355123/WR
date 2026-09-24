# EXP-S4-MILESTONE-REPRO-20260924

## Verdict

**STEP4_MILESTONE = PASS**

The standalone frozen Step 4 source was clean-built for Master and Slave,
programmed to the two DE5a boards, and passed the Step 4A/4B runtime
acceptance after one planned read-only settling retry. Step 5 lock was not
achieved in this capture and is not a Step 4 acceptance requirement.

## Source provenance and identity

- Historical source origin: `a1980bff30231376a3182486fd786d906876c2d4`.
- Frozen package/repository commit used on Pain: `393f402c6af420b45e9ffa1f0b936cdfd017982c`, branch `feat/file_cleanup`.
- Historical experiment: `experiments/legacy/exp-step5-softpll-lock/EXP-S5-F4B-ARBITRATION-CONTROL-20260915/`.
- Historical Master SOF SHA-256: `ae017c25ca628f7c7d35636d27079f85e8f5543aa8f712e122f984f5a6932400`.
- Historical Slave SOF SHA-256: `ec4be4bd6390ce2cbe3c603c99b337fb501d60da37e58c2cf2b5bfca1de5f092`.
- Frozen source manifest: `artifacts/milestones/step4_softpll_startup/source/SOURCE_SHA256SUMS`.
- Historical-source audit: 3,181 historical source files checked, zero mismatches. Three firmware build-orchestration wrappers are reported separately as reproduction infrastructure. The source package manifest covers all files in the frozen package.

The package relocates the historical JTAG projects and generated inputs into
the cleaned repository layout. It does not change functional HDL, firmware,
vendor sources, or generated IP. Historical hashes are provenance only; the
rebuilt image hashes below are the images actually programmed and validated.

The only historical project-file content changes are relative-path
relocations. The frozen-package SHA-256 values and original Git blob IDs are:

| Relocated file | Historical Git blob | Frozen-package SHA-256 |
|---|---|---|
| `quartus/DE5a_wr_master_jtag.qsf` | `d6cd8fb9ce16d0e9579a4d02a009f5197ce3afa6` | `fd1987020915a229286cf71da8703ebb7c1424e87b0cb5a51ce36809a4800d0e` |
| `quartus/DE5a_wr_slave_jtag.qsf` | `44eae8c1a39ff8dee0a8836a107bea96abcb8cc5` | `c1359b1fa9f354e3e2fa14397f6806269cc3a47a4ce554f8d66b02ea72cb728c` |
| `quartus/DE5a_wr_master_jtag.vhd` | `8a76a6c9245fb268e90988020fbb5d885bf786ed` | `5b859ac3b3ec8affa44d6e81f556b278d79ff3fc7c86469a10ac7c80d2300a7d` |
| `quartus/DE5a_wr_slave_jtag.vhd` | `ce21c0da031e0237f6e3f9ea6e6398a4e214b7f9` | `63429975c53ff6ada6afe7e0159d82b981f5ac2c91031eafc6402f413627f5c1` |

The three firmware build-orchestration wrappers were adapted only for portable
invocation and disposable-workspace line-ending normalization; their historical
blob IDs and frozen-package SHA-256 values are listed by
`raw/build/step4-candidate/source-identity-verification.log`. No runtime
firmware or functional RTL source was changed.

## Build

- Build host: Pain.
- Quartus: Version 17.0.0 Build 595, 04/25/2017, Standard Edition.
- Master clean full compilation: PASS.
- Slave clean full compilation: PASS.
- Firmware Master/Slave MIF generation: PASS.
- Raw logs and build identity: `raw/build/step4-candidate/`.
- As a separate repository-cleanup check, the current root JTAG Master and
  Slave projects were also clean full-compiled successfully. Those root-source
  outputs were not programmed and are not used to claim this milestone;
  records are under `raw/build/current-root/`.

The first firmware-build attempt exposed Windows-checkout CRLF handling in
Kconfig/defconfig plus child scripts lacking executable bits. The build
wrappers were corrected before the successful build: invoke child scripts
through Bash and normalize line endings only in disposable Linux build
workspaces. Frozen firmware source bytes remain unchanged. The initial failed
attempt logs are retained under
`raw/build/step4-candidate/firmware-first-attempt/`.

| Image | MIF SHA-256 | Rebuilt SOF SHA-256 | Full compile |
|---|---|---|---|
| Master | `1571b052cc9f4d28eaa94a7f5f58f2f50bf508acbad60071294dd065273cab56` | `55cb04191f3e0793623a55ada6c9e842b6d92d26ba196f1b057c5d5595d57717` | PASS |
| Slave | `60d2b3e7f282535722d250ce1cf579487001bcc748c98fe549b5a440033ce9e9` | `b6b87623d8c7cb4660a04e97bd7a0ce5792783fdd3e6d04a64880307bb26612e` | PASS |

The rebuilt SOFs are saved at the milestone root and their hashes are also
listed in the milestone `SHA256SUMS`.

Timing was not closed: worst setup slack was -0.047 ns (Master) and -0.268 ns
(Slave). This is recorded as a limitation, not represented as timing PASS and
not used as a Step 4 functional gate. Quartus also reported unconstrained
clocks and input/output paths; see each `build_info_*.txt` and STA report.

## Programming

Programming order followed the candidate's recorded procedure: Master, wait
approximately 45 seconds, then Slave.

- Master: cable `DE5 [1-11.1]`; configuration succeeded.
- Slave: cable `DE5 [1-11.2]`; configuration succeeded.
- Logs: `raw/program/master-program.log` and `raw/program/slave-program.log`.

## Runtime validation

The initial read-only preflight found Master Step 1/2 ready, but Slave PTP was
not yet calibrated, so the Slave Step 2 gate and Step 4B gate were not ready.
Following the plan, the boards were left programmed and a single 60-second
settling interval was allowed before repeating the read-only capture. No
reset, power-cycle, PTP restart, or Wishbone write was issued.

The successful retry is preserved in
`raw/observe/preflight-retry-60s.log`.

| Acceptance check | Master | Slave |
|---|---|---|
| Step 1 PHY/link | PASS; link, RX/TX readiness, TM link and core link healthy | PASS; same |
| Step 2 endpoint/PTP | PASS; Master mode/PTP state and traffic counters advance | PASS; Slave mode/PTP state and traffic counters advance |
| Step 3 WR handshake | Not applicable to Master role | PASS; foreign master, WR parent/calibration, LOCK and SLAVE_PRESENT observed; `LOCK_ENABLE=4` |
| Step 4 startup gate | Step 4A event chain PASS | `STEP4B_ALLOWED=YES`, `STEP4B_RESULT=PASS`, first inactive boundary `ACTIVE`; mode SLAVE, `SPLL_INIT_COUNT=1`, `SPLL_SEQ_STATE=6 (SEQ_WAIT_MAIN)` |

All required event counters advanced over the before/after observation:

| Counter delta | Master | Slave |
|---|---:|---:|
| DMTD accepted | 46,796 | 46,162 |
| TAG valid | 23,439 | 46,189 |
| TRR write | 23,440 | 46,194 |
| TRR pop | 23,242 | 45,709 |
| IRQ | 23,242 | 43,982 |
| Helper update | 23,242 | 22,887 |

For both boards, boot generation, CPU reset count, WR-core reset count, and
SI-configuration-drop count had zero delta. Link remained up; PTP traffic
counters advanced and RX error deltas were zero. JTAG/Wishbone diagnostics
reported `PRELOAD_PROTOCOL_RUNTIME_REVALIDATION=PASS`,
`JTAG_WB_DIAGNOSTIC_PATH=TRUSTED`, and zero timeout/invalid transactions.

The capture reads registers sequentially rather than atomically. Positive
counter deltas establish that each stage was active during the observation;
they do not establish same-cycle causality between different counters. The
Slave diagnostic also reports a cumulative WR timeout/failure field in its
snapshot; the Step 3 decoder passed the required current parent/signaling
checks, and the cumulative field is retained as a caveat rather than described
as zero.

## Step 5 and known limitations

- Step 5 result in this capture: `NEVER_LOCKED`; first inactive boundary:
  `MAIN_PHASE_LOCK`. This does not negate Step 4 PASS.
- Global time was not evaluated by this Step 4 reproduction.
- Timing closure is NO; no timing-clean claim is made.
- Physical SMA/output edge skew is not evaluated.

## Reproduction artifacts

- Frozen source: `artifacts/milestones/step4_softpll_startup/source/`.
- Rebuilt/programmed Master SOF: `artifacts/milestones/step4_softpll_startup/master.sof`.
- Rebuilt/programmed Slave SOF: `artifacts/milestones/step4_softpll_startup/slave.sof`.
- Build/program/runtime raw evidence: this experiment's `raw/` tree.
- File integrity: this experiment's `SHA256SUMS`.
