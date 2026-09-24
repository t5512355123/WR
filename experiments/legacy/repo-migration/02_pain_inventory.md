# pain 資料清查

產生時間：2026-08-15T21:50:54.406815+08:00
Root：/home/b10504072/04_White_Rabbit

## 範圍
pain_manifest.tsv 會記錄選取的原始碼、韌體、Quartus、script、report、artifact 與文件，包含路徑、大小、UTC mtime、SHA256 與分類。
產生的內部資料夾 db/、incremental_db/ 與 simulation/ 未列入詳細 manifest，但仍保留在原始 tree 與備份中。

## 統計
選取檔案：4196
選取大小：2,551,225,021

依副檔名統計：
.c              830
.vhd            747
.h              724
.sv             349
.py             265
.rpt            264
.v              235
[none]          147
.summary        143
.mk              66
.sh              64
.sdc             60
.sof             59
.qpf             52
.qsf             52
.tcl             34
.qip             30
.log             28
.md              24
.bin             10
.mif              8
.hex              3
.elf              2

## 找到的重要路徑
- DE5a_wr_master.vhd: 2 selected file(s)
- DE5a_wr_slave.vhd: 1 selected file(s)
- jtag_wb_diag: 44 selected file(s)
- clock625_jtagwb_diag: 35 selected file(s)
- simplewa: 249 selected file(s)
- dco: 273 selected file(s)
- sfp: 992 selected file(s)
- runtime: 31 selected file(s)
- loadprobe: 58 selected file(s)
- rs422: 72 selected file(s)
- nosfpmatch: 852 selected file(s)
- staging: not found at pain root
- wrpc-sw: 1632 selected file(s)
- vendor: 3033 selected file(s)
- 實驗紀錄.md: 1 selected file(s)

## Git 根目錄
/home/b10504072/04_White_Rabbit/week02/v01/vendor/wr-cores/.git
/home/b10504072/04_White_Rabbit/week02/v01/vendor/wrpc-sw/.git
/home/b10504072/04_White_Rabbit/week02/v01/vendor/wrpc-sw_nosfpmatch_diag/.git

## 資料夾大小備註
完整 root 約為 4.6G；大型產生資料夾包含 db/、incremental_db/ 與許多除錯輸出資料夾。移動任何資料前請先參閱遷移計畫。
