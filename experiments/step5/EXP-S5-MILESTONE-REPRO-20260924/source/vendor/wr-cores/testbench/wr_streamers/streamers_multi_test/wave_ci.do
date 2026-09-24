onerror {resume}

add wave   sim:/main/current_test
add wave  /main/U_TX_Streamer/tx_valid_i
add wave  /main/U_TX_Streamer/tx_data_i
add wave  /main/U_TX_Streamer/tx_last_p1_i
add wave  /main/U_TX_Streamer/tx_flush_p1_i
add wave   sim:/main/U_TX_Streamer/U_Wrapped_Streamer/fab_src.sof
add wave   sim:/main/U_TX_Streamer/U_Wrapped_Streamer/fab_src.eof
add wave  /main/U_TX_Streamer/tx_frame_p1_o
add wave  /main/U_TX_Streamer/tx_dreq_o
#add wave -noupdate /main/U_TX_Streamer/tx_reset_seq_i
add wave  /main/U_RX_Streamer/rx_frame_p1_o
add wave  /main/U_RX_Streamer/rx_dreq_i
add wave  /main/U_RX_Streamer/rx_valid_o
add wave  /main/U_RX_Streamer/rx_data_o
add wave  /main/U_RX_Streamer/rx_first_p1_o
add wave  /main/U_RX_Streamer/rx_last_p1_o
add wave  /main/U_RX_Streamer/rx_lost_p1_o
add wave   sim:/main/drop_frm
add wave   sim:/main/rx_streamer_lost_frm
add wave   sim:/main/rx_streamer_lost_frm_cnt
add wave  /main/U_RX_Streamer/rx_latency_o
add wave  /main/U_RX_Streamer/rx_latency_valid_o
add wave   sim:/main/rx_streamer_lost_blks
add wave   sim:/main/fab_data_from_tx
add wave   sim:/main/fab_data_to_rx
add wave  /main/mac/adr
#add wave -noupdate /main/mac/dat_o
#add wave -noupdate /main/mac/dat_i
#add wave -noupdate /main/mac/sel
#add wave -noupdate /main/mac/ack
#add wave -noupdate /main/mac/stall
add wave  /main/mac/err
add wave  /main/mac/rty
#add wave -noupdate /main/mac/cyc
#add wave -noupdate /main/mac/stb
#add wave -noupdate /main/mac/we
add wave   sim:/main/delay_link
add wave   sim:/main/tx_wb_cyc
add wave   sim:/main/rx_wb_cyc
add wave   sim:/main/tx_wb_ack
add wave   sim:/main/rx_wb_ack
add wave   sim:/main/rx_wb_stall
add wave   sim:/main/tx_wb_stall
add wave   sim:/main/tx_wb_stb
add wave   sim:/main/rx_wb_stb
null TreeUpdate [null SetDefaultTree]
wv.cursors.add -time {867 ns} -name {Cursor 1}
null configure wave -namecolwidth 150
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
wv.zoom.range -from {0 ns} -to {915 ns}

