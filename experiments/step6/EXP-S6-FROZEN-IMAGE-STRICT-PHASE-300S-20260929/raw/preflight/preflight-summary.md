# Pain preflight summary

Captured from the Pain terminal on 2026-09-29 before the frozen-image program
sequence. This is a transcription of the preflight results; the programmer and
observation logs are preserved separately as raw files.

- Checkout: `/home/b10504072/04_WR`
- Branch / commit: `feat/file_cleanup` / `bb3ead3c93296c22d682b52eae6f684862c0af58`
- Git tree: `2ccbda8343777c956408f8e5d41abfb8c2044508`
- Worktree was clean before the experiment logs were created.
- Quartus Prime Programmer: 17.0.0 Build 595.
- `quartus_pgm -l` listed both required cables: `DE5 [1-11.1]` and
  `DE5 [1-11.2]`; the inventory command completed with zero errors/warnings.
- No Quartus programmer, JTAG observer, or dashboard process was active before
  programming.
- The Step 6 frozen source manifest and milestone `SHA256SUMS` both verified.
  The source manifest covers 3,219 files; the milestone manifest covers the
  README, both frozen SOFs, and the source manifest.
- Frozen Slave SOF SHA-256:
  `6257952a2aa303b07dcfbd1ca08aa75230af12e412adf176cbbf5a4443bc7450`.
- Frozen Master SOF SHA-256:
  `ad16d364eddbdacbf1aab40bd12154da337f757fbec90e2e216c8e08a0f54901`.

No separate hardware reset or physical power cycle was performed. The FPGA
programming operations themselves reconfigured the two devices.
