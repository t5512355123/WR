# Dashboard console summary (not a raw capture)

Session: one read-only dashboard/JTAG reader, `INTERVAL_SECONDS=5`,
`OBS_GAP_MS=1000`.

- Started `2026-09-30 21:52:20 +08:00`.
- At the planned 600-second deadline (`22:02:20`), the first visible sample
  after the deadline (`22:02:21`) showed Slave `WAIT_OFFSET_STABLE`, offset
  `−956 ps`; `TRACK_PHASE` had not been reached.
- The session was interrupted at approximately `22:04:37`, about 737 seconds
  after start. This exceeded the 600-second limit by approximately 137 seconds.
- Final visible sample (`22:04:33`): Master Step 1/2/4 PASS, Global Time
  VALID, TAI 819, cycles 124999999. Slave Step 1–4 PASS; Helper=1,
  MainFreq=1, MainPhase=1, MainLock=1, PSTAT=1; servo state
  `WAIT_OFFSET_STABLE`; offset `−712 ps`; Step 6 WAITING and Global Time
  invalid because offset was not below 60 ps.
- No `TRACK_PHASE` was observed. Do not treat the listed samples as a complete
  time series or infer exact extrema/counts.
- Ctrl+C stopped the reader. The wrapper then reported its temporary
  `capture.log` missing and `quartus_stp_rc=130`; therefore no complete raw
  dashboard log is available in this experiment folder.

This file is a human-authored summary of visible terminal output, not an
unaltered hardware capture.
