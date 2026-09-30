# EXP-S6-OBSERVER-PUBLICATION-TIMESTAMP-VALIDATION-20261001

## Objective and boundary

Offline-only source-contract audit, observer-policy validation, adversarial
tests, and replay of the last five rejected WDIAGS frames. The aim is to decide
whether the current telemetry can ever support a trustworthy phase-offset
sample. This does not test the PLL, servo, or 300-second Step 6 milestone.

The fixed source baseline is `8bd7c5ee87dfa04875eb88446aa6064a02e2202b` on
`feat/file_cleanup`. `PUBLICATION_ORDER_PROOF=NOT_ESTABLISHED`,
`LIVE_OBSERVER_AUTHORIZED=NO`, and the Step 6 offset verdict remains
`NOT_ESTABLISHED` throughout this experiment.

## Immutable inputs

- Repository: <https://github.com/t5512355123/WR>
- Branch: `feat/file_cleanup`
- Source baseline: `8bd7c5ee87dfa04875eb88446aa6064a02e2202b`
- Prior raw replay source: `EXP-S6-WR-REARM-TO-STABLE-WINDOW-TRACE-20261001`
- Prior raw SHA-256: `FADEA77FF4CB3C435DC581D131DDC763C3BD4D6B7BA63E056D00F05CD5E9AE7B`

The old raw log and all existing source are read-only. Do not access or modify
`/home/b10504072/04_WR_archive_step6_pass/`.

## Allowed and prohibited actions

Only this experiment directory may be edited: its plan/report, source-field
contract, offline Tcl/Python policy copies, fixtures, tests, and analysis
outputs. Source and RTL may be inspected read-only.

No live JTAG/WB read, dashboard, firmware or Quartus build, programming, reset,
power-cycle, or production/common-reader/RTL/build-source/SOF edit is allowed.
The existing mapping marker is not a valid whole-frame commit sequence, and a
candidate patch written here is not deployment evidence or authority to build.

## Source-derived field boundaries

`analysis/SOURCE_FIELD_CONTRACT.md` enumerates each proposed field's address,
all writers/callers found, aliases, owner/update timing, and current protection.
The field table is complete for the listed fields, but that does not make the
existing DATA_VALID/mapping pair a coherent frame protocol.

Proposed group membership is only a candidate schema:

| Candidate group | Fields | Present source limitation |
|---|---|---|
| EVENT | `STATE`, `RX`, `TX`, `A8C` | Writers are in the periodic task, but the current mapping marker precedes some payload writes; DATA_VALID has no explicit ordering fence. |
| PHASE | `CKO`, `SETP`, `UCNT` | Marker updates at `task-diags.c:365`, before phase writes at `:573-580`; no generation covers the whole payload. |
| Independent status | `SSTAT`, `A6C` | Immediate extension-disable paths also write these words; each must remain a separately timestamped raw observation, never joined to a frame or to each other. |

The existing `0x134/0x138` mapping words are aliased by the Helper PI snapshot
bank after a request, and the self-test marker is written before phase data.
`DATA_VALID=1` at both endpoints cannot detect a complete `1→0→1` publication
between host reads. `writel()` is a volatile store; the DATA_VALID setter's
readback is not a CPU-to-DPRAM-to-JTAG ordering proof. The existing nominal
100 ms task cadence alone does not exclude low-16-bit wrap/ABA in a 60-second
window because the scheduler catch-up bound is not established.

## Offline policy contract

The Tcl policy and Python analyzer must run the same synthetic frame vectors
and the same five legacy raw frame vectors. A trusted candidate frame requires:

- a complete, source-audited odd/even publication generation that covers every
  payload field; equal, committed generation and valid inverse at both ends;
- known publisher ownership and no active/frozen overlay;
- `DATA_VALID=1`, `DATA_SNAPSHOT=0` at both endpoints;
- exact candidate-group membership; all field reads valid, individually
  timestamped, monotonic, and fully within their own frame guard interval;
- at least 10 distinct committed generations per group, plus a forward UCNT
  change for PHASE.

`SSTAT` and `A6C` remain individual raw status records. A6C bit 11 set on the
first read means a pre-existing sticky first-disable record; set later means a
new stop event. The rest of either status word is not assumed sticky.

Timed-read field names are normalized explicitly: the legacy source key
`WR_STATE_RAW_READ_*` maps to canonical `STATE_READ_*`, with equivalent aliases
for RX and TX. A missing value, `-1`, backwards time, or reversed interval is
invalid—not a usable event timestamp.

## Required offline checks and PASS criteria

All checks must pass before this offline experiment can be called validated:

1. Source table accounts for every writer/caller and overlapping address owner
   of each proposed field. Any unlisted writer remains a blocker.
2. A synthetic positive control is accepted by both Tcl and Python, while
   adversarial vectors are rejected identically for publication-crossing,
   DATA_VALID low, snapshot active, inverse mismatch, unknown/frozen owner,
   wrong field membership, invalid/missing/nonmonotonic timestamps, duplicate
   UCNT conflict, status-record timing, first-disable sticky guard, wrap/reset,
   timeout, and strict `±60 ps` boundaries.
3. The same five archived raw attempts replay through both frame validators.
   Expected result: five candidates rejected, zero trusted PHASE frames,
   stable 300-second window not started, servo/offset verdict
   `NOT_ESTABLISHED`.
4. Existing raw files remain byte-for-byte unchanged; the recorded SHA-256
   still matches.
5. The analyzer never turns synthetic acceptance into a hardware/Step 6 pass.

Offline validation may pass while source publication proof remains
`NOT_ESTABLISHED`. Mock tests prove reject/accept policy only; they do not prove
hardware ordering.

## Stop rule and future boundary

Unknown writer/alias/owner, unproven generation coverage/order/ABA, Tcl/Python
disagreement, an accepted torn-frame counterexample, or a scope breach means
record the exact gap and stop. No live observer or build/program is authorized
by this experiment.

A future source change, if separately authorized, would need a dedicated
non-aliased sequence (address still unselected) that brackets all candidate
payload writes, explicit ordering barriers before commit, and a demonstrated
owner/version/read-collision contract. Adding only a fence is insufficient:
it cannot reveal an entire publication that occurred between endpoint reads.

Even after a future telemetry contract is proven, Step 6 requires fresh,
unique, trusted phase updates spanning 300 seconds with strict
`-60 < CKO < 60 ps`, maximum accepted sample gap 1 second, and valid lock/time
conditions. This offline experiment cannot satisfy that milestone.
