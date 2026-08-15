action = "simulation"
target = "xilinx"
syn_device = "xc6slx45t"
syn_grade = "-3"
syn_package = "fgg484"
top_module = "main"
sim_tool = "riviera"
vcom_opt="-relax -packagevhdlsv"
fetchto = "../../../ip_cores"
vlog_opt = "+incdir+../../sim"

include_dirs = [ "../../../sim",
        "../" ]

modules = {
    "local" : [ "../" ]
}