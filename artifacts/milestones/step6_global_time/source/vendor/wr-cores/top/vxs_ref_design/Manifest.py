fetchto = "../../ip_cores"

files = [
    "vxs_wr_ref_top.vhd",
    "vxs_wr_ref_top.ucf"
]

modules = {
    "local" : [
        "../../",
        "../../board/vxs",
    ],
    "git" : [
        "git://ohwr.org/hdl-core-lib/general-cores.git",
        "git://ohwr.org/hdl-core-lib/gn4124-core.git",
        "git://ohwr.org/hdl-core-lib/etherbone-core.git",
    ],
}
