# EXP-S6-QSFP-SFF8636-CALIBRATION-FIX-20260927

## Question

Does parsing the installed QSFP module with its SFF-8636 Upper Page 00h
serial-ID layout allow the Slave to load its real calibration record and
produce valid Global Time?

## Evidence and source basis

The previous read-only capture on DE5 [1-11.2] reported:

```text
lower-page identifier = 0x0d
I2C address/offset/read ACK mask = 0x07
fresh lower-page bytes equal cached bytes = yes
legacy SFP checksums at bytes 63/95 = invalid
```

The source implementation had parsed the QSFP+ lower page as an SFF-8472 SFP
header. SFF-8024 identifies `0x0d` as QSFP+ with SFF-8636/SFF-8436 management;
SFF-8636 places serial ID on Upper Page 00h, with part number at bytes
168–183, CC_BASE at 191, and CC_EXT at 223.

References: [SNIA SFF-8024 Rev 4.14](https://members.snia.org/document/dl/26423),
[SNIA SFF-8636 Rev 2.11.32](https://members.snia.org/document/dl/26712).

## Single variable

Add SFF-8636-aware module identification to the frozen Step 6 Slave firmware:

- retain SFF-8472 parsing for SFP identifier `0x03`;
- support SFF-8636 QSFP/QSFP28 identifiers `0x0d` and `0x11`;
- read page-select byte 127 and proceed only if it is already `00h`;
- read Upper Page 00h bytes 128–223 and validate the identifier, CC_BASE,
  and CC_EXT before looking up the true part number in the existing DB;
- never change page select, write the transceiver EEPROM, write SDBFS, or invent
  calibration values.

No PLL/servo parameters, thresholds, reset, PHY, RTL, SDB, or timing constraints
are changed. Master image is not rebuilt or programmed for this experiment.

## Execution

1. Run the focused offline VUART/SFP source-contract tests on Laptop and push
   the source package.
2. Pain fetches that exact commit, builds Slave firmware and the complete
   Slave Quartus project, records both hashes, then programs only DE5 [1-11.2].
3. In one read-only VUART session, run `sfp params live` and verify the QSFP
   identifier, page-select value, upper-page ACKs, matching ID, both checksums,
   and database result. Run the dashboard with no host-side 120-second wait.
4. If the DB match succeeds and Global Time becomes valid, perform the
   established 300-second Step 5 lock and Step 6A stability observation.
5. Copy raw logs/checksums to Laptop, write the experiment report, verify all
   recorded SHA-256 values, and push the report.

## Stop conditions

- Stop without loading calibration if I2C ACKs fail, page select is not `00h`,
  the upper-page identifier differs, either checksum fails, or database lookup
  returns `NO_MATCH`/`ERROR`.
- Do not bypass checksum validation or add a guessed calibration row.
- If the DB match is valid but Global Time remains invalid, record the
  calibration values and servo state and stop before changing any control
  parameter; use that evidence to define the next experiment.

## Acceptance

This is a parser/calibration experiment, not a Step 6 PASS declaration. Step 6
remains incomplete until valid stable Global Time and its existing subsequent
same-PPS / scheduled-trigger criteria are independently satisfied.
