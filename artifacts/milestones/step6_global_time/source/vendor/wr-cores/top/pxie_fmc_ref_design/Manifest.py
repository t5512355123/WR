fetchto = "../../ip_cores"

files = [ "pxie_fmc_ref_top.vhd", ]

modules = {
    "local" : [
        "../../",
    ],
    "git" : [
        "git://ohwr.org/hdl-core-lib/general-cores.git",
        "git://ohwr.org/hdl-core-lib/gn4124-core.git",
        "git://ohwr.org/hdl-core-lib/etherbone-core.git",
    ],
}
