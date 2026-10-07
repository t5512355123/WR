fetchto = "../../ip_cores"

files = [
    "cute_wr_ref_top.vhd",
    "cute_wr_ref_top.ucf",
]

modules = {
    "local" : [
        "../../",
        "../../board/cute",
    ],
    "git" : [
        "git://ohwr.org/project/general-cores.git",
        "git://ohwr.org/project/etherbone-core.git",
        "git://ohwr.org/project/urv-core.git",
    ],
}
