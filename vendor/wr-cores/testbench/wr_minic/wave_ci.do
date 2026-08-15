onerror {resume}

add wave  /main/txp_cg_newframe
add wave  /main/rxp_cg_newframe
add wave  /main/txp_cg_size
add wave  /main/rxp_cg_size
add wave  /main/DUT/g_interface_mode
add wave  /main/DUT/g_address_granularity
add wave  /main/DUT/g_buffer_little_endian
add wave  /main/DUT/clk_sys_i
add wave  /main/DUT/rst_n_i
add wave  -group SRC /main/DUT/src_dat_o
add wave  -group SRC /main/DUT/src_adr_o
add wave  -group SRC /main/DUT/src_sel_o
add wave  -group SRC /main/DUT/src_cyc_o
add wave  -group SRC /main/DUT/src_stb_o
add wave  -group SRC /main/DUT/src_we_o
add wave  -group SRC /main/DUT/src_stall_i
add wave  -group SRC /main/DUT/src_err_i
add wave  -group SRC /main/DUT/src_ack_i
add wave  -group SNK /main/DUT/snk_dat_i
add wave  -group SNK /main/DUT/snk_adr_i
add wave  -group SNK /main/DUT/snk_sel_i
add wave  -group SNK /main/DUT/snk_cyc_i
add wave  -group SNK /main/DUT/snk_stb_i
add wave  -group SNK /main/DUT/snk_we_i
add wave  -group SNK /main/DUT/snk_stall_o
add wave  -group SNK /main/DUT/snk_err_o
add wave  -group SNK /main/DUT/snk_ack_o
add wave  -group TXTSU /main/DUT/txtsu_port_id_i
add wave  -group TXTSU /main/DUT/txtsu_frame_id_i
add wave  -group TXTSU /main/DUT/txtsu_tsval_i
add wave  -group TXTSU /main/DUT/txtsu_ack_o
add wave  -group WB /main/DUT/wb_out
add wave  -group WB /main/DUT/wb_in
add wave  -group TX_PATH -height 16 /main/DUT/ntx_state
add wave  -group TX_PATH -unsigned /main/DUT/ntx_ack_count
add wave  -group TX_PATH /main/DUT/ntx_flush_last
add wave  -group TX_PATH /main/DUT/tx_fifo_d
add wave  -group TX_PATH /main/DUT/tx_fifo_q
add wave  -group TX_PATH /main/DUT/tx_fifo_we
add wave  -group TX_PATH /main/DUT/tx_fifo_rd
add wave  -group TX_PATH /main/DUT/tx_fifo_empty
add wave  -group TX_PATH /main/DUT/tx_fifo_full
add wave  -group TX_PATH /main/DUT/txf_ferror
add wave  -group TX_PATH /main/DUT/txf_fnew
add wave  -group TX_PATH /main/DUT/txf_data
add wave  -group TX_PATH /main/DUT/txf_type
add wave  -group TX_PATH /main/DUT/ntx_stored_dat
add wave  -group TX_PATH /main/DUT/ntx_stored_type
add wave  -group TX_PATH /main/DUT/irq_tx
add wave  -group TX_PATH /main/DUT/irq_tx_ack
add wave  -group TX_PATH /main/DUT/irq_tx_mask
add wave  -group TX_PATH /main/DUT/ntx_newpacket
add wave  -group RX_PATH /main/DUT/regs_out
add wave  -group RX_PATH -unsigned /main/DUT/RX_FIFO/count_o
add wave  -group RX_PATH -height 16 /main/DUT/nrx_state
add wave  -group RX_PATH /main/DUT/nrx_sof
add wave  -group RX_PATH /main/DUT/nrx_eof
add wave  -group RX_PATH /main/DUT/rxf_data
add wave  -group RX_PATH /main/DUT/rxf_type
add wave  -group RX_PATH /main/DUT/rx_fifo_we
add wave  -group RX_PATH /main/DUT/rx_fifo_q
add wave  -group RX_PATH /main/DUT/rx_fifo_rd
add wave  -group RX_PATH /main/DUT/rx_fifo_empty
add wave  -group RX_PATH /main/DUT/rx_fifo_full
add wave  -group RX_PATH /main/DUT/rx_fifo_afull
add wave  -group RX_PATH /main/DUT/irq_rx_ack
add wave  -group RX_PATH /main/DUT/irq_rx
null TreeUpdate [null SetDefaultTree]
wv.cursors.add -time {40485000000 fs} -name {Cursor 1}
null configure wave -namecolwidth 208
null configure wave -valuecolwidth 100
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
wv.zoom.range -from {0 fs} -to {15051471750 ps}

