action = "simulation"
target = "xilinx"
files = "main.sv"
syn_device = "xc6slx45t"
syn_grade = "-3"
syn_package = "fgg484"
#sim_tool = "modelsim"
sim_tool = "riviera"
top_module = "main"
fetchto = "../../ip_cores"
vlog_opt="+incdir+../../sim"
vcom_opt="-packagevhdlsv"
include_dirs = [ "../../sim", "../../modules/fabric" ]

modules ={"local" : ["../../",
			"../../ip_cores/general-cores",
			"../../ip_cores/etherbone-core",
			"../../ip_cores/gn4124-core"]}
    
