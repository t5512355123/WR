# Exact paired return timestamp provenance

Baseline3dd3604d completed the coherent16-update timestamp round. Action-free
UCNT192→193→194 showed ~8.2ns raw return jumps and ~4.2ns CKO jumps; fixed
delays and phase writes stayed unchanged. Strict300s remains NOT_ESTABLISHED.
Source msg_pack_delay_resp uses only fractionalns correction_field; inspect
the Master receive timestamp and its accepted remote representation next.

## Only change

Root observer/analysis/tests and current experiment metadata. NO firmware,
RTL, PI/Ki/gain, calibration, counter, reset, threshold or PHY changes.
Normal/2 acquisition,/12tracking and live strict60/120 gates remain identical.
No advisors; frozen milestones and Pain protected archive remain untouched.

One observer pre-drains both UARTs and queries ONLY live `mac get`. Source
state-initializing derives EUI64 by insertingfffe into current MAC (not its
fallback). Slave `pll ts4 0`, then Master `pll rxts 0` requests are sent BEFORE
draining either reply. Both existing page outputs fit the actual1024-byte
VUART FIFO including shell echo/CRLF/prompt; native/layout tests check bounds.
This creates potential overlap, NOT simultaneous/cycle-atomic acquisition.
Only exact sequence/identity/full-time pairs prove actual overlap.

Then read the SAME complete Master32record/Slave16record frozen histories.
No second page0, retry, reader or calibration command. Whole actual deadline
360s, each reply read maximum30s. Keep every query/request interval and raw
reply hex. Both links/PLL gates and Master time bracketed repeatedly, stable
reset generations. Slave time may be invalid while diagnosing acquisition.

## Prespecified data gates

Full32 Master RX records and16 accepted Slave TS4 updates, no dropped/changed
pages, all source/domain/port identities consistent with live queried MACs.
Actual Master linearizer math reproduces. Exact matching DelayResp/DelayReq
sequence+domain selects peer pairs, independent of Sync sequence. Full signed64
seconds/scaled-ns conversions: Master's recorded linearized RX must EQUAL
Slave's accepted raw-before-WR-delta T4, not merely correlate within8ns.
At least8 matched accepted updates and4consecutive UCNT+1 paired differences.
Incomplete/untrustworthy pairing is INCONCLUSIVE, never patched after capture
by relaxing bounds or joining distant histories. Missing matches stay missing.

For large CKO jumps, decompose raw return = (Master coarse RX−Slave raw T3)
+ Master linearization correction. Record raw phase, ahead, falling/rising,
active T24P, pre/current phase writes and fixed deltas. This isolates which
digital representation moved; does not prove hardware accuracy or analog skew.
No large transition inside overlap means cause not evaluated, not stability PASS.

## Workflow / stops

Laptop edit/test/push -> Pain ff pull/native regressions -> root build_current
and compile_current (same pinned firmware, one fresh pair) -> program_current
once -> dashboard/20s health smoke; if locks settling, ONE bounded120s startup
observation -> one paired capture ->20s strict postflight. Extend to a genuine
300s goal only after fresh<60ps entry with no retention violation in postflight.
No image/source mismatch, reset, link/lock/Master-time loss, bank conflict or
persistently invalid data tolerated; save reason and stop that capture.
Returned products/raw/hash verification -> Laptop REPORT/push -> Pain ff sync.
No automatic tuning at end. Step6 goal remains strict300s, not data-only PASS.
