# Riviera run script 
# execute: vsim -c -do "run.do"
vsim -L unisim -t 10fs work.main +access +r -ieee_nowarn
do ../wave_ci.do
radix -hexadecimal
run 200ms
wave zoomfull
radix -hexadecimal

