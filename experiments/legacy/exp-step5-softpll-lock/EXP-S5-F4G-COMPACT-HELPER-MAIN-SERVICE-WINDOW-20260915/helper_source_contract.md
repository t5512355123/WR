# F4G helper/L2 source contract preflight

Experiment: `EXP-S5-F4G-COMPACT-HELPER-MAIN-SERVICE-WINDOW-20260915`

This is the required offline source audit before any hardware capture. F4G is
read-only observability; it does not change C/RTL control, PI parameters,
timeouts, bootstrap, arbitration, mailbox state, or reset logic.

## Helper CORE publication

The WDIAGS offsets are defined in
`vendor/wrpc-sw/include/hw/wrc_diags_regs.h`:

| offset | field |
|---:|---|
| `0x100` | publication epoch |
| `0x114` | Helper error |
| `0x118` | Helper update count |
| `0x11c` | Helper output |

`vendor/wrpc-sw/dev/wdiags.c::wdiags_write_wr_spll_helper_measurement_debug`
is the only exact writer found by the source audit for these four fields. It
writes an odd epoch, publishes the payload, executes the publication barrier,
and writes the even commit epoch. `vendor/wrpc-sw/lib/task-diags.c::wrc_wr_diags`
is the caller. The caller first brackets the source RAM snapshot with the
measurement epoch (and the separate PI trace epoch), then passes the accepted
source snapshot to the writer.

The F4G reader therefore accepts Helper CORE only when the two epoch reads are
hex-valid, even, equal, and the three CORE payload words are valid. Every
rejected attempt retains both raw epoch values and all raw CORE words. A CORE
record is never upgraded to the ten-field FULL record.

```text
SOURCE_CONTRACT_VERIFIED=YES
RUNTIME_IMAGE_VERIFIED=REQUIRED_AT_CAPTURE
DYNAMIC_OWNER_VERIFIED=NOT_AVAILABLE
SOURCE_BACKED_CORE=LIMITED
```

The source audit found no competing exact writer for the Helper measurement
offsets in `vendor/wrpc-sw`. That supports the limited source-backed CORE
interpretation, but it does not prove the running FPGA image or the runtime
owner of the shared WDIAGS overlay. F4G must verify board identity and image
runtime evidence before interpreting the capture. If a runtime competing
writer is found, the capture is stopped as `OWNER_UNRESOLVED`.

## L2 service telemetry

The existing DE5a RTL source
`quartus/jtag_runtime_diag/si5340a_controller_dco.v` defines the diagnostic
payloads as follows. The low 32-bit half is Main and the high 32-bit half is
Helper unless noted otherwise.

| probe | payload | source semantics |
|---:|---|---|
| `52` | status | live pending/transaction/error state |
| `53` | pending | rising-edge count of Main/Helper pending bits |
| `54` | service start | one logical transaction start at `runtime_start` rising edge with `rt_state==1` |
| `55` | completed | success count at the completed `dco_step_count` boundary |
| `56` | failed | failure count at the same completed boundary when ACK/timeout evidence is present |
| `57` | maximum wait | maximum observed pending-to-start wait |
| `58` | current wait | live wait for a currently pending request |
| `59` | maximum latency | maximum start-to-completion latency |
| `60` | failure events | ACK-error events / timeout events |
| `61` | first loss | sticky first-loss time, owner, and reason |

The counters are 32-bit live counters. The RTL exposes the fields through
combinational 64-bit payloads; there is no shared epoch covering probes 52–61
and no atomic multi-probe snapshot. F4G therefore reads each probe as its own
timed word, retains the packed raw value, and computes deltas only between two
trusted reads of the same counter field. It never subtracts a `start` read from
a `completed` read taken over a different interval and never claims all ten
probes were one atomic sample.

```text
L2_COUNTER_WIDTH_BITS=32
L2_COUNTER_SOURCE_SEMANTICS=VERIFIED
L2_MULTI_PROBE_ATOMICITY=NOT_AVAILABLE
L2_DELTA_POLICY=SAME_FIELD_TRUSTED_READS_ONLY
```

## F4G runtime gate

The runtime observer must report:

- role identity (`DE5 [1-11.1]` Master and `DE5 [1-11.2]` Slave),
- link/status/PTP/WR state, boot generation and reset counters,
- Helper and Main producer records with independent validity/freshness,
- separately timed L2 words, and
- one active source-probe reader process at a time.

`OWNER_UNRESOLVED`, identity mismatch, a reset/generation change, a second
reader, three consecutive true core transport failures, or ten seconds with
no usable Main/Helper core ends the run. Optional position or Master position
error reads do not invalidate the WR core. This file is a preflight contract;
it is not evidence that Step5 has passed.
