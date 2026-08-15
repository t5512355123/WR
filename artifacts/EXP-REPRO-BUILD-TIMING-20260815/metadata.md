Experiment ID: `EXP-REPRO-BUILD-TIMING-20260815`
Date: 2026-08-15
Git commit: `0a8f44afa5b26111a1103903968bf173e210ee92`
Git branch: `main`
Build host: `pain`
Quartus version: Prime 17.0 Build 595

Master top: `quartus/rs422_uart_diag/DE5a_wr_master_rs422.vhd`
Slave top: `quartus/rs422_uart_diag/DE5a_wr_slave_rs422.vhd`
Master QSF SHA256: `7cc3c418ce161276a0cf152cd863832188e29eb2057ded878f813df54f2fbe94`
Slave QSF SHA256: `d4c31818c5334d9612d894afd5c46a5cddfbf5312be2b76f18ec0fc73dab2ff3`
Master SDC SHA256: `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
Slave SDC SHA256: `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`

Master MIF SHA256: `598984b3330514a4489139ed60a6b6d67b26c48fff61b23d5544c56d816450cf`
Slave MIF SHA256: `384253c28284c83632e49fbfa72144e78bbc66a7d2351b845baf2dce55ee5970`
Master SOF SHA256: `9a779de65eb0df89de28194e869bbda99b26ba6603ec4af2c539f8e805248d1b`
Slave SOF SHA256: `1849a8a1a446df738be2b6b258c387bc6141d5c8b9f1ea9d2d199b98c5a002a5`

QSFP port: QSFP-A
Lane: 0
Word alignment: preserved RS422 baseline
TX pre-emphasis First Post-Tap: 18, unchanged
clk_ref: 125 MHz nominal
clk_dmtd: 124.992 MHz nominal
clk_sys: 50 MHz nominal
Firmware mode: Master / Slave
Probe mapping version: `docs/debug/probe_bits.md`

Master compile result: PASS, 0 errors
Slave compile result: PASS, 0 errors
Master timing closed: NO
Slave timing closed: NO
Master worst setup/hold/recovery slack: `-3.812 / 0.039 / -1.975 ns`
Slave worst setup/hold/recovery slack: `-3.103 / 0.030 / -1.839 ns`
Unconstrained paths: Master 3 clocks / 1992 input / 83 output; Slave 3 clocks / 2001 input / 83 output

Master probe: not reprogrammed or re-probed in this migration build
Slave probe: not reprogrammed or re-probed in this migration build
Result: BUILD PASS; timing closure and WR time synchronization remain unproven

Notes: The build wrapper records compile success separately from timing closure.
