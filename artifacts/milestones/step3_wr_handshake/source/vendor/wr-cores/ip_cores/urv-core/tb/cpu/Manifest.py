sim_tool = "modelsim"
sim_top="main"
syn_device="xc6slx150t"

action = "simulation"
target = "xilinx"
include_dirs=["../../rtl"]
fetchto = "../../ip_cores"

vcom_opt="-mixedsvvh l"

files = [ "main.sv" ];

modules = {"local" : [ "../../rtl"],
           "git" : ["https://ohwr.org/project/general-cores.git"]}
