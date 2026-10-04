# Same-image initial-acquisition diagnostic with Main readback

2026-10-04. Goal is the inconsistent initial TIME_VALID acquisition, not
another gain candidate or an easier accuracy gate. Prior turn made progress:
identical FPGA configuration plus one complete159s startup trace and300s
retention passed, but the failed boot's actual phase target was never saved.

Baseline: root controls/3117input manifest418bb254, /2 acquisition,/12
tracking, legacy60/120, Main Kp300/Ki1, physical step16, Master bootstrap2048
and account64. Firmware and FPGA payloads must remain identical. Both root
and milestone failed/success records remain preserved. No advisor or power
cycle, no frozen milestone or protected archive modification.

Only observational executable changes: optional passive Main F4L subset in
the existing startup reader plus a bounded wrapper. It reads the existing
source-proven F4L v1 magic/schema/publication/source epochs, update identity,
generation/producer and phase_shift_current. Separate guard and timestamps;
no bank snapshot request, new mapping, functional firmware/RTL changes or
claims of atomic servo/Main pairing. The source's current value is captured
before the MPLL invocation's one-unit shifter advance, not physical phase.

Laptop edits/tests/push → Pain exactpull →20s live smoke on existing hardware,
no program. Require at least3 trusted Main frames and actual update progress.
Only a successful smoke allows the one replay: root native tests, actual
build/full Master/Slave compiles,3117pre/postinput checks and known RBF hashes
BEFORE one established Slave→Master programming pair. No order/clock/control
changes. Capture original300s arming/600s maximum acquisition/firstTRACK,
including passive Main frames about every4 rows and at firstTRACK.

After reader releases JTAG, issue only existing readonly `pll stat`/`pll gps 0`
on both boards, preserving actual current/target and calibration scan replies.
No calibration query unsupported by this legacy firmware. Health/current/
target/servo publications are separately timed, not atomic measurements.
If valid time is reached, qualify300s unchanged in this same boot. If not,
leave the unfavorable boot running for further passive diagnosis; no retry.

Immediate stop for source/image mismatch, another JTAG owner, reset/generation
change, hardware/reader stop conditions or persistent invalid data. Partial
data remain evidence, not PASS.20s live smoke is not startup or300s validation.

Questions: does Main update/phase_current progress while acquisition waits?
Do readonly current/target converge to the expected requested SETP quantization?
Does the negative≤−131072ps conversion overflow appear? If executed targets
settle normally but CKO remains out-of-band, that narrows toward timestamp/
phase/calibration path; it does NOT prove a specific physical cause. Save
unfavorable data before any further program. Laptop raw/checksum verification,
report/products push, Pain exactsync complete this round.
