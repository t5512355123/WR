#! /bin/bash
host="$1"

ip=`ping -n -c 1 $host | grep "bytes from" | cut -d" " -f4 | cut -d: -f1`
mac=`/usr/sbin/arp -n $ip  | grep ether | cut -b34-52`

echo "Device is $ip at $mac"

ipbits=`echo $ip | sed 's/\./ /g'`
iphex=`printf "%02x%02x%02x%02x" $ipbits`

machex=`echo $mac | sed 's/://g'`

eb-write -a 32 -d 32 -r 0 -p -c -f -v udp/$ip 24/4 0x$iphex
eb-write -a 32 -d 32 -r 0 -p -c -b -v udp/$ip 16/8 0x${machex}0000
