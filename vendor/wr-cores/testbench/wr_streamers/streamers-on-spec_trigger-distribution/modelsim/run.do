# Modelsim run script
vsim -L unisim -L secureip work.main -voptargs="+acc" 
set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do ../wave.do
run 40000us
wave zoomfull
radix -hex
