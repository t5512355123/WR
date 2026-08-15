onerror {resume}
quiet WaveActivateNextPane {} 0
add wave  /main/U_TX_Streamer/tx_flush_i
add wave  /main/U_TX_Streamer/tx_last_i
add wave  /main/U_TX_Streamer/tx_data_i
add wave  /main/U_TX_Streamer/tx_reset_seq_i
add wave  /main/U_TX_Streamer/tx_valid_i
add wave  /main/U_TX_Streamer/tx_dreq_o
add wave  /main/mac/adr
add wave  /main/mac/dat_o
add wave  /main/mac/dat_i
add wave  /main/mac/sel
add wave  /main/mac/ack
add wave  /main/mac/stall
add wave  /main/mac/err
add wave  /main/mac/rty
add wave  /main/mac/cyc
add wave  /main/mac/stb
add wave  /main/mac/we
add wave  /main/U_RX_Streamer/rx_first_o
add wave  /main/U_RX_Streamer/rx_last_o
add wave  /main/U_RX_Streamer/rx_data_o
add wave  /main/U_RX_Streamer/rx_valid_o
add wave  /main/U_RX_Streamer/rx_dreq_i
add wave  /main/U_RX_Streamer/rx_lost_o
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

