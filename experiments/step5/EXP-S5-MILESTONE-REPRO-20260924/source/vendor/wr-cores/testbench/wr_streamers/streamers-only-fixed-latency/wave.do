onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/clk_sys_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/clk_ref_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/rst_n_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/src_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/src_o
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tm_time_valid_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tm_tai_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tm_cycles_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/link_ok_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_data_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_valid_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_dreq_o
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_sync_o
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_last_p1_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_flush_p1_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_reset_seq_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_frame_p1_o
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_streamer_cfg_i
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_threshold_hit
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_timeout_hit
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_flush_latched
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_idle
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_last
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_we
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_full
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_empty
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_rd
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_empty_int
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_rd_int
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_rd_int_d
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_q_int
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_q_reg
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_q_valid
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_q
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_fifo_d
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/state
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/seq_no
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/count
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/ser_count
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/word_count
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/total_words
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/timeout_counter
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/pack_data
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/fsm_out
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/escaper
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/fab_src
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/fsm_escape
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/fsm_escape_enable
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/crc_en
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/crc_en_masked
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/crc_reset
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/crc_value
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_almost_empty
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tx_almost_full
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/buf_frame_count_inc_ref
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/buf_frame_count_dec_sys
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/buf_frame_count
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tag_cycles
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tag_valid
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/tag_valid_latched
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/link_ok_delay_cnt
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/link_ok_delay_expired
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/link_ok_delay_expired_ref
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/link_ok_ref
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/clk_data
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/rst_n_ref
add wave -noupdate -group TxStreamer /main/U_TX_Streamer/stamper_pulse_a
add wave -noupdate -group main /main/clk_ref
add wave -noupdate -group main /main/clk_sys
add wave -noupdate -group main /main/rst
add wave -noupdate -group main /main/tx_streamer_dvalid
add wave -noupdate -group main /main/tx_streamer_data
add wave -noupdate -group main /main/tx_streamer_flush
add wave -noupdate -group main /main/tx_streamer_last
add wave -noupdate -group main /main/tx_streamer_dreq
add wave -noupdate -group main /main/rx_streamer_dreq
add wave -noupdate -group main /main/rx_streamer_data
add wave -noupdate -group main /main/rx_streamer_dvalid
add wave -noupdate -group main /main/rx_streamer_lost
add wave -noupdate -group main /main/rx_latency
add wave -noupdate -group main /main/rx_latency_valid
add wave -noupdate -group main /main/tm_cycles
add wave -noupdate -group main /main/tm_tai
add wave -noupdate -group main /main/tx_counter
add wave -noupdate -group main /main/rx_streamer_cfg
add wave -noupdate -group main /main/tx_streamer_cfg
add wave -noupdate -group main /main/src_out
add wave -noupdate -group main /main/src_in
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rst_n_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/clk_sys_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/clk_ref_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/tm_time_valid_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/tm_tai_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/tm_cycles_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/d_data_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/d_last_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/d_sync_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/d_target_ts_en_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/d_valid_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/d_drop_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/d_accept_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/d_req_o
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rx_first_p1_o
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rx_last_p1_o
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rx_data_o
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rx_valid_o
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rx_dreq_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rx_streamer_cfg_i
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/State
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rst_n_ref
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/wr_full
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_rd
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/dbuf_d
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/dbuf_q
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_q
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/dbuf_q_valid
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/dbuf_req
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_data
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_sync
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_last
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_target_ts_en
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_target_ts
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_empty
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_we
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/fifo_valid
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/rx_valid
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/delay_arm
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/delay_match
add wave -noupdate -group FixDelay /main/U_RX_Streamer/U_FixLatencyDelay/delay_miss
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/clk_i
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/rst_n_i
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/arm_i
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/ts_latency_i
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/tm_time_valid_i
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/tm_tai_i
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/tm_cycles_i
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/match_o
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/tm_cycles_scaled
add wave -noupdate -expand -group TSCompare /main/U_RX_Streamer/U_FixLatencyDelay/U_Compare/ts_latency_scaled
add wave -noupdate -expand -group Top /main/clk_ref
add wave -noupdate -expand -group Top /main/clk_sys
add wave -noupdate -expand -group Top /main/rst
add wave -noupdate -expand -group Top /main/tx_streamer_dvalid
add wave -noupdate -expand -group Top /main/tx_streamer_data
add wave -noupdate -expand -group Top /main/tx_streamer_flush
add wave -noupdate -expand -group Top /main/tx_streamer_last
add wave -noupdate -expand -group Top /main/tx_streamer_dreq
add wave -noupdate -expand -group Top /main/tx_streamer_sync
add wave -noupdate -expand -group Top /main/rx_streamer_dreq
add wave -noupdate -expand -group Top /main/rx_streamer_data
add wave -noupdate -expand -group Top /main/rx_streamer_dvalid
add wave -noupdate -expand -group Top /main/rx_streamer_lost
add wave -noupdate -expand -group Top /main/rx_latency
add wave -noupdate -expand -group Top /main/rx_latency_valid
add wave -noupdate -expand -group Top /main/tm_cycles
add wave -noupdate -expand -group Top /main/tm_tai
add wave -noupdate -expand -group Top /main/tx_counter
add wave -noupdate -expand -group Top /main/rx_streamer_cfg
add wave -noupdate -expand -group Top /main/tx_streamer_cfg
add wave -noupdate -expand -group Top /main/src_out
add wave -noupdate -expand -group Top /main/src_in
add wave -noupdate -expand -group Top /main/tx_delay_count
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {2269068 ps} 0}
configure wave -namecolwidth 191
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
WaveRestoreZoom {0 ps} {10500 ns}
