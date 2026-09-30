# Source-backed WDIAGS field contract

Audit baseline: `8bd7c5ee87dfa04875eb88446aa6064a02e2202b`.
This is a read-only source audit; it does not establish that a live frame is
coherent. Line numbers below refer to the baseline source tree.

| Field / offset | All source writers and aliases found | Owner / update timing | Existing protection and contract disposition |
|---|---|---|---|
| `STATE` / `WDIAG_TEMP`, `0x04c` | `wdiags_write_temp()` from boot/startup checkpoints in `wrc_main.c:204,219,251,505,512,517,527`; periodic `wdiags_write_wr_state_debug()` from `task-diags.c:225`. Both helpers write the same register in `dev/wdiags.c:848-857`. The DE5a defconfigs disable `CONFIG_TEMP_SENSORS`; the temperature-task call at `task-diags.c:596` is therefore inactive on the pinned DE5a configurations. | Startup markers own it before the diagnostics task; active DE5a WR state owns it in the periodic task (tag `0xA...`). | Active state writer is called while `DATA_VALID` is lowered, but there is no explicit barrier bracketing its write. Startup values are outside that periodic publication. A captured `0xA...` tag identifies the intended current writer, not commit ordering. Candidate EVENT field only; not currently trusted. |
| `RX`, `0x064` | `wdiags_write_wr_signaling_debug()` at `dev/wdiags.c:903-912`; one runtime caller at `task-diags.c:226`. | Periodic diagnostics writer. | Call is inside the periodic task's DATA_VALID-low/high interval. No explicit publication fence around the interval. Candidate EVENT field only; not currently trusted. |
| `TX`, `0x068` | Same writer and caller as `RX`; register aliases are `WDIAG_SERVO_UPTIME_MSB/LSB` in `wrc_diags_regs.h:409-412`. | Periodic diagnostics writer. | Same as RX. Candidate EVENT field only; not currently trusted. |
| `A8C` / private lock-result word, `0x08c` | `wdiags_write_wr_lock_debug()` writes literal offset `0x8c` at `dev/wdiags.c:924-935`; one runtime caller at `task-diags.c:237`. The private words are within the 128-word WDIAGS DPRAM configured at `wrc_periph.vhd:73,489-492`; `0x8c` has no named standard-map alias in `wrc_diags_regs.h`. | Periodic diagnostics writer. | Inside the periodic DATA_VALID interval, but no explicit publication fence. The address is a private literal, so the observer contract preserves the literal offset/aperture audit. Candidate EVENT field only; not currently trusted. |
| `CKO`, `0x040` | `wdiags_write_servo_state()` writes `WRC_DIAGS_WDIAG_CKO` at `dev/wdiags.c:384-402`; periodic caller at `task-diags.c:573`. | Periodic servo-state diagnostic writer. | DATA_VALID is low around the periodic task, but the generation marker is written earlier at `task-diags.c:365`, before this field at `:573-580`. No fence proves write visibility. Candidate PHASE field only; not currently trusted. |
| `SETP`, `0x044` | Same function/caller as CKO; macro in `wrc_diags_regs.h:379`. | Periodic servo-state diagnostic writer. | Same as CKO. |
| `UCNT`, `0x048` | Same function/caller as CKO; macro in `wrc_diags_regs.h:382`. | Periodic servo-state diagnostic writer. | Same as CKO. A changing UCNT alone cannot certify its neighboring CKO/SETP payload without a generation covering all three. |
| `SSTAT`, `0x008` | Periodic `wdiags_write_servo_state()` at `dev/wdiags.c:394`; immediate `wdiags_write_wr_extension_disable_debug()` at `:860-900`, called from `ppsi/fsm.c:341,383` and `ppsi/proto-ext-whiterabbit/common-fun.c:95`. | Periodic servo status plus asynchronous first-disable context writer. | Excluded from EVENT/PHASE frames. Read as its own timestamped raw word; do not join to A6C or a frame. Only the defined first-disable context is sticky; the full word is not. |
| `A6C` / `SERVO_RESTART_COUNT`, `0x06c` | Periodic `wdiags_write_wr_signaling_debug()` at `dev/wdiags.c:903-912`; immediate first-disable writer at `:894-900`, same call sites as SSTAT. | Periodic counters plus asynchronous first-disable record. | Excluded from EVENT/PHASE frames. Read independently. Bit 11 is the first-disable-valid stop guard; the entire word is not sticky. |
| Old mapping marker / inverse, `0x134/0x138` | `wdiags_write_mapping_self_test()` at `dev/wdiags.c:1024-1039`, called at `task-diags.c:365`; aliases `WDIAG_MAPPING_COUNTER/INVERSE` in `wrc_diags_regs.h:85-86` overlap `HELPER_PI_SNAPSHOT_BANK_COMMIT_COUNT/OVERWRITE_COUNT` at `:30-31`, written by PI snapshot ACK/overlay paths at `wdiags.c:1256-1264` and initialized at `:1618-1621`. | Mapping self-test before the PI snapshot request; frozen-bank overlay owns the same words after `wdiags_helper_pi_snapshot_v2_active` is set (`wdiags.c:97,372`). | Not a publication sequence for the complete candidate frame: it is advanced before the phase fields, and it can be frozen/reassigned to the PI overlay. Complementary words do not prove ownership or CPU/DPRAM/JTAG order. Do not use as a commit generation. |
| DATA_VALID / snapshot control, `CTRL=0xA04` | `wdiag_set_valid()` writes control at `dev/wdiags.c:319-323`; periodic low/high calls at `task-diags.c:138,602`. | Periodic publisher / diagnostic reader control. | `writel()` is a volatile store only (`include/hw/rawmem.h`). The endpoint readback does not issue `fence iorw, iorw`. DATA_VALID may transition `1→0→1` between host reads. Endpoint equality cannot prove no intervening publication. |

## Audit conclusion

The current writer/caller/address-alias table is source-complete for the fields
above (`field_writer_contract_complete=true`, `writer_aliases_complete=true`).
The existing software does **not** provide a generation that covers every
candidate payload field, does **not** prove CPU-to-DPRAM-to-JTAG publication
ordering, and does **not** bound all possible marker increments during a
60-second observer window. Therefore the live-frame contract remains blocked:

```text
PUBLICATION_PROTOCOL_PROVEN = false
SEQUENCE_OWNER_PROVEN       = false
ABA_EXCLUDED_FOR_60S        = false
LIVE_OBSERVER_AUTHORIZED    = false
```

A future candidate can use an odd/even dedicated publication generation that
brackets all frame writes, with a fence before commit, plus a verified
non-aliased sequence/inverse location. The address is intentionally not chosen
here: it first needs an explicit source/RTL map audit. A fence alone is not
sufficient because it does not detect a complete publication that occurs
between the host's endpoint reads.
