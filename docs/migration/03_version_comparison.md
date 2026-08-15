# Laptop / pain Version Comparison

Generated: 2026-08-15 21:53:05 +08:00

## Exact relative-path comparison
Laptop selected files: 106
pain selected files: 4196
Same: 59
Different: 9
Laptop-only: 38
Pain-only: 4128

The detailed comparison is in comparison.tsv. No side was automatically selected as the winner.

## Important path evidence
- week02/v01/DE5a_wr_master.vhd: Same=1; sample Same:week02/v01/DE5a_wr_master.vhd
- week02/v01/DE5a_wr_slave.vhd: Same=1; sample Same:week02/v01/DE5a_wr_slave.vhd
- week02/v01/DE5a_wr_master.qsf: Different=1; sample Different:week02/v01/DE5a_wr_master.qsf
- week02/v01/DE5a_wr_slave.qsf: Different=1; sample Different:week02/v01/DE5a_wr_slave.qsf
- week02/v01/DE5a_wr_master.sdc: Same=1; sample Same:week02/v01/DE5a_wr_master.sdc
- week02/v01/DE5a_wr_slave.sdc: Same=1; sample Same:week02/v01/DE5a_wr_slave.sdc
- week02/v01/jtag_wb_diag: Pain-only=33, Same=11; sample Same:week02/v01/jtag_wb_diag/DE5a_wr_master_jtagwb.qpf | Same:week02/v01/jtag_wb_diag/DE5a_wr_master_jtagwb.qsf | Same:week02/v01/jtag_wb_diag/DE5a_wr_master_jtagwb.sdc
- week02/v01/clock625_jtagwb_diag: Pain-only=18, Same=17; sample Same:week02/v01/clock625_jtagwb_diag/DE5a_wr_master_jtagwb.qpf | Same:week02/v01/clock625_jtagwb_diag/DE5a_wr_master_jtagwb.qsf | Same:week02/v01/clock625_jtagwb_diag/DE5a_wr_master_jtagwb.sdc
- week02/v01/實驗紀錄.md: Same=1; sample Same:week02/v01/實驗紀錄.md
- week02/v01/wrpc-sw: Laptop-only=5; sample Laptop-only:week02/v01/wrpc-sw/dev/pps_gen.c | Laptop-only:week02/v01/wrpc-sw/include/std/sys/types.h | Laptop-only:week02/v01/wrpc-sw/Makefile
- week02/v01/vendor: Pain-only=3032, Same=1; sample Pain-only:week02/v01/vendor/wr-cores-arria10/ip_cores/general-cores/modules/common/gc_sync_ffs.vhd | Pain-only:week02/v01/vendor/wr-cores-arria10/ip_cores/general-cores/modules/common/gencores_pkg.vhd | Pain-only:week02/v01/vendor/wr-cores-arria10/ip_cores/general-cores/modules/genrams/genram_pkg.vhd
- week02/v01/firmware: Pain-only=4; sample Pain-only:week02/v01/firmware/wrc_de5a_master_nosfpmatch.mif | Pain-only:week02/v01/firmware/wrc_de5a_master.mif | Pain-only:week02/v01/firmware/wrc_de5a_slave_nosfpmatch.mif

## Preliminary interpretation
- The inventories are not structurally equivalent: pain contains many diagnostic projects, generated outputs, vendor sources, firmware and reports absent from Laptop.
- Exact same-path matches must be checked before migration; a newer mtime alone is not treated as correctness.
- The existing known-good SOF checksums and experiment record are pain-side evidence and must be preserved as milestone artifacts.
