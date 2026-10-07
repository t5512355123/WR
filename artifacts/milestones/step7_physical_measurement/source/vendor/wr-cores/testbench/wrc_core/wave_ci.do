onerror {resume}

add wave  /main/DUT/PERIPH/rst_n_i
add wave  /main/DUT/rst_net_n
add wave  /main/DUT/rst_wrc_n
add wave  /main/DUT/clk_sys_i
add wave  /main/clk_ref
add wave  /main/DUT/phy_tx_data_o
add wave  /main/DUT/phy_tx_k_o
add wave  /main/phy_rbclk
add wave  /main/DUT/phy_rx_data_i
add wave  /main/DUT/phy_rx_k_i
add wave  -group WRPC_EP /main/DUT/U_Endpoint/src_o
add wave  -group WRPC_EP /main/DUT/U_Endpoint/src_i
add wave  -group WRPC_EP /main/DUT/U_Endpoint/snk_o
add wave  -group WRPC_EP /main/DUT/U_Endpoint/snk_i
add wave  -group WRPC_EP /main/DUT/U_Endpoint/U_Wrapped_Endpoint/regs_fromwb
add wave  -group WRPC_EP /main/DUT/U_Endpoint/U_Wrapped_Endpoint/regs_towb
add wave  -group WRPC_EP /main/DUT/U_Endpoint/U_Wrapped_Endpoint/pfilter_done_o
add wave  -group WRPC_EP /main/DUT/U_Endpoint/U_Wrapped_Endpoint/pfilter_drop_o
add wave  -group WRPC_EP /main/DUT/U_Endpoint/U_Wrapped_Endpoint/pfilter_pclass_o
add wave  -group WRPC_EP /main/DUT/U_Endpoint/wb_i
add wave  -group WRPC_EP /main/DUT/U_Endpoint/wb_o
add wave  -group EP_PCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_clk_i
add wave  -group EP_PCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_data_o
add wave  -group EP_PCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_k_o
add wave  -group EP_PCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_disparity_i
add wave  -group EP_PCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_enc_err_i
add wave  -group EP_PCS -height 16 /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_state
add wave  -group EP_PCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_fab_i
add wave  -group EP_PCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_busy_o
add wave  -group Minic /main/DUT/MINI_NIC/src_i
add wave  -group Minic /main/DUT/MINI_NIC/src_o
add wave  -group Minic /main/DUT/MINI_NIC/wb_i
add wave  -group Minic /main/DUT/MINI_NIC/wb_o
add wave  -group Minic -height 16 /main/DUT/MINI_NIC/U_Wrapped_Minic/ntx_state
add wave  -group Minic /main/DUT/MINI_NIC/U_Wrapped_Minic/tx_fifo_d
add wave  -group Minic /main/DUT/MINI_NIC/U_Wrapped_Minic/tx_fifo_empty
add wave  -group Minic /main/DUT/MINI_NIC/U_Wrapped_Minic/tx_fifo_full
add wave  -group Minic /main/DUT/MINI_NIC/U_Wrapped_Minic/tx_fifo_q
add wave  -group Minic /main/DUT/MINI_NIC/U_Wrapped_Minic/tx_fifo_rd
add wave  -group Minic /main/DUT/MINI_NIC/U_Wrapped_Minic/tx_fifo_we
add wave  -group Minic /main/DUT/MINI_NIC/U_Wrapped_Minic/tx_status_word
add wave  -group EP /main/EP/snk_ack_o
add wave  -group EP /main/EP/snk_adr_i
add wave  -group EP /main/EP/snk_cyc_i
add wave  -group EP /main/EP/snk_dat_i
add wave  -group EP /main/EP/snk_err_o
add wave  -group EP /main/EP/snk_rty_o
add wave  -group EP /main/EP/snk_sel_i
add wave  -group EP /main/EP/snk_stall_o
add wave  -group EP /main/EP/snk_stb_i
add wave  -group EP /main/EP/snk_we_i
add wave  -group EP /main/EP/src_ack_i
add wave  -group EP /main/EP/src_adr_o
add wave  -group EP /main/EP/src_cyc_o
add wave  -group EP /main/EP/src_dat_o
add wave  -group EP /main/EP/src_err_i
add wave  -group EP /main/EP/src_in
add wave  -group EP /main/EP/src_out
add wave  -group EP /main/EP/src_sel_o
add wave  -group EP /main/EP/src_stall_i
add wave  -group EP /main/EP/src_stb_o
add wave  -group EP /main/EP/src_we_o
add wave  -group EP /main/EP/regs_fromwb
add wave  -group EP /main/EP/regs_towb
add wave  -group EP /main/EP/wb_ack_o
add wave  -group EP /main/EP/wb_adr_i
add wave  -group EP /main/EP/wb_cyc_i
add wave  -group EP /main/EP/wb_dat_i
add wave  -group EP /main/EP/wb_dat_o
add wave  -group EP /main/EP/wb_in
add wave  -group EP /main/EP/wb_out
add wave  -group EP /main/EP/wb_sel_i
add wave  -group EP /main/EP/wb_stall_o
add wave  -group EP /main/EP/wb_stb_i
add wave  -group EP /main/EP/wb_we_i
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/dreq_pipe
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/pcs_busy_i
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/snk_i
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/snk_o
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/pcs_fab_o
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/pcs_dreq_i
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/ep_ctrl_i
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/pcs_error_i
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/fab_pipe
add wave  -group DUT->EP-TXpath /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_Tx_Path/pcs_fab_o
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/an_tx_en_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/an_tx_en_synced
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/an_tx_val_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/clk_sys_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_almost_empty
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_almost_full
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_clear_n
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_empty
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_enough_data
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_fab
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_packed_in
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_packed_out
add wave  -group DUT->EP-TxPCS -height 16 /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_state
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_rd
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_ready
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_wr
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/mdio_mcr_pdown_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/mdio_mcr_pdown_synced
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/mdio_wr_spec_tx_cal_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_busy_o
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_dreq_o
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_error_o
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_fab_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_clk_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_data_o
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_disparity_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_enc_err_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_k_o
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/rmon_tx_underrun
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/rst_n_i
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/timestamp_trigger_p_a_o
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_busy
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_catch_disparity
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_cntr
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_cr_alternate
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_error
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_is_k
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_odata_reg
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_odd_length
add wave  -group DUT->EP-TxPCS -height 16 /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_state
add wave  -group DUT->EP-TxPCS /main/DUT/U_Endpoint/U_Wrapped_Endpoint/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_rdreq_toggle
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/an_tx_en_i
add wave  -group EP->txPCS -height 16 /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_state
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/an_tx_en_synced
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/an_tx_val_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/clk_sys_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_almost_empty
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_almost_full
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_clear_n
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_empty
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_enough_data
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_fab
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_packed_in
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_packed_out
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_rd
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_ready
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/fifo_wr
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/mdio_mcr_pdown_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/mdio_mcr_pdown_synced
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/mdio_wr_spec_tx_cal_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_busy_o
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_dreq_o
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_error_o
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/pcs_fab_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_clk_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_data_o
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_disparity_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_enc_err_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/phy_tx_k_o
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/rmon_tx_underrun
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/rst_n_i
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/timestamp_trigger_p_a_o
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_busy
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_catch_disparity
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_cntr
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_cr_alternate
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_error
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_is_k
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_odata_reg
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_odd_length
add wave  -group EP->txPCS /main/EP/U_PCS_1000BASEX/gen_8bit/U_TX_PCS/tx_rdreq_toggle
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/clk_sys_i
add wave  -group DUT->MUX -height 16 /main/DUT/U_WBP_Mux/demux
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/dmux_others
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/dmux_sel
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/dmux_sel_zero
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/dmux_select
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/dmux_snd_stat
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/dmux_status_reg
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/ep_snk_i
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/ep_snk_o
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/ep_snk_out_stall
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/ep_src_i
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/ep_src_o
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/ep_stall_mask
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/g_muxed_ports
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux_class_i
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux_cycs
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux_rrobin
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux_select
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux_snk_i
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux_snk_o
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux_src_i
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/mux_src_o
add wave  -group DUT->MUX /main/DUT/U_WBP_Mux/rst_n_i
null TreeUpdate [null SetDefaultTree]
wv.cursors.add -time {402323834470 fs} -name {Cursor 2}
null configure wave -namecolwidth 363
null configure wave -valuecolwidth 163
null configure wave -justifyvalue left
null configure wave -signalnamewidth 1
null configure wave -snapdistance 10
null configure wave -datasetprefix 0
null configure wave -rowmargin 4
null configure wave -childrowmargin 2
null configure wave -gridoffset 0
null configure wave -gridperiod 1
null configure wave -griddelta 40
null configure wave -timeline 0
null configure wave -timelineunits ns
update
wv.zoom.range -from {1202933155800 fs} -to {1203674570090 fs}

