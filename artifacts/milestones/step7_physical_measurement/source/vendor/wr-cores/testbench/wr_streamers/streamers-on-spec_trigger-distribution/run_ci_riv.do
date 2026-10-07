# make -f Makefile > /dev/null 2>&1
vsim -L unisim -L secureip work.main +access +r 
set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do wave_ci.do
run 1000us
wave zoomfull
radix -hex

