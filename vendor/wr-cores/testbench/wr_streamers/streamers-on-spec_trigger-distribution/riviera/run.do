# Riviera run script
vsim -L unisim -L secureip work.main +access +r +access +w_nets -ieee_nowarn 

do ../wave_ci.do
run 40000us
wave zoomfull
radix -hexadecimal
