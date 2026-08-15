sim_tool   = "modelsim"
top_module = "main"
action     = "simulation"
target     = "xilinx"
syn_device = "xc6slx45t"
vcom_opt   = "-93 -mixedsvvh"

fetchto    = "../../../ip_cores"

include_dirs = [
    "../gn4124_bfm",
    "../../../ip_cores/general-cores/sim/",
]

files = [
    "main.sv",
]

modules = {
    "local" :  [
        "../gn4124_bfm",
        "../../rtl",
    ],
    "git" : [
        "git://ohwr.org/hdl-core-lib/general-cores.git",
    ],
}
