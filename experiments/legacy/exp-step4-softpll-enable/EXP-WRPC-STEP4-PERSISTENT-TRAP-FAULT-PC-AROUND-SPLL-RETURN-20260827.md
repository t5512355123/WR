# EXP-WRPC-STEP4-PERSISTENT-TRAP-FAULT-PC-AROUND-SPLL-RETURN-20260827

## 結論

本輪依分支 2 最新指示，在不改變既有 fault handler 停止語意的前提下，加入 `.debug_precrt` persistent trap/fault record，並以正確的 `quartus/jtag_runtime_diag` image 做一次 Master `mode master` 注入與約 35 秒觀測。

最重要結果：兩張板的 fault record 都是空的：

```text
FAULT_MAGIC=00000000
FAULT_COUNT=00000000
FAULT_MCAUSE=00000000
FAULT_MEPC=00000000
FAULT_MTVAL=00000000
FAULT_RA=00000000
FAULT_SP=00000000
```

因此本輪**沒有捕捉到同步 trap/fault**；同步 exception 作為 S4→S5 之間失控原因的假說被削弱，但尚未能證明 CPU 已經正常跨過 caller handoff。

硬體狀態仍重現：

```text
command received       = yes
WB command completion  = yes
SPLL stage 4            = yes
SPLL stage 5            = no
lock-wait substage      = 1
FAULT_COUNT             = 0
ROOT_CAUSE              = NOT_PROVEN
SYNCHRONOUS_TRAP        = NOT_SUPPORTED_BY_THIS_CAPTURE
```

## Experiment setup

- Source/provenance commit: `d87316bea2c189f5d58305d86c8ca740fc501ea2`
- Image role: `quartus/jtag_runtime_diag` Master and Slave images
- Master SOF SHA-256: `d10137cde41b0c2e68bd1c61f6b3823a4351d80c260cfd291d54d7ef38707e9b`
- Slave SOF SHA-256: `6b7b55a39a65356452cec15166ff99c934b7abe634cbb6bbb88d6967c6c8be48`
- Master MIF SHA-256: `f38e130d7ad3adcb0cb3d616809c27bca4499b22e9d461706f5b215dbacf3f27`
- Slave MIF SHA-256: `e4b862d3e422ba795260602474a1c493a2568e194346536b1b3c513a9e87fef4`
- Injection: one VUART command, `mode master`, followed by newline
- Forensics: 60 samples, 500 ms interval; Master and Slave sampled together
- Fault readback: CPU-local `.debug_precrt` words through existing CPU host readback; CPU hold/release only during readback, no reset and no WR/PHY/SPLL writes

The pre-capture baseline was healthy and readable on both boards. Master reported `PTP_STATE=4`, boot-init command index 2; Slave reported `PTP_STATE=4`, boot-init command index 4.

## Observed transition

Before injection, Master was at boot generation 2 with no persistent stage. The command was accepted at sample 5. At sample 6 the current boot generation was 3, while the persistent record still showed the preceding mode-stage history from generation 2:

```text
sample 006:
  BOOT_GENERATION=3
  PERSIST_MODE_MASTER_STAGE=4
  PERSIST_LOCK_WAIT_SUBSTAGE=1
  PERSIST_BOOT_GENERATION_AT_STAGE=2
  PERSIST_CMD_STAGE=9
  PERSIST_CMD_RX_BYTE_COUNT=12

sample 009:
  BOOT_GENERATION=3
  PERSIST_MODE_MASTER_STAGE=4
  PERSIST_LOCK_WAIT_SUBSTAGE=1
  PERSIST_SPLL_CHECK_LOCK_STAGE=4
  PERSIST_SPLL_CHECK_LOCK_BOOT_GENERATION=3
  PERSIST_CMD_RX_BYTE_COUNT=13

sample 060:
  BOOT_GENERATION=3
  PERSIST_MODE_MASTER_STAGE=4
  PERSIST_LOCK_WAIT_SUBSTAGE=1
  PERSIST_SPLL_CHECK_LOCK_STAGE=4
  PERSIST_SPLL_CHECK_LOCK_BOOT_GENERATION=3
  S5=not observed
```

The generation transition is evidence of a re-entry boundary during the command attempt. Since the trap record remained zero, the capture does not support a synchronous exception as the cause of that boundary. A non-trap control-flow event, CPU/Bus wait, or another re-entry mechanism remains possible.

## Trap instrumentation and readback

The trap entry records the original fault context before entering the existing fault-stop path. It records `mcause`, `mepc`, `mbadaddr`/`mtval`, original `ra`/`sp`, boot generation, and the persistent mode/SPLL stages. The original fault behavior remains an infinite fault loop; no recovery, reset, interrupt-mask, or exception-mask behavior was added.

To preserve the proven 110-word WDIAGS map, the new record was not added to normal WDIAGS publication. The dedicated readback script reads the CPU-local persistent words after capture. It completed successfully on both boards, and every fault field was zero.

## Interpretation

The result narrows the next search boundary:

1. `S4=yes / S5=no` remains reproducible.
2. The correct JTAG image accepted the command and stayed readable.
3. The persistent trap record proves no instrumented synchronous trap was entered.
4. Boot generation advanced from 2 to 3 during the command attempt.
5. The next investigation should focus on the re-entry source or a non-trap CPU/Bus handoff/wait condition around the machine-level return boundary, rather than adding more synchronous-fault hypotheses.

Timing is still not closed on this image: worst setup slack is `-0.383 ns` for Master and `-0.307 ns` for Slave. This remains an experimental diagnostic image, not an acceptance image.

## Raw evidence

Raw logs, build provenance, baseline readout, fault readback, hashes, and the full 60-sample forensics capture are in:

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-PERSISTENT-TRAP-FAULT-PC-AROUND-SPLL-RETURN-20260827/`

