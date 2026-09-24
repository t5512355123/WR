#!/usr/bin/python

import sys
import time
import wr_streamers


class RFKinkySwappedBitfield(wr_streamers.Bitfield):
    def __init__(self, owner, offset, width=1 ):
        super(RFKinkySwappedBitfield, self).__init__(owner, offset, width=width)
        if width == 1:
            if offset % 32 >= 16:
                self.bitmap = [ offset - 16 ]
            else:
                self.bitmap = [ offset + 16 ]

        self.bitmap = range(16,32) + range(0, 16)
        #print(self.bitmap)

class RFMFrame(wr_streamers.StreamerFrame):
    def __init__(self, streamers):
        super(RFMFrame, self).__init__(streamers)
        #print("plen: %d" % len(self.payload))
        self.control = wr_streamers.Bitfield(self, 0, 16)
        self.rfm0 = RFKinkySwappedBitfield(self, 0+16, 32)
        self.rfm1 = RFKinkySwappedBitfield(self, 32+16, 32)
        self.rfm2 = RFKinkySwappedBitfield(self, 64+16, 32)
        self.rfm3 = RFKinkySwappedBitfield(self, 96+16, 32)
        self.rfm4 = RFKinkySwappedBitfield(self, 128+16, 32)
        self.rfm5 = RFKinkySwappedBitfield(self, 160+16, 32)

        self.control.value = 0x0042
        self.rfm0.value = 0x00000000
        self.rfm1.value = 0x00000001
        self.rfm2.value = 0x00000002
        self.rfm3.value = 0x00000003
        self.rfm4.value = 0xdeadbeef
        self.rfm5.value = 0x01234567


streamers = wr_streamers.StreamersIface(interface="enp114s0")

frame = RFMFrame(streamers)


while True:
    print("sendstrem\n")
    frame.tx_timestamp = 0xffff98e2 #fd90
    frame.rfm5.value = 0
    streamers.send( frame )
    time.sleep(0.1)
    frame.rfm5.value = 1
    streamers.send( frame )
    time.sleep(0.1)


