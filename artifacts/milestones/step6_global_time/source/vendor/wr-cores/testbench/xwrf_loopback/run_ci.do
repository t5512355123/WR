#vlog -dpiheader dpi/minic_dpi.h -sv main.sv +incdir+"." +incdir+../../sim
vlog  main.sv +incdir+"." +incdir+../../sim
null make -f Makefile
#vsim -sv_lib dpi/minic -L unisim -t 10fs work.main -voptargs="+acc"
vsim -L unisim -t 10fs work.main +access +r
set StdArithNoWarnings 1
set NumericStdNoWarnings 1
do wave_ci.do
radix -hexadecimal
run 20ms
wave zoomfull
radix -hexadecimal

