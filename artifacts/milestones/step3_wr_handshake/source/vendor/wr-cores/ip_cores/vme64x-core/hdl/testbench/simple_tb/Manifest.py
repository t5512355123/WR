files = [
 "top_tb.vhd",
]

fetchto = "../../ip_cores"

modules = {
    "local": [ "../../rtl" ],
    "git": [ "git://ohwr.org/project/general-cores.git" ],
}
