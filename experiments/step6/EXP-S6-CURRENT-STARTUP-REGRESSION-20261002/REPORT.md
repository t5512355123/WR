# Current rebuild startup regression — 2026-10-02

## Verdict

`CURRENT_STARTUP_REPRODUCIBILITY = NOT_ESTABLISHED`

`CURRENT_SESSION_TIME_VALID_300S = NOT_REACHED`

This read-only investigation does not invalidate the earlier recorded 300-second
capture. It does invalidate treating that capture as a guarantee that every
fresh build/program will acquire valid time. No production control, validity
bit, EEPROM calibration, gain, threshold, reset or FPGA image was changed during
this investigation. The protected Pain archive was not accessed or modified.

## Current artifacts and state

Pain and Laptop source HEAD at inspection: `6ffa25798892ce895946a1c05edb695c4788179e`.
Pain has generated changes from the user's new build; these were preserved.

User build evidence: previous experiment's
`raw/build/20261002T034011Z-current.vJu5Kz/`; programming evidence:
`raw/program/20261002T034534Z-current-{master,slave}.log`.

| Role | New SOF SHA-256 |
| --- | --- |
| Master | `803d28ea2d1460dd8b0715bce7fc40fcfff29f02c6e8b67e0142714c6c40a03c` |
| Slave | `7a77b464ce9126a4fb074cfa1bf91f37cf7172bd982354cf18ecf93d93cd82e1` |

Both firmware MIF hashes still match the prior successful run. A changed SOF
hash alone does not prove changed placement or identify the cause; build
metadata can also change the file hash.

At 12:05:52 +08:00 the live dashboard reported both links healthy. Master
TIME_VALID/PPS_VALID were 1. Slave Helper, Main frequency, Main phase, Main lock
and PSTAT were all 1, but servo was WAIT_OFFSET_STABLE, offset -394 ps,
TIME_VALID/PPS_VALID 0 and no valid PPS snapshot. Therefore this is not only a
dashboard display issue: PLL lock and PTP time acquisition are distinct gates.

## Passive phase-context capture

Single-reader command on Pain:

```sh
quartus_stp -t scripts/jtag/read_step6_servo_interleaved_offset.tcl 20000 250 '1-11.2' 2
```

Observer summary: 33 rows, 28 phase-observation-valid rows, 0 Global-Time
coherent/qualifying rows; reset_stop=0, timeout_count=0, invalid_count=0.
Phase validity is separate from Global-Time validity; the 28 rows are joined by
UCNT, not assumed to be atomic across all fields. Repeated UCNT rows are not
independent servo updates. State mapping is 3=SYNC_PHASE, 4=TRACK_PHASE,
5=WAIT_OFFSET_STABLE.

Representative accepted rows:

| Observer ms | UCNT hex | State | CKO ps | SETP ps | DMS ps |
| ---: | --- | ---: | ---: | ---: | ---: |
| 0 | 000002C2 | 5 | -426 | 1910 | 172436 |
| 523 | 000002C3 | 5 | 3807 | 1910 | 176204 |
| 1721 | 000002C4 | 5 | 3557 | 1910 | 176454 |
| 6628 | 000002C9 | 5 | -63 | 1910 | 172073 |
| 8624 | 000002CB | 5 | -204 | 1808 | 172215 |
| 9825 | 000002CC | 5 | 3649 | 1808 | 176361 |

CKO and DMS can jump by approximately 4 ns while SETP is unchanged and UCNT
advances. This supports investigating timestamp/coarse-fine reconstruction and
RX phase calibration before attributing the failure to tracking gain. It does
not prove a timestamp bug or establish single-cycle causality. TRACK was not
observed in this short window.

The full runtime reader additionally reported TRUSTED JTAG/WB transport,
TIMEOUT_COUNT=0 and INVALID_COUNT=0. Slave calibration-failure counter was
`0x459` in both before/after snapshots, and lock-unlocked counter was unchanged.
These are accumulated historical events within this boot, not proof that
calibration is failing in the current observation window.

## Next diagnostic boundary

Inspect the actual live T24P transition and RX raw phase/ahead-bit behavior,
including measured versus cached calibration and its applicability to the
fresh image. Keep the acquisition control unchanged until a source-supported
defect is identified. Do not force timing outputs, relabel WAITING as PASS,
or infer that a new gain will repair the observed jumps.

Any repaired candidate must follow Laptop change/test/push, Pain exact-source
build/program, then a fresh guarded 300-second TIME_VALID capture. Historical
PASS and instantaneous PLL lock are not substitutes for that validation.

## Evidence integrity

Raw logs in this folder were copied from Pain, with transfer archive SHA-256:
`a70905179453ec27bfe7bc98d286f0e15fc663dec6c50f5704109d6f913da277`.

- `raw/wr-current-pretrack-20261002.log`: `4688bfc5056a052aeaf8dd1aa997c19e5a9ba99ccd8b49677daca847cbebde9d`
- `raw/wr-current-live-second-20261002.log`: `960423d5d94b4ff0a83e389d728b38d99230a555c42e5c913e7581062f99ada2`
- `raw/wr-current-runtime-20261002.log`: `2b6b0e5fb17692813788aef38039ef50ea05dc99abda9bc789ccd1952268b810`
