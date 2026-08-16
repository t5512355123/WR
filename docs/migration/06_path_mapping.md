# Laptop / pain Path Mapping

| Original location | New source-of-truth location | Classification |
|---|---|---|
| Laptop `04_White_Rabbit/week02/v01` | `04_WR` | preserved legacy source/reference; source-of-truth folder renamed on 2026-08-16 |
| pain `/home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag` | `quartus/rs422_uart_diag` | canonical Quartus projects |
| pain `.../vendor/wr-cores` | `vendor/wr-cores` | vendored source snapshot |
| pain `.../vendor/wr-cores-arria10` | `vendor/wr-cores-arria10` | vendored Arria 10 source snapshot |
| pain `.../vendor/wrpc-sw` | `vendor/wrpc-sw` | vendored firmware source snapshot |
| pain `.../firmware` configs | `firmware/configs` | firmware build inputs |
| pain `.../work_wrphy_full` | `generated/work_wrphy_full` | required generated Quartus input |
| pain `.../si5340_controller` | `rtl/clock/si5340_controller` | clock-control source |
| pain `.../jtag_wb_diag`, `clock625_jtagwb_diag`, DCO/simplewa/etc. | `archive/diagnostics/...` | legacy diagnostic source |
| pain output/MIF/SOF/reports | `artifacts/EXP-...` | milestone evidence |
| old experiment record | `docs/experiments/legacy_實驗紀錄.md` | immutable historical record |

The original paths remain available and are not replaced by the new mapping.
