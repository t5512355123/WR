if target=="xilinx":
  modules = {
    "local" : [
      "hdl/gn4124core/rtl",
    ],
  }

if action == "simulation":
  modules['local'].append("hdl/gn4124core/sim/gn4124_bfm")
