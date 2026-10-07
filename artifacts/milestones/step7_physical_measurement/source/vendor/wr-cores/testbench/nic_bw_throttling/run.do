#vlog -sv main.sv +incdir+"." +incdir+../../sim
#-- make -f Makefile
#vsim -L unisim -t 10fs work.main -voptargs="+acc"

make -f Makefile
vsim -L secureip -L unisim -L xilinxcorelib -t 10fs work.main -voptargs="+acc" +nowarn8684 +nowarn8683
set StdArithNoWarnings 1
set NumericStdNoWarnings 1
do wave.do
radix -hexadecimal
run 200ms
wave zoomfull
radix -hexadecimal
