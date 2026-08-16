# Status Probe Bit Mapping（狀態 probe bit 對照）

這個 16-bit status vector 是除錯用 bit vector，不是用來識別 Master/Slave 或板卡身份的 code。

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

`0x82CF` 表示 `si_config_done=1`、`phy_ready=1`、`tm_link_up=1`、`link_ok=1`、`time_valid=0`、`pps_valid=0`、`rx_ready=1`、`tx_ready=1`，沒有回報 encoding error，且 CPU reset 已解除。

## 0xA2C3

`0xA2C3` 表示 link/status bits 與 0x82CF 不相同；依照此 mapping，包含 `rx_enc_err=1`。這個值曾在較早的非對稱除錯實驗中觀察到。

`0x82CF` 不是 Master code，`0xA2C3` 也不是 Slave code；兩者都只是除錯用 bit vector。
