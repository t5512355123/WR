#!/bin/bash

T_BRDC="udp/192.168.0.255"
T_DEVx="udp/192.168.0.10"
NUM_DEVS=1
NUM_TRIGS=4

A_GPIO="0x00100000"
A_OFFS="0x00180"
A_SUFF="/4"

A_CLR_FIFO="004"
A_SET_ACT="00C"
A_CLR_ACT="010"
A_POS_EDG="018"
A_NEG_EDG="01C"


EB_WR="eb-write -p -f"
EB_RD="eb-read -p -f"



clear
for ((j = 0; j <= NUM_DEVS-1; j++ ))
do

echo $EB_WR $T_DEVx$j $A_OFFS$A_CLR_FIFO$A_SUFF 0xF
$EB_WR $T_DEVx$j $A_OFFS$A_SET_ACT$A_SUFF 0xF

echo "collect 10 seconds worth of timestamps"
for ((x = 0; x <= 10; x++ ))
do
#sleep 1
echo -n "."
done
echo ""

$EB_WR $T_DEVx$j $A_OFFS$A_CLR_ACT$A_SUFF 0xF

for ((k = 0; k < NUM_TRIGS; k++ ))
do


aux=$((k * 2))
#echo $aux
A_F_POP="4"$aux"0"  
A_F_CNT="4"$aux"4"
A_F_UTC0="4"$aux"8"
A_F_UTC1="4"$aux"C"

aux=$((k * 2 + 1))
#echo $aux

A_F_CYC="4"$aux"0"



for ((i = 0; i <= 10; i++ ))
do

UTC1=0x$($EB_RD $T_DEVx$j $A_OFFS$A_F_UTC1$A_SUFF)
UTC0=0x$($EB_RD $T_DEVx$j $A_OFFS$A_F_UTC0$A_SUFF)
VAL=$((UTC0 * 256 + UTC1))
VALS=$(date -d @$VAL)
CYC=$($EB_RD $T_DEVx$j $A_OFFS$A_F_CYC$A_SUFF)
 
echo "DEV"$j "TRIG"$k "UTC" $UTC0 $UTC1 $VALS "Cycle" $CYC

#echo "pop fifo"
$EB_WR $T_DEVx$j $A_OFFS$A_F_POP$A_SUFF 0x1
done



done
#echo "Timestamps stored: "
#eb-read $T_DEV $A_OFFS$A_F_CNT$A_SUFF
#sleep 1

done



