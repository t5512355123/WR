fetchto = "../../ip_cores"

files = [
    "clbv2_wr_ref_top.vhd",
    "clbv2_wr_ref_top.xdc",
    "clbv2_wr_ref_top.bmm",
]

modules = {
    "local" : [
        "../../",
    ],
    "git" : [
        "git://ohwr.org/hdl-core-lib/general-cores.git",
        "git://ohwr.org/project/urv-core.git",
    ],
}
