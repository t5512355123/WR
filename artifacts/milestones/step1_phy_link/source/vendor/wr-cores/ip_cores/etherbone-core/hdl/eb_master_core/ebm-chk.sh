dev=$1
ebadr=$((0x1000000))

#test=0x$(0x$(printf "%X\n" "$(($ebadr))")
#echo $test
echo "src mac"
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x0C))")/4 	#my mac
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x10))")/4 
echo "src ip"
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x14))")/4  #my ip
echo "src port"
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x18))")/4  #my port
echo "dst mac"
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x1C))")/4  #his mac
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x20))")/4  
echo "dst ip"
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x24))")/4  #his ip
echo "dst port"
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x28))")/4  #his port
echo "len hibits maxops ebops"
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x2C))")/4  
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x30))")/4  #adr hi bits
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x34))")/4  #max ops
eb-read $dev 0x$(printf "%X\n" "$(($ebadr + 0x40))")/4  #EB options

