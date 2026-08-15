onerror {resume}

add wave  /main/clk_sys
add wave  /main/WRF_LBK/X_LOOPBACK/wrf_snk_i
add wave  /main/WRF_LBK/X_LOOPBACK/wrf_snk_o
add wave  /main/WRF_LBK/X_LOOPBACK/wrf_src_o
add wave  /main/WRF_LBK/X_LOOPBACK/wrf_src_i
add wave  -height 16 /main/WRF_LBK/X_LOOPBACK/WRF_SRC/state
add wave  /main/WRF_LBK/X_LOOPBACK/src_fab
add wave  /main/WRF_LBK/X_LOOPBACK/src_dreq
add wave  /main/WRF_LBK/X_LOOPBACK/wb_i
add wave  /main/WRF_LBK/X_LOOPBACK/wb_o
add wave  -height 16 /main/WRF_LBK/X_LOOPBACK/lbk_rxfsm
add wave  -height 16 /main/WRF_LBK/X_LOOPBACK/lbk_txfsm
add wave  /main/WRF_LBK/X_LOOPBACK/fword_valid
add wave  -unsigned /main/WRF_LBK/X_LOOPBACK/fsize
add wave  -unsigned /main/WRF_LBK/X_LOOPBACK/txsize
add wave  -unsigned /main/WRF_LBK/X_LOOPBACK/tx_cnt
add wave  /main/WRF_LBK/X_LOOPBACK/ack_cnt
add wave  -group FFIFO /main/WRF_LBK/X_LOOPBACK/ffifo_empty
add wave  -group FFIFO /main/WRF_LBK/X_LOOPBACK/ffifo_full
add wave  -group FFIFO -unsigned /main/WRF_LBK/X_LOOPBACK/FRAME_FIFO/count_o
add wave  -group FFIFO /main/WRF_LBK/X_LOOPBACK/frame_wr
add wave  -group FFIFO /main/WRF_LBK/X_LOOPBACK/frame_in
add wave  -group FFIFO /main/WRF_LBK/X_LOOPBACK/frame_rd
add wave  -group FFIFO /main/WRF_LBK/X_LOOPBACK/frame_out
add wave  -group SFIFO /main/WRF_LBK/X_LOOPBACK/sfifo_empty
add wave  -group SFIFO /main/WRF_LBK/X_LOOPBACK/sfifo_full
add wave  -group SFIFO -unsigned /main/WRF_LBK/X_LOOPBACK/SIZE_FIFO/count_o
add wave  -group SFIFO -unsigned /main/WRF_LBK/X_LOOPBACK/fsize_in
add wave  -group SFIFO -unsigned /main/WRF_LBK/X_LOOPBACK/fsize_out
add wave  -group SFIFO /main/WRF_LBK/X_LOOPBACK/fsize_wr
add wave  -group SFIFO /main/WRF_LBK/X_LOOPBACK/fsize_rd
add wave  -group CNTRS -unsigned /main/WRF_LBK/X_LOOPBACK/rcv_cnt
add wave  -group CNTRS -unsigned /main/WRF_LBK/X_LOOPBACK/drp_cnt
add wave  -group CNTRS -unsigned /main/WRF_LBK/X_LOOPBACK/fwd_cnt
null TreeUpdate [null SetDefaultTree]
wv.cursors.add -time {1493558550000 fs} -name {Cursor 1}
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
wv.zoom.range -from {1488841281420 fs} -to {1489276418580 fs}

