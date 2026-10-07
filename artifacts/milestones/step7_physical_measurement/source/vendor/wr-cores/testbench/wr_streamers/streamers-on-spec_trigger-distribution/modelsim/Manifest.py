action= "simulation"
target= "xilinx"
syn_device="xc6slx45t"
sim_tool="modelsim"
top_module="main"

vcom_opt="-mixedsvvh"

include_dirs = [ "../" ]

modules = {
    "local" : [ "../" ]
}

files = [ "main.sv" ]