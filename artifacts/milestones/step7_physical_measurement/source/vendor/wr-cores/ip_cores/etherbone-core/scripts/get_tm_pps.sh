#!/bin/bash

T_BRDC="udp/192.168.0.255"
T_DEVx="udp/192.168.0.10"
NUM_DEVS=1

A_GPIO="0x00100000"
A_OFFS="0x00180"
A_SUFF="/4"

A_SET_ACT="00C"
A_CLR_ACT="010"
A_POS_EDG="018"
A_NEG_EDG="01C"

A_F_POP="400"
A_F_CNT="404"
A_F_UTC0="408"
A_F_UTC1="40C"
A_F_CYC="410"


#A_F_POP="460"	
#A_F_CNT="464"
#A_F_UTC0="468"
#A_F_UTC1="46C"
#A_F_CYC="470"

EB_WR="eb-write -p -f"
EB_RD="eb-read -p -f"

echo $EB_WR $T_BRDC $A_OFFS$A_SET_ACT$A_SUFF 0x1

#$EB_WR $T_BRDC $A_OFFS$A_SET_ACT$A_SUFF 0x1
#echo "Timestamps stored before: "
#eb-read $T_DEV $A_OFFS$A_F_CNT$A_SUFF

for ((i = 0; i <= 10; i++ ))
do

#echo "Trigger all"
#$EB_WR $T_BRDC $A_GPIO$A_SUFF 0x00000000
#$EB_WR $T_BRDC $A_GPIO$A_SUFF 0x0000000f

#echo "Timestamps stored after: "
#eb-read $T_DEV $A_OFFS$A_F_CNT$A_SUFF
#eb-read $T_DEV $A_OFFS$A_F_UTC1$A_SUFF
#eb-read $T_DEV $A_OFFS$A_F_UTC0$A_SUFF

for ((j = 0; j <= NUM_DEVS-1; j++ ))
do

UTC1=$($EB_RD $T_DEVx$j $A_OFFS$A_F_UTC1$A_SUFF)
UTC0=$($EB_RD $T_DEVx$j $A_OFFS$A_F_UTC0$A_SUFF)
CYC=$($EB_RD $T_DEVx$j $A_OFFS$A_F_CYC$A_SUFF)
 
echo "DEV"$j "UTC" $UTC0 $UTC1 "Cycle" $CYC

#echo "pop fifo"
$EB_WR $T_DEVx$j $A_OFFS$A_F_POP$A_SUFF 0x1
done

#echo "Timestamps stored: "
#eb-read $T_DEV $A_OFFS$A_F_CNT$A_SUFF
sleep 1

done



