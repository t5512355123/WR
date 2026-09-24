action = "simulation"
sim_tool = "ghdl"
sim_top = "vme16_tb"

ghdl_opt = "--std=08 --ieee=synopsys"
# for general-cores
target = None

modules = {
    "local": [ ".." ],
}
