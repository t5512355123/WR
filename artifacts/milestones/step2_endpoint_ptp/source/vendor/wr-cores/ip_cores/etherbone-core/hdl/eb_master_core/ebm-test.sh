dev=$1
ebadr=$((0x1000000))

#test=0x$(0x$(printf "%X\n" "$(($ebadr))")
#echo $test

eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x0C))")/4 0x080030E3	#my mac
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x10))")/4 0xB05A0000
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x14))")/4 0xC0A8BFFE #my ip
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x18))")/4 0x0000EBD1 #my port
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x1C))")/4 0xBC305BE2 #his mac
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x20))")/4 0xB0880000 
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x24))")/4 0xC0A8BF1F #his ip
echo "3\n"
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x28))")/4 0x0000EBD0 #his port
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x2C))")/4 0x00000050 #udp packet length 
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x30))")/4 0x00000000 #adr hi bits
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x34))")/4 0x00000010 #max ops
eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x40))")/4 0x00000000 #EB options
echo "4\n"
./ebt.sh $dev $ebadr
echo "5\n"
echo eb-write $dev 0x$(printf "%X\n" "$(($ebadr + 0x04))")/4 0x00000001 #flush
echo "6\n"

