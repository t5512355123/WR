onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -radix hexadecimal /main/link_up_a
add wave -noupdate -radix hexadecimal /main/link_up_b
add wave -noupdate -divider {SPEC A - common}
add wave -noupdate -radix hexadecimal /main/SPEC_A/clk_sys_62m5
add wave -noupdate -radix hexadecimal /main/SPEC_A/rst_sys_62m5_n
add wave -noupdate -radix hexadecimal /main/SPEC_A/rst_ref_125m_n
add wave -noupdate -radix hexadecimal /main/SPEC_A/clk_ref_125m
add wave -noupdate -divider {SPEC A - WR Timing}
add wave -noupdate -radix hexadecimal /main/SPEC_A/dio_p_i(1)
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/tm_time_valid_o
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/tm_tai_o
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/tm_cycles_o
add wave -noupdate -divider {SPEC A - pulse stamper}
add wave -noupdate -radix hexadecimal /main/SPEC_A/U_Pulse_Stamper/tag_tai_o
add wave -noupdate -radix hexadecimal /main/SPEC_A/U_Pulse_Stamper/tag_cycles_o
add wave -noupdate -radix hexadecimal /main/SPEC_A/U_Pulse_Stamper/tag_valid_o
add wave -noupdate -divider {SPEC A - TX Streamer}
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/wrs_tx_data_i
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/wrs_tx_valid_i
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/wrs_tx_dreq_o
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/gen_wr_streamers/cmp_xwr_streamers/src_i
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/gen_wr_streamers/cmp_xwr_streamers/src_o
add wave -noupdate -divider {SPEC A - PHY}
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/phy8_o.tx_data
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/phy8_o.tx_k
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/phy8_i.tx_disparity
add wave -noupdate -radix hexadecimal /main/SPEC_A/cmp_xwrc_board_spec/cmp_board_common/phy8_i.tx_enc_err
add wave -noupdate -divider {SPEC B - PHY}
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/phy8_i.rx_data
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/phy8_i.ref_clk
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/phy8_o.tx_k
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/phy8_i.tx_enc_err
add wave -noupdate -divider {SPEC B - WR timing}
add wave -noupdate -radix hexadecimal /main/SPEC_B/dio_p_o(2) 
add wave -noupdate /main/SPEC_B/U_Pulse_Stamper/tm_time_valid_i
add wave -noupdate /main/SPEC_B/U_Pulse_Stamper/tm_tai_i
add wave -noupdate /main/SPEC_B/U_Pulse_Stamper/tm_cycles_i
add wave -noupdate -divider {SPEC B - RX Streamer}
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/gen_wr_streamers/cmp_xwr_streamers/snk_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/gen_wr_streamers/cmp_xwr_streamers/snk_o
add wave -noupdate -radix hexadecimal /main/SPEC_B/rx_data
add wave -noupdate -radix hexadecimal /main/SPEC_B/rx_valid
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/wrs_rx_data_o
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/wrs_rx_valid_o
add wave -noupdate -radix hexadecimal /main/SPEC_B/cmp_xwrc_board_spec/cmp_board_common/wrs_rx_dreq_i
add wave -noupdate -divider {SPEC B - Timestamp adder}
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Add_Delay1/valid_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Add_Delay1/a_tai_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Add_Delay1/a_cycles_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Add_Delay1/b_tai_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Add_Delay1/b_cycles_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Add_Delay1/valid_o
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Add_Delay1/q_tai_o
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Add_Delay1/q_cycles_o
add wave -noupdate -divider {SPEC B - pulse generator}
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/trig_ready_o
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/trig_tai_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/trig_cycles_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/trig_valid_i
add wave -noupdate -radix hexadecimal /main/SPEC_B/U_Pulse_Generator/pulse_o
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {560018003180 fs} 0} {{Cursor 2} {530003823340 fs} 0}
configure wave -namecolwidth 221
configure wave -valuecolwidth 152
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {0 fs} {55629 ns}
