# EXP-S5-MAIN-FREQ-THRESH20-F4L-DIAGNOSTIC-GATE-20260920

## Verdict

```text
THRESH20_CONTROL_PRESERVATION = PASS
F4L_DIAGNOSTIC_OWNER           = PASS
MASTER_RUNTIME_GATE            = PASS
SLAVE_LINK_GATE                = PASS
SLAVE_HELPER_GATE              = NOT_READY_HELPER
MAIN_RUNTIME_GATE              = NOT_READY_HELPER
F4L_THRESH20_FORMAL            = NOT_ALLOWED
STEP5                          = NO
STOP_REASON                    = SLAVE_SEQ_WAIT_HELPER
```

本輪只建立 fresh threshold20 + F4L diagnostic image 的 direct runtime gate；
依既定停止條件，沒有執行 120 秒 F4L formal，也沒有修改 PI、gain、threshold、
timeout、bootstrap、arbiter、mailbox、PHY、reset、RTL 或 SDB。

## Source and offline validation

```text
source commit = 00d7572fa4943dbba1e28b2245f884fc04386a94
branch        = exp/step5-softpll-lock
```

唯一新增的 firmware identity 差異是 Master/Slave：

```c
#define DE5A_F4L_MAIN_PHASE_DIAG 1
```

控制設定保留：

```text
Slave Main frequency threshold = 20
Master Main frequency threshold = 50
Main Kp                        = 300
frequency Ki                   = 1
phase Ki                       = 0
frequency boost                = 20
frequency lock samples        = 50
phase threshold/samples       = 1200/1000
bumpless preload               = ON
```

離線測試結果：

```text
test_step5_threshold20.py                 = PASS
test_step5_f4l_threshold20_owner.py       = PASS
test_step5_f4l.py                         = PASS
tests                                     = 10 passed
bundled Python exit                       = 0
git diff --check                           = PASS
```

## Build and programming

```text
clean build                               = PASS
JTAG_F4L_STEP5_BUILD                      = PASS
Slave SOF SHA256                          = c6a533740edcd74422cc472dc8980cb233731a1de2f9c6459205dcd04494eafa
Master SOF SHA256                         = 1ca7209388a74b6b207f0d3875ef5486a54ca3942d4d1dbba411d43b7a2b3e5f
Slave WNS                                 = -0.361 ns
Master WNS                                = -0.289 ns
```

```text
Slave cable  = DE5 [1-11.2]
Master cable = DE5 [1-11.1]
JTAG_F4L_SCHEDULE_OBSERVABILITY_PROGRAM = PASS
```

The known timing closure caveat remains; this observability-only change did not
close timing.

## Direct runtime capture

Command executed once after programming:

```text
quartus_stp -t scripts/jtag/read_wb_runtime.tcl --raw
```

```text
quartus_exit = 0
runtime raw SHA256 = 050352d3fbe0c2c45d57edf623a55ae2e6b85d0e01f70b361c2996960bd72ea1
```

### Master DE5 [1-11.1]

```text
Step1 PHY/link                  = PASS
Step2 Endpoint/PTP              = PASS
Step4A event chain               = PASS
spll_main_limits                = 00320032
BOOT_GENERATION delta            = 0
CPU_RESET_COUNT delta            = 0
WR_CORE_RESET_COUNT delta        = 0
SI_CONFIG_DROP_COUNT delta       = 0
RXERR delta                      = 0
```

The Master is not the Step5 closed-loop subject in this capture.

### Slave DE5 [1-11.2]

Infrastructure and WR handshake were healthy:

```text
CORE_TM_LINK_UP                  = 1
CORE_LINK_OK                     = 1
PHY/link gate                    = PASS
PSTAT link                       = 1
Step3 WR handshake                = PASS
parentCalibrated                 = 1
LOCK_ENABLE                      = 1
RXERR delta                      = 0
BOOT_GENERATION delta            = 0
CPU_RESET_COUNT delta            = 0
WR_CORE_RESET_COUNT delta        = 0
SI_CONFIG_DROP_COUNT delta       = 0
JTAG/WB transport                = TRUSTED
PRELOAD_PROTOCOL_RUNTIME_REVALIDATION = PASS
```

The limiting state was upstream of Main:

```text
SPLL_STATE                       = 00030004
SPLL_SEQ_STATE                   = 4 (SEQ_WAIT_HELPER)
SPLL_HELPER_LOCKED               = 0
SPLL_MAIN_STATE                  = 00000000
MAIN_ENABLED                     = 0
spll_main_limits                 = 00320014
WDIAGS_PTP                       = 8 (UNCALIBRATED)
```

The raw helper shadow advanced during the read window, but it did not establish
the required locked state. Therefore Main startup and F4L phase observability
were not reached in a valid operating gate.

## Interpretation and stop decision

The compile-time identity and threshold20 control preservation passed. The
physical/link and WR-parent gates also passed. The direct runtime gate is still
not ready because the Slave remained in `SEQ_WAIT_HELPER` with Helper unlocked.

The dashboard's `WDIAGS_PTP=UNCALIBRATED` is recorded as a symptom of the
unfinished SoftPLL startup, not used as the sole causal diagnosis; the raw
sequence state directly identifies the current boundary as Helper acquisition.

```text
F4L_THRESH20_RUNTIME_GATE = NOT_READY_HELPER
F4L_THRESH20_FORMAL       = NOT_ALLOWED
STEP5                     = NO
```

Stop here. Do not run formal F4L on this capture and do not infer a phase-domain
result. The next action must address the bounded Helper-acquisition boundary
before another Main/F4L comparison is allowed.

## Evidence files

- `raw/build/firmware-image-manifest.txt`
- `raw/build/sof-manifest.txt`
- `raw/program/program-manifest.txt`
- `raw/observe/direct_runtime.log`
- `raw/observe/direct_runtime.log.sha256`
