target = "xilinx"
action = "simulation"
sim_tool = "modelsim"
top_module = "main"
syn_device = "XC6VLX130T"
fetchto = "../../ip_cores"
vlog_opt = "+incdir+../../sim +incdir+../../sim/wr-hdl"

files = [ "main.sv" ]

include_dirs = [ "../../sim" ]

modules = { "local" : ["../../top/bare_top",
                       "../../ip_cores/general-cores",
                       "../../ip_cores/wr-cores"] }
					

