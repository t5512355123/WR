action = "simulation"
target = "xilinx"
syn_device = "xc6slx45t"
syn_grade = "-3"
syn_package = "fgg484"
top_module = "main"
sim_tool = "modelsim"
vcom_opt="-mixedsvvh"

include_dirs = [ "../../../sim",
        "../" ]

modules = {
    "local" : [ "../" ]
}