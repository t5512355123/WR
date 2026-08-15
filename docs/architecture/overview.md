# Architecture Overview

The DE5a design uses `xwr_core` with an Arria 10 WR PHY. QSFP-A lane 0 carries the White Rabbit Ethernet link. The system also contains SI5340/DCO clock control, a uRV RISC-V soft CPU running wrpc-sw, and PPS output to SMA_CLKOUT.

This repository separates the canonical RS422 diagnostic baseline from legacy experiments. The reorganization changes file ownership and build paths only; it does not alter the WR datapath.
