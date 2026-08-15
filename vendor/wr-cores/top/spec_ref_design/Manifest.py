fetchto = "../../ip_cores"

files = [
    "spec_wr_ref_top.vhd",
]

modules = {
    "local" : [
        "../../",
    ],
    "git" : [
        "git://ohwr.org/project/general-cores.git",
        "git://ohwr.org/project/gn4124-core.git",
        "git://ohwr.org/project/etherbone-core.git",
        "git://ohwr.org/project/urv-core.git",
    ],
}
