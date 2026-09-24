action= "simulation"
target= "xilinx"
syn_device="xc6slx45t"
#sim_tool="modelsim"
sim_tool="riviera"
top_module="main"
vcom_opt="-packagevhdlsv"
fetchto="../../../ip_cores"
vlog_opt="+incdir+../../../sim"

modules = { "local" : ["../../..",
                       "../../../modules/wr_streamers",
                       "../../../ip_cores/general-cores"]}
					  
files = ["main.sv"]

