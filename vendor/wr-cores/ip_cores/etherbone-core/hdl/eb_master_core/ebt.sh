dev=$1
ebadr=$(($2+ 0x800000))
ebwoffs=$((0x400000))

 eb-write -p $dev 0x$(printf "%X\n" "$(($ebadr + 0x00))")/4 0xDEADBEE0
 eb-write -p $dev 0x$(printf "%X\n" "$(($ebadr + 0x04))")/4 0xDEADBEE1
 eb-write -p $dev 0x$(printf "%X\n" "$(($ebadr + $ebwoffs + 0x00))")/4 0xDEADBEE2
