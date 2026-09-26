onerror {resume}

add wave  -radix hexadecimal /main/link_up_a
add wave  -radix hexadecimal /main/link_up_b
add wave  -divider {SPEC A - common}
add wave  -radix hexadecimal /main/SPEC_A/clk_sys_62m5
add wave  -radix hexadecimal /main/SPEC_A/rst_sys_62m5_n
add wave  -radix hexadecimal /main/SPEC_A/rst_ref_125m_n
add wave  -radix hexadecimal /main/SPEC_A/clk_ref_125m
add wave  -divider {SPEC A - WR Timing}
add wave  -radix hexadecimal /main/SPEC_A/dio_p_i(1)
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/tm_time_valid_o
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/tm_tai_o
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/tm_cycles_o
add wave  -divider {SPEC A - pulse stamper}
add wave  -radix hexadecimal /main/SPEC_A/U_Pulse_Stamper/tag_tai_o
add wave  -radix hexadecimal /main/SPEC_A/U_Pulse_Stamper/tag_cycles_o
add wave  -radix hexadecimal /main/SPEC_A/U_Pulse_Stamper/tag_valid_o
add wave  -divider {SPEC A - TX Streamer}
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/wrs_tx_data_i
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/wrs_tx_valid_i
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/wrs_tx_dreq_o
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/gen_wr_streamers/cmp_xwr_streamers/src_i
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/gen_wr_streamers/cmp_xwr_streamers/src_o
add wave  -divider {SPEC A - PHY}
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/phy8_o.tx_data
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/phy8_o.tx_k
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/phy8_i.tx_disparity
add wave  -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/phy8_i.tx_enc_err
add wave  -divider {SPEC B - PHY}
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/phy8_i.rx_data
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/phy8_i.ref_clk
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/phy8_o.tx_k
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/phy8_i.tx_enc_err
add wave  -divider {SPEC B - WR timing}
add wave  -radix hexadecimal /main/SPEC_B/dio_p_o(2) 
add wave  /main/SPEC_B/U_Pulse_Stamper/tm_time_valid_i
add wave  /main/SPEC_B/U_Pulse_Stamper/tm_tai_i
add wave  /main/SPEC_B/U_Pulse_Stamper/tm_cycles_i
add wave  -divider {SPEC B - RX Streamer}
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/gen_wr_streamers/cmp_xwr_streamers/snk_i
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/gen_wr_streamers/cmp_xwr_streamers/snk_o
add wave  -radix hexadecimal /main/SPEC_B/rx_data
add wave  -radix hexadecimal /main/SPEC_B/rx_valid
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/wrs_rx_data_o
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/wrs_rx_valid_o
add wave  -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/wrs_rx_dreq_i
add wave  -divider {SPEC B - Timestamp adder}
add wave  -radix hexadecimal /main/SPEC_B/U_Add_Delay1/valid_i
add wave  -radix hexadecimal /main/SPEC_B/U_Add_Delay1/a_tai_i
add wave  -radix hexadecimal /main/SPEC_B/U_Add_Delay1/a_cycles_i
add wave  -radix hexadecimal /main/SPEC_B/U_Add_Delay1/b_tai_i
add wave  -radix hexadecimal /main/SPEC_B/U_Add_Delay1/b_cycles_i
add wave  -radix hexadecimal /main/SPEC_B/U_Add_Delay1/valid_o
add wave  -radix hexadecimal /main/SPEC_B/U_Add_Delay1/q_tai_o
add wave  -radix hexadecimal /main/SPEC_B/U_Add_Delay1/q_cycles_o
add wave  -divider {SPEC B - pulse generator}
add wave  -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/trig_ready_o
add wave  -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/trig_tai_i
add wave  -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/trig_cycles_i
add wave  -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/trig_valid_i
add wave  -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/pulse_o
null TreeUpdate [null SetDefaultTree]
wv.cursors.add -time {560018003180 fs} -name {Cursor 1}
null configure wave -namecolwidth 221
null configure wave -valuecolwidth 152
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
wv.zoom.range -from {0 fs} -to {55629 ns}

