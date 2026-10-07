make -f Makefile > /dev/null 2>&1 
vsim -L unisim work.main -voptargs="+acc" 

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

#do wave.do
run 100us
wave zoomfull
radix -hex

