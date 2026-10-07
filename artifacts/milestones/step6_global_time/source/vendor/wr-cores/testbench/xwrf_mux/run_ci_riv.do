vlog main.sv +incdir+"." +incdir+../../sim
null vsim -L unisim -t 10fs work.main +access +r -sv_seed random
vsim -L unisim -t 10fs work.main -voptargs="+acc"
set StdArithNoWarnings 1
set NumericStdNoWarnings 1
do wave_ci.do
radix -hexadecimal
run 2ms
wave zoomfull
radix -hexadecimal

