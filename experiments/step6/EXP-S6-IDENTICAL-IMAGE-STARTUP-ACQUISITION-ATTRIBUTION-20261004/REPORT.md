# Same-configuration acquisition diagnosis — live baseline completed

2026-10-04, Asia/Taipei. This report preserves the success before a controlled
replay; the original inconsistent-startup question is NOT yet resolved.

## Current result

`CURRENT_LIVE_TIME_VALID_300S = PASS`; `DETERMINISTIC_STARTUP = NOT_ESTABLISHED`;
`PHYSICAL_CAUSE_OF_CKO_BOOT_VARIATION = NOT_YET_IDENTIFIED`.

Today a new user-triggered root programming is recorded: Slave ended08:11:07,
Master08:11:26. SOFs33e58bf4/fa5e4d2c are exact qualified main-root artifacts.
The08:16:42 preflight had both TIME_VALID/PPS_VALID1, Slave five locks1,
TRACK_PHASE, CKO−104ps. This is not midnight's failed boot recovering later.

After Laptop observer/analyzer/tests push(fcdb3f6d), Pain exactpull, no build,
programming, reset, control changes or competing reader occurred during this
live-baseline capture. Read-only preservation is intentional: do not destroy
the now-successful boot before recording it. Current root source manifest
418bb254 contains3117 input files; all checked. Milestones and the protected
04_WR_archive_step6_pass path were not modified.

## Formal retention evidence

Raw folder: `raw/20261004T003029Z-live/`. Observer began08:30:29,
formal303s-per-board acquisition used the unchanged TIME_VALID verifier;
complete live wrapper ended08:41:07.

| Board | TIME_VALID rows | observed span | largest gap | complete DONE |
|---|---:|---:|---:|---|
| Master1-11.1 |1190/1190|302900ms|257ms|303155ms|
| Slave1-11.2 |1190/1190|302880ms|257ms|303134ms|

Both PPS/snapshot/link diagnostics1190/1190, live time monotonic. Board
captures are sequential, not proof of simultaneous global-time equality.
No sampled invalid rows; complete sample indexes and DONE counts verified.
Laptop independently reran the analyzer with300000ms/1000ms-gap/301-min-rows
and recovered the identical result. Raw SHA2565af80714; result85c83f0d.

## Source-proven distinction between acquisition and retention

In the actual unchanged wrh-servo.c, WAIT_OFFSET_STABLE enables timing only
when the full offset magnitude is strictly<60ps. TRACK's>120ps fallback
returns to SYNC_PHASE without clearing the previously enabled timing output.
wrpc_enable_timing_output and the PPS ESCR valid bits retain that state until
an actual disable/reset path. Five SoftPLL lock bits do not enable timing
by themselves. Existing native-C22cases exercise that exact source policy.

15s phase/context smoke:24raw rows,20trusted,4guard rejections,15unique UCNT
updates,0conflicting same-UCNT payloads. All20 trusted health observations
had TIME_VALID1, while15had abs(CKO)>120ps. CKO−516..+412ps; DMS173734..174343ps;
SETP−5444..−5262ps. Unique statesSYNC3/TRACK2/WAIT10. Three consecutive-UCNT
SYNC→WAIT actions matched the actual CKO/2 arithmetic, including negative
truncation. This proves software arithmetic, not physical actuator response.
Health and phase groups are separately sampled, not atomic hardware events.

The earlier independent midnight rebuild had BYTE-IDENTICAL FPGA RBF
payloads yet failed both600s readiness attempts: SlaveTIME_VALID0, five locks1,
WAIT_OFFSET_STABLE and dashboard CKO−2353/−2460ps. Those captures remain
failures of initial acquisition, not failures of300s retention after entry.
Different SOF metadata does not explain them; the RBF configuration is equal.
The new valid boot does not overwrite or reverse those failed outcomes.

## Next bounded diagnostic, not a gain sweep

After this evidence/report is pushed: Pain exactpull, existing root firmware
build/full two-board compile, all3117input checks and RBF byte/hash comparison
BEFORE programming, one Slave→Master program, then single-reader startup
CKO/SETP/DMS/UCNT/state/health trace. Capture ends at first TRACK or deadline;
observer invalidity is INCONCLUSIVE, not a hardware verdict. If time becomes
valid, qualify300s in the same boot. No production changes, forced validity,
automatic reprogram retries, advisors or archive promotion.

Laptop27offline analyzer/source tests passed; replay shell syntax passed.
All15transferred files are checksum-matched in live-transfer.sha256. No causal
claim of jitter, calibration, timestamp or DCO failure is made without the
next acquisition/actuator evidence. The diagnostic goal remains active.
