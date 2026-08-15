# EXP-BASELINE-RS422

- Date: 2026-08-15
- Build host: `pain`
- Quartus: Prime 17.0 Build 595
- Source status: restored RS422 baseline, then copied into this staging repository
- Git commit: to be filled after the initial source-of-truth commit
- Master project: `quartus/rs422_uart_diag/DE5a_wr_master_rs422.qpf`
- Slave project: `quartus/rs422_uart_diag/DE5a_wr_slave_rs422.qpf`
- Master MIF SHA256: `0d7e79f0a33d82b5afaf850e19c169bb88ea479a58029f9c19b60de561ccb5f2`
- Slave MIF SHA256: `9a9c23628ef235c6cb24376c039120bf06b2dac5d213374fc591e6f5992d1c19`
- Master SOF programmer checksum: `0x3088011E`
- Slave SOF programmer checksum: `0x308FFC95`

## Interpretation

The two baseline bitstreams configured successfully and reported the expected
PHY/PCS link status. The repeated low-16 probe value was `0x82CF` on both ends:
link-up and link-ok were asserted, while `time_valid` and `pps_valid` were not.
Therefore this experiment proves configuration and a link-level baseline only;
it does not prove White Rabbit time synchronization.
