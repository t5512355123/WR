# EXP-S5-QSFPB-F4M-FIRMWARE-REBUILD-20260917

## Verdict

**STOPPED — Pain build-script portability failure; no hardware result.**

This round did not reach Quartus compilation, programming, or F4M observation.
It therefore provides no Step5 pass/fail evidence and does not change the
QSFP-B PHY conclusion.

## Boundary reached

Pain successfully pulled laptop commit `b288f14d` and ran both firmware builds.
The new Slave and Master MIFs were generated, and the build manifest captured
their hashes:

```text
Slave MIF  ee99ed1d9c042593dd1ed23d63f6eee67a5867565c319ed57ea2e929abf8a421
Master MIF 5a7f7a662b6535138f1076b108682dbaeb8c57ec03e211ad6bc4700d4ae55e1a
```

The firmware identity hashes were the expected current files:

```text
Slave identity  aa283a28dd201ec2a547f5804b91ab8b1771d8e0d7b6c83a90bcc726f039a546
Master identity 90c32a0b4084150db93031666b95ebed568105e691b10dcdbaf398c5c7f152ee
```

The experiment helper then stopped at its compile-time marker check:

```text
scripts/pain/pain_build_portb_step5.sh: line 40: rg: command not found
```

No SOF was generated in this round, no programmer was invoked, and no board
state was changed after the previous F4M run.

## Cause and correction

The laptop helper used `rg` for a local marker check, but the Pain environment
does not provide `rg`. This is an execution-environment issue only. The next
iteration will replace that check with a POSIX/basic-tool check available on
Pain, then rerun the same firmware rebuild and QSFP-B compile/program/F4M
sequence. No PI, gain, threshold, timeout, bootstrap, arbiter, mailbox,
detector, DAC ordering, PHY, reset, RTL, SDB, or observer-control change is
authorized by this result.

## Raw evidence

- [firmware build logs](raw/build)
- [PLAN.md](PLAN.md)

## Step5 status

```text
QSFP-B prerequisite = previously PASS
F4M firmware-rebuild boundary = STOPPED_BEFORE_COMPILE
Step5 = NOT ASSESSED / NOT PASS
```

