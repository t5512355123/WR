action   = "simulation"
sim_tool = "modelsim"
sim_top  = "TB_SPEC"
target   = "xilinx"
vcom_opt = "-93"

syn_device  = "xc6slx45t"
syn_grade   = "-3"
syn_package = "fgg484"

modules = {
    "local" : [
        "../top",
        "../rtl",
        "../../gn4124core/rtl",
        "testbench",
    ],
    "git" : [
        "git://ohwr.org/hdl-core-lib/general-cores.git",
    ],
}

fetchto = "../../ip_cores"
