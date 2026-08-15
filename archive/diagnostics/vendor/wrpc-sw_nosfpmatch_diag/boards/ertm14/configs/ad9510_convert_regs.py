#!/usr/bin/python

import sys
import re


n_regs = 0;
regs = []

for l in open(sys.argv[1],"rb").readlines():
    r = re.match('^"(\w+)","\w+","(\w+)"', l)
    if r != None:
        addr = int(r.group(1), 16)
        value = int(r.group(2), 16)
        regs += [(addr,value)]
        n_regs+=1

print("{")
print("%d," % n_regs)
print("{")

for r in regs:
    print(" { 0x%02x, 0x%02x }, " % r );

print("}\n};\n")
