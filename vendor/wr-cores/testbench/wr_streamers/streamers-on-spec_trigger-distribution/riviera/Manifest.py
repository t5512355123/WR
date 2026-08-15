action= "simulation"
target= "xilinx"
syn_device="xc6slx45t"
sim_tool="riviera"
top_module="main"

vcom_opt="-relax -packagevhdlsv"

include_dirs = [ "../" ]

modules = {
    "local" : [ "../" ]
}

files = [ "main.sv" ]