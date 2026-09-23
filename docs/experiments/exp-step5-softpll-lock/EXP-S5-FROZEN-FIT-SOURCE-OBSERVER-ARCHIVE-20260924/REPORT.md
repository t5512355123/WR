# EXP-S5-FROZEN-FIT-SOURCE-OBSERVER-ARCHIVE-20260924

## Purpose

This is a provenance-only archive for the existing frozen-fit Step5 A/B
experiment. It preserves the source files and observer scripts that were
present only in Pain's old checkout, without changing or extending the
experiment's result. The associated experiment remains
[`EXP-WRPC-STEP5-HPLL-6208-128-FROZEN-FIT-KP-MINUS300-VS-MINUS301-MIF-ONLY-AB-600S-20260902.md`](../EXP-WRPC-STEP5-HPLL-6208-128-FROZEN-FIT-KP-MINUS300-VS-MINUS301-MIF-ONLY-AB-600S-20260902.md):
Step4B was revalidated, but neither A nor B reached Helper lock, so this is
not a Step5 pass milestone.

## Checkout audit

The source was Pain's `/home/b10504072/04_WR` checkout at
`f847f4e74c5b16389c9848d4fe2592a9873a6b5c`, branch
`exp/step5-softpll-lock`. It was compared by Git blob identity with the clean
`feat/file_cleanup` checkout at `dda9ececa8697e570c7fc3afccdc320897c462f1`.

```text
UNTRACKED_REGULAR_FILES=490
EXACT_CONTENTS_ALREADY_TRACKED=468
PATH_ABSENT_BUT_CONTENT_TRACKED_ELSEWHERE=92
UNIQUE_FILE_COPIES=22
DISTINCT_UNTRACKED_CONTENTS=7
NESTED_WORKTREE_DIRECTORY_ENTRIES=15
```

The 22 unique copies consist of five distinct source files repeated across
four staged/canonical source trees, plus two different observer Tcl scripts.
One copy of each source file is kept here. Four project-layout files (`.qpf`
and `.sdc`) are also retained so the source directory is structurally
complete; their contents were already tracked elsewhere in the repository.
The other 468 exact-content duplicates were not copied again.

## Preserved files and SHA-256

The source snapshot is the `canonical-004f439-before-mif` tree from
`artifacts/exp-step5-frozen-fit-20260902`; the original `canonical-7585a06`
rollback and two `staging-88604a5` trees contain byte-identical copies of the
five source files listed below. The observer scripts are retained as found.

| Preserved path under `raw/` | Original size | SHA-256 |
| --- | ---: | --- |
| `source/DE5a_wr_master_jtag.qpf` | 1,319 | `0885ab6140e881bb747dbade7ec3dc9af834c3e54cb690891b812e83a02e7e01` |
| `source/DE5a_wr_master_jtag.qsf` | 36,296 | `6d28fc359e96aac128490afbc8487d8efab730f22b1a071c5fb8d0fa5e6a5a38` |
| `source/DE5a_wr_master_jtag.sdc` | 396 | `921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b` |
| `source/DE5a_wr_master_jtag.vhd` | 72,265 | `0fe191ad963cc5c5fea4eeb57a240d3d0dff4d730753bf6ace908870ec5ec0e7` |
| `source/DE5a_wr_slave_jtag.qpf` | 1,318 | `e8f6d590ebf5c8fec62e47b768a371b3d4e2c8a017490f9e775d227343ddc3f3` |
| `source/DE5a_wr_slave_jtag.qsf` | 36,257 | `2d86e2eef4c1ebc28c5e5b8e1df4485f61afb925724b8aeb4086501ed9beeb5c` |
| `source/DE5a_wr_slave_jtag.sdc` | 396 | `921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b` |
| `source/DE5a_wr_slave_jtag.vhd` | 86,344 | `f818185046e3220ab9a4d2e9a5948a793a763585a02570026e9dd40c79738b9e` |
| `source/si5340a_controller_dco.v` | 29,133 | `04a664b9f74c777809488a9f6edb45bb2fc26ec14e0c4add6101b52a280eaea5` |
| `observer/observer-kp300.tcl` | 94,183 | `5c0e91627e2688d083c49aafd55dbcc6558b20514461f307737261abcd834927` |
| `observer/observer-kp301.tcl` | 94,183 | `41ccaeed1ebd7ecb2d27c2f3699ecc11303d48243a9b24289d5436c37a2aba9d` |

Every destination file was SHA-256 checked against its Pain source after
transfer. Files are byte-preserved without whitespace normalization,
including the trailing spaces in Quartus-generated project license headers.
No SOF or MIF is included in this archive; binaries remain governed by the
separate milestone-artifact retention policy.
