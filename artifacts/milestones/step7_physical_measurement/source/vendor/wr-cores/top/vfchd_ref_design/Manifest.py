fetchto = "../../ip_cores"

files = [
    "vfchd_wr_ref_top.vhd",
    "vfchd_i2cmux/vfchd_i2cmux_pkg.vhd",
    "vfchd_i2cmux/I2cMuxAndExpReqArbiter.v",
    "vfchd_i2cmux/I2cMuxAndExpMaster.v",
    "vfchd_i2cmux/SfpIdReader.v",
]

modules = {
    "local" : [
        "../../",
    ],
    "git" : [
        "git://ohwr.org/project/general-cores.git",
        "git://ohwr.org/project/vme64x-core.git",
        "git://ohwr.org/project/etherbone-core.git",
        "git://ohwr.org/project/urv-core.git",
    ],
}
