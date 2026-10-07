#!/bin/sh
set -e

GHDL=${GHDL:-ghdl}

for i in 1 2 3 4 5 6 7 8 9 11; do
  echo
  echo "Scenario $i"
  $GHDL -r --ieee=synopsys top_tb -gg_scenario=$i --stop-time=5us --assert-level=error --ieee-asserts=disable-at-0 | tee sim.log
  if [ $? != 0 ]; then
    echo "Simulation failed!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
  fi
  # check log
  if ! grep -q -F "end of simulation" sim.log; then
    echo "Simulation failed!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
  fi
done

echo "OK!"
