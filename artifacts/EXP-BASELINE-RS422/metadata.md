# EXP-BASELINE-RS422

Experiment ID: `EXP-BASELINE-RS422`
Date: 2026-08-15
Git commit: unavailable; this is a pre-Git legacy baseline
Git branch: unavailable
Build host: `pain`
Quartus version: Prime 17.0 Build 595

Master top: `quartus/rs422_uart_diag/DE5a_wr_master_rs422.vhd`
Slave top: `quartus/rs422_uart_diag/DE5a_wr_slave_rs422.vhd`
Master project: `quartus/rs422_uart_diag/DE5a_wr_master_rs422.qpf`
Slave project: `quartus/rs422_uart_diag/DE5a_wr_slave_rs422.qpf`
Master QSF SHA256: `7cc3c418ce161276a0cf152cd863832188e29eb2057ded878f813df54f2fbe94`
Slave QSF SHA256: `d4c31818c5334d9612d894afd5c46a5cddfbf5312be2b76f18ec0fc73dab2ff3`
Master SDC SHA256: `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
Slave SDC SHA256: `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`

Master MIF: `master.mif`
Slave MIF: `slave.mif`
Master MIF SHA256: `0d7e79f0a33d82b5afaf850e19c169bb88ea479a58029f9c19b60de561ccb5f2`
Slave MIF SHA256: `9a9c23628ef235c6cb24376c039120bf06b2dac5d213374fc591e6f5992d1c19`
Master SOF: `master.sof`
Slave SOF: `slave.sof`
Master SOF SHA256: `9238740e35f2b48915d1fa7ee6d2dca9d443438f197f1226720dde9dd5e1892b`
Slave SOF SHA256: `44251d6911c021e0d6fb12083034ec870a7d06a4374e435d27caa5e9efb36f15`
Master SOF programmer checksum: `0x3088011E`
Slave SOF programmer checksum: `0x308FFC95`

QSFP port: QSFP-A
Lane: 0 active; other lanes held inactive in the preserved top
Word alignment: preserved RS422 baseline; no new alignment change
TX pre-emphasis First Post-Tap: 18 in the preserved QSF assignments
clk_ref: 125 MHz nominal
clk_dmtd: 124.992 MHz nominal
clk_sys: 50 MHz nominal
Firmware mode: legacy Master / Slave MIF pair
Probe mapping version: `docs/debug/probe_bits.md`, low-16 status vector

## Interpretation

The two baseline bitstreams configured successfully and reported the expected
PHY/PCS link status. The repeated low-16 probe value was `0x82CF` on both ends:
link-up and link-ok were asserted, while `time_valid` and `pps_valid` were not.
Therefore this experiment proves configuration and a link-level baseline only;
it does not prove White Rabbit time synchronization.

Result Master: PASS for configuration and PHY/PCS link; synchronization unproven
Result Slave: PASS for configuration and PHY/PCS link; synchronization unproven
time_valid: 0 in the recorded probe
pps_valid: 0 in the recorded probe
Timing closed: not evaluated for this legacy artifact set
