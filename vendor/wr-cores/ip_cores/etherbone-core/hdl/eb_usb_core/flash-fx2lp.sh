#! /bin/sh

PROGRAMMED="1d50:6062"
RAW_CYPRESS="04b4:8613"

busid() {
  while [ ${#@} -gt 0 ]; do
    if lsusb -d "$1" >/dev/null; then
      lsusb -d "$1" | head -1 | sed 's@^Bus \(...\) Device \(...\):.*@/dev/bus/usb/\1/\2@'
      return 0
    fi
    shift
  done
  echo "flash-fx2lp.sh: Could not find a device to program!" >&2
  exit 1
}

dev=`busid $PROGRAMMED $RAW_CYPRESS`

# If unprogrammed, "usbtest" steals the device
rmmod usbtest 2>/dev/null

if [ "$1" = "-E" ]; then # erase
  fxload -D "$dev" -tfx2lp -I erase_eeprom.ihx -v
elif [ "$1" = "-T" ]; then # test
  fxload -D "$dev" -tfx2lp -I cdc_acm.ihx -v
else # flash
  fxload -D "$dev" -tfx2lp -I cdc_acm.ihx -s vend_ax.hex -c 0x41 -v
fi
