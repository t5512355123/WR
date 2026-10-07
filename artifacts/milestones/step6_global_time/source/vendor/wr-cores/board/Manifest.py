try:
    if board in ["spec", "svec", "vfchd", "clbv2", "clbv3", "clbv4", "pxie-fmc", "diot-sb", "fasec", "common"]:
        modules = {"local" : [ board ] }
except NameError:
    # board is not defined
    pass
