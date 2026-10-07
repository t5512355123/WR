action = "simulation"
target = "xilinx"
syn_device = "xc6slx45t"
syn_grade = "-3"
syn_package = "fgg484"
#sim_tool = "modelsim"
sim_tool = "riviera"
top_module = "main"
#vlog_opt="-mixedsvvh l"
#vcom_opt="-mixedsvvh l"
vcom_opt="-relax -packagevhdlsv"
include_dirs = [ "../../sim" ]

files = [ "main.sv" ]

modules = { "local" : [ "../../",
                     "../../ip_cores/general-cores"
                     ]};
