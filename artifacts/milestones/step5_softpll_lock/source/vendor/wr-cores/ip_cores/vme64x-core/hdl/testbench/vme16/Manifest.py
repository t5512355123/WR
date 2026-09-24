# Allow the user to override fetchto using:
#  hdlmake -p "fetchto='xxx'"
if locals().get('fetchto', None) is None:
  fetchto = "../../ip_cores"

top_module="vme16_tb"
target=None

files = [
 "vme16_tb.vhd",
]

modules = {
    "local": [ "../../rtl", fetchto + "/general-cores" ],
}
