# Laptop / pain 版本比較

產生時間：2026-08-15 21:53:05 +08:00

## 精確相對路徑比較
Laptop 選取檔案：106
pain 選取檔案：4196
相同：59
不同：9
只有 Laptop：38
只有 pain：4128

詳細比較位於 comparison.tsv。系統沒有自動選擇任何一方作為正確版本。

## 重要路徑證據
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

## 初步解讀
- 兩份 inventory 的結構並不相同：pain 包含 Laptop 沒有的許多除錯 project、產生輸出、vendor 原始碼、韌體與 report。
- 遷移前必須檢查相同路徑的精確比對；不能只用較新的 mtime 判定正確性。
- 既有的已知可用 SOF checksum 與實驗紀錄是 pain 端證據，必須作為里程碑 artifact 保留。
