# Status Probe Bit Mapping

The 16-bit status vector is a debug bit vector, not a board identity code.

| Bit | Signal |
|---:|---|
| 0 | si_config_done |
| 1 | phy_ready |
| 2 | tm_link_up |
| 3 | link_ok |
| 4 | time_valid |
| 5 | pps_valid |
| 6 | rx_ready |
| 7 | tx_ready |
| 8 | MOD_PRS_n |
| 9 | INTERRUPT_n |
| 10 | tx_disable |
| 11 | phy_rst |
| 12 | si_id_error |
| 13 | rx_enc_err |
| 14 | tx_enc_err |
| 15 | CPU_RESET_n |

## 0x82CF

`0x82CF` means `si_config_done=1`, `phy_ready=1`, `tm_link_up=1`, `link_ok=1`, `time_valid=0`, `pps_valid=0`, `rx_ready=1`, `tx_ready=1`, no reported encoding errors, and CPU reset deasserted.

## 0xA2C3

`0xA2C3` means the link/status bits are not equivalent to 0x82CF and includes `rx_enc_err=1` under this mapping. It was observed in an earlier asymmetric diagnostic experiment.

`0x82CF` is not a Master code and `0xA2C3` is not a Slave code. They are only debug bit vectors.
