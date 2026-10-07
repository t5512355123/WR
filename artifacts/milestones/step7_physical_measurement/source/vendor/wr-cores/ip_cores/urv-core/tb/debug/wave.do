onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -expand -group Fetch /main/DUT/fetch/clk_i
add wave -noupdate -expand -group Fetch /main/DUT/fetch/dbg_enabled_o
add wave -noupdate -expand -group Fetch /main/DUT/fetch/dbg_force_i
add wave -noupdate -expand -group Fetch /main/DUT/fetch/dbg_insn_i
add wave -noupdate -expand -group Fetch /main/DUT/fetch/dbg_insn_ready_o
add wave -noupdate -expand -group Fetch /main/DUT/fetch/dbg_mode
add wave -noupdate -expand -group Fetch /main/DUT/fetch/f_ir_o
add wave -noupdate -expand -group Fetch /main/DUT/fetch/f_pc_o
add wave -noupdate -expand -group Fetch /main/DUT/fetch/f_stall_i
add wave -noupdate -expand -group Fetch /main/DUT/fetch/f_valid_o
add wave -noupdate -expand -group Fetch /main/DUT/fetch/im_addr_o
add wave -noupdate -expand -group Fetch /main/DUT/fetch/im_data_i
add wave -noupdate -expand -group Fetch /main/DUT/fetch/im_valid_i
add wave -noupdate -expand -group Fetch /main/DUT/fetch/pc
add wave -noupdate -expand -group Fetch /main/DUT/fetch/pc_next
add wave -noupdate -expand -group Fetch /main/DUT/fetch/pc_plus_4
add wave -noupdate -expand -group Fetch /main/DUT/fetch/pipeline_cnt
add wave -noupdate -expand -group Fetch /main/DUT/fetch/rst_d
add wave -noupdate -expand -group Fetch /main/DUT/fetch/rst_i
add wave -noupdate -expand -group Fetch /main/DUT/fetch/x_bra_i
add wave -noupdate -expand -group Fetch /main/DUT/fetch/x_dbg_toggle
add wave -noupdate -expand -group Fetch /main/DUT/fetch/x_pc_bra_i
add wave -noupdate -expand -group Main /main/dbg_enabled
add wave -noupdate -expand -group Main /main/dbg_force
add wave -noupdate -expand -group Main /main/dbg_insn
add wave -noupdate -expand -group Main /main/dbg_insn_ready
add wave -noupdate /main/DUT/execute/f_dbg_toggle_o
add wave -noupdate /main/DUT/x2f_dbg_toggle
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {14447 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 164
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
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
WaveRestoreZoom {3518287 ps} {4025354 ps}
