#! /bin/bash
# Goal: read the current timestamps off two devices
# Add 5 seconds to each and set off a 100ms pulse

#SCU: 3.0 2.I 1.L 0.P
#EXP: 3.I 2.I 1.L 0.P

dev1="$1"
dev2="$2"
wait_s="5"
pulse_ns="100000000"
channel=2 # IO pin on both SCU and exploder

FLAGS="-p -a 32 -d 32 -r 0"

schedule () {
  dev="$1"
  delay_s="$2"
  delay_ns="$3"
  
  echo -n "  $dev: "
  
  # Read the timestamp
  UTC0=0x`eb-read $FLAGS $dev $((0x180408+channel*0x20))/4`
  UTC1=0x`eb-read $FLAGS $dev $((0x18040C+channel*0x20))/4`
  CYC=0x`eb-read $FLAGS $dev  $((0x180410+channel*0x20))/4`
  
  # Compute the deadline
  NS=$((CYC*8 + delay_ns))
  S_OVER=$((NS/1000000000))
  UTC=$((UTC0*256 + UTC1 + delay_s + S_OVER))
  NS=$((NS-S_OVER*1000000000))
  CYC=$((NS/8))

  echo -n `date +"%Y-%m-%d %H:%M:%S" -d @$UTC`
  printf ".%09d\n" $NS
  
  eb-write $FLAGS $dev 0x140010/4 0 # utchi
  eb-write $FLAGS $dev 0x140014/4 `printf 0x%x $UTC` # utclo
  eb-write $FLAGS $dev 0x140018/4 `printf 0x%x $CYC` # cycle
  eb-write $FLAGS $dev 0x14001C/4 0xffffffff # toggle all LEDs
  eb-write $FLAGS $dev 0x140000/4 0 # enqueue command
}

# Step 1: detect and configure device TLUs
echo "Configuring TLUs to latch pulse"

# Flush FIFO
let fifo_pin=2**channel

if ! eb-write $dev1 0x180004/4 $fifo_pin; then echo "$dev1 TLU not found"; exit 1; fi
if ! eb-write $dev2 0x180004/4 $fifo_pin; then echo "$dev2 TLU not found"; exit 1; fi
# Enable capture
eb-write $FLAGS $dev1 0x18000C/4 $fifo_pin
eb-write $FLAGS $dev2 0x18000C/4 $fifo_pin

echo -n "Waiting for pulse... "
while true; do
  dev1stat=0x`eb-read $FLAGS $dev1 0x180000/4`
  dev2stat=0x`eb-read $FLAGS $dev2 0x180000/4`
  let dev1rdy="dev1stat&fifo_pin"
  let dev2rdy="dev2stat&fifo_pin"
  if [ $dev1rdy -gt 0 -a $dev2rdy -gt 0 ]; then break; fi
  sleep 1
done

echo "done"
eb-write $FLAGS $dev1 0x180010/4 $fifo_pin
eb-write $FLAGS $dev2 0x180010/4 $fifo_pin

echo "Scheduling events:"
schedule $dev1 $wait_s 0
schedule $dev1 $wait_s $pulse_ns
schedule $dev2 $wait_s 0
schedule $dev2 $wait_s $pulse_ns
