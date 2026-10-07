#!/bin/sh
set -e

for i in 1 2 3 4 5 6 7 8 9; do
  echo
  echo "Scenario $i"
  vsim -quiet -gg_scenario=$i -c -do "set NumericStdNoWarnings 1; run 5us; quit" top_tb | tee sim.log
  # check log
  if grep -F '# ** ' sim.log | grep -E -v 'Note|Warning'; then
    echo "Simulation failed!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
  fi
  if ! grep -F "# ** Note: end of simulation" sim.log; then
    echo "Simulation failed!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
  fi
done

echo "OK!"
