onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /main/clk_sys
add wave -noupdate /main/rst_n
add wave -noupdate -expand -group SNK -expand /main/DUT/U_DUT/snk_i
add wave -noupdate -expand -group SNK -expand /main/DUT/U_DUT/snk_o
add wave -noupdate -expand -group SRC -expand /main/DUT/U_DUT/src_o
add wave -noupdate -expand -group SRC -expand /main/DUT/U_DUT/src_i
add wave -noupdate /main/DUT/U_DUT/bw_bps_o
add wave -noupdate /main/DUT/U_DUT/bw_bps_cnt
add wave -noupdate /main/DUT/U_DUT/bwcur_kbps
add wave -noupdate /main/DUT/U_DUT/pps_p_i
add wave -noupdate /main/DUT/U_DUT/pps_valid_i
add wave -noupdate -height 16 /main/DUT/U_DUT/state_fwd
add wave -noupdate /main/DUT/U_DUT/wrf_reg
add wave -noupdate /main/DUT/U_DUT/drop_frame
add wave -noupdate /main/DUT/U_DUT/rnd_reg
add wave -noupdate /main/DUT/U_DUT/drop_thr
add wave -noupdate /main/DUT/U_DUT/bwmin_kbps
add wave -noupdate /main/DUT/U_DUT/new_limit_i
add wave -noupdate /main/DUT/U_DUT/bwmax_kbps_i
add wave -noupdate /main/DUT/U_DUT/thr_step_kbps
add wave -noupdate /main/DUT/U_DUT/last_thr_kbps
add wave -noupdate /main/DUT/U_DUT/dbg_frame_dropped
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {4015874000000 fs} 1}
configure wave -namecolwidth 150
configure wave -valuecolwidth 100
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
configure wave -timelineunits us
update
WaveRestoreZoom {4015779439820 fs} {4016029859720 fs}
