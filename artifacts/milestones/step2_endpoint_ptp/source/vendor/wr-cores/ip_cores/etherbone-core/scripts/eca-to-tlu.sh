#! /bin/bash
dev="$1"
channel=1

let fifo_pin=2**channel
FLAGS="-p -a 32 -d 32 -r 0"

schedule () {
  dev="$1"
  delay_s="$2"
  delay_ns="$3"
  
  if [ $delay_ns -eq 0 ]; then echo -n "target: "; fi
  
  # Read the ppsgen time
  UTC=0x`eb-read $FLAGS $dev 0x220308/4` # pps utc lo
  CYC=0x`eb-read $FLAGS $dev 0x220304/4` # pps cycle count
  
  # Compute the deadline
  NS=$((CYC*8 + delay_ns))
  S_OVER=$((NS/1000000000))
  UTC=$((UTC + delay_s + S_OVER))
  NS=$((NS-S_OVER*1000000000))
  CYC=$((NS/8))

  if [ $delay_ns -eq 0 ]; then
    echo -n `date +"%Y-%m-%d %H:%M:%S" -d @$UTC`
    printf ".%09d\n" $NS
  fi
  
  eb-write $FLAGS $dev 0x140010/4 0 # utchi
  eb-write $FLAGS $dev 0x140014/4 `printf 0x%x $UTC` # utclo
  eb-write $FLAGS $dev 0x140018/4 `printf 0x%x $CYC` # cycle
  eb-write $FLAGS $dev 0x14001C/4 0xffffffff # toggle all LEDs
  eb-write $FLAGS $dev 0x140000/4 0 # enqueue command
}

# Flush the FIFO
if ! eb-write $dev 0x180004/4 $fifo_pin; then echo "$dev TLU not found"; exit 1; fi
# Enable capture
eb-write $FLAGS $dev 0x18000C/4 $fifo_pin

# Trigger a pulse in 5 seconds
schedule $dev 5 0
schedule $dev 5 100000

# Wait 6 seconds
sleep 6

# Read back the time we set
UTC0=0x`eb-read $FLAGS $dev $((0x180408+channel*0x20))/4`
UTC1=0x`eb-read $FLAGS $dev $((0x18040C+channel*0x20))/4`
CYC=0x`eb-read $FLAGS $dev  $((0x180410+channel*0x20))/4`

# Compute the deadline
NS=$((CYC*8))
UTC=$((UTC0*256 + UTC1))

echo -n "result: "
echo -n `date +"%Y-%m-%d %H:%M:%S" -d @$UTC`
printf ".%09d\n" $NS
