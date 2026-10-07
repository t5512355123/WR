vsim -L unisim -t 10fs work.main -voptargs="+acc"
set StdArithNoWarnings 1
set NumericStdNoWarnings 1


radix -hexadecimal
run 10us
wave zoomfull
radix -hexadecimal
