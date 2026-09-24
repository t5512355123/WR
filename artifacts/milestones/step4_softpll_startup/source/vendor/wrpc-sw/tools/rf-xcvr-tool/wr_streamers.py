#!/usr/bin/python

import rawsocketpy
import sys
import os
import struct
import time



def a2s(a):
    if(type(a) == str):
        return a
    s=b""
    for b in a:
        s+=chr(b)
    return s

class Bitfield(object):
    def __init__(self, owner, offset, width=1):
        self.owner = owner
        self.offset = offset
        self.width = width
        self.raw_value = 0
        self.bitmap = None
    
    @property
    def value(self):
        return self.raw_value

    @value.setter
    def value(self, value):
        self.raw_value = value
        self.owner.update_field(self)

class StreamerFrame(object):
    def __init__(self, streamers):
        self.streamers = streamers
        self.raw_data = None
        self.payload=[]
        for x in range (0, streamers.g_data_width / 16):
            self.payload += [0]
        #print("OPLEN", len(self.payload))
        self.rx_valid = None
        
    def set_bit(self,offset,value):
        #print("setbit offset %d avl %d" % (offset, value))
        if(value):
            self.payload[offset/16] |= ( 1<< (offset & 0xf))
        else:
            self.payload[offset/16] &= ~( 1<< (offset & 0xf))
        #print("PLENs", len(self.payload))

    def update_field(self, field):
        if field.bitmap:
            for b in range(0,field.width):
                self.set_bit( b + field.offset, field.value & (1<<field.bitmap[b] ) )
        else:
            for b in range(0,field.width):
                self.set_bit( b + field.offset, field.value & (1<<b) )

    def escape(self,data):
        rv=[]
        for d in data:
            if d & 0x10000:
                rv+=[0xcafe]
                rv+=[d & 0xffff]
            elif d == 0xcafe:
                rv+=[0xcafe]
                rv+=[0]
            else:
                rv+=[d]
        return rv
            

    def unescape(self,data):
        rv = []
        pos = 0
        while(pos < len(data)):
            b = struct.unpack(">H", a2s(data[pos : pos + 2]) )[0]
            if ( b == 0xcafe ):
                pos += 2
                b2 = struct.unpack(">H", a2s(data[pos : pos + 2]) )[0]
                rv += [ 0x10000 | b2 ]
            else:
                rv += [ b ]
            pos+=2
        return rv

    def formatPayload(self,payload):
        rv=""
        for x in payload:
            rv += "%04x " % x
        return rv

    def formatTimestamp(self,ts):
        if ts == None:
            return "invalid"
        else:
            return "%d" %  ts

    def crc16(self, data):
        crc = 0xFFFF
        for i in range(0, len(data)):
            crc ^= ((data[i] & 0xff) << 8)
            for j in range(0,8):
                if (crc & 0x8000) > 0:
                    crc =(crc << 1) ^ 0x1021
                else:
                    crc = crc << 1
    
            crc ^= data[i] & 0xff00
            for j in range(0,8):
                if (crc & 0x8000) > 0:
                    crc =(crc << 1) ^ 0x1021
                else:
                    crc = crc << 1
        
        return crc & 0xFFFF


    def pack16(self,data):
        rv=[]
        i=0
        #print("Pack l", len(data))
        while i < len(data):
            rv += [ (data[i] << 8) | data[i+1] ]
            i+=2

        #for r in rv:
            #print("%04x" % r)
        return rv

    def unpack16(self,data):
        rv=[]
        i=0
        while i < len(data):
            rv += [ (data[i] >> 8) & 0xff ]
            rv += [ (data[i] ) & 0xff ]
            i+=1

        #for r in rv:
            #print("%02x" % r)
        return rv


    def reverse(self,x, n):
        rv=[]
        for k in x:
            result = 0
            for i in xrange(n):
                if (k >> i) & 1: result |= 1 << (n - 1 - i)
            rv += [result]
        return rv

    # fuck, i'm sick of this bit twiddling
    def streamer_crc16(self, data):
        import copy
        d2 = copy.copy(data)
        data_packed_rev = self.reverse( d2, 16)
        crc = 0xffff^self.crc16( data_packed_rev )
        crc = self.reverse([crc], 16)[0]
        return (crc >> 8) | ((crc << 8) & 0xff00)

    def decode(self, data):
        self.raw_data = data
        self.mac_dst = self.raw_data[0:6]
        self.mac_src = self.raw_data[6:12]
        self.ethertype = struct.unpack(">H", a2s(self.raw_data[12:14]) )[0]

        print("DST  : %02x:%02x:%02x:%02x:%02x:%02x"% (self.mac_dst[0],self.mac_dst[1],self.mac_dst[2],self.mac_dst[3],self.mac_dst[4],self.mac_dst[5]))
        print("SRC  : %02x:%02x:%02x:%02x:%02x:%02x"% (self.mac_src[0],self.mac_src[1],self.mac_src[2],self.mac_src[3],self.mac_src[4],self.mac_src[5]))
        print("ETH  : %04x" % self.ethertype)
        
        ts0 = struct.unpack(">H", a2s(self.raw_data[14:16]) )[0]
        ts1 = struct.unpack(">H", a2s(self.raw_data[16:18]) )[0]
        

        if ts0 == 0xffff:
            self.tx_timestamp = None
        else:
            self.tx_timestamp = (ts0 << 16) | ts1
        
        print("TXTS : %s" % self.formatTimestamp( self.tx_timestamp) )

        self.seq = struct.unpack(">H", a2s(self.raw_data[18:20]) )[0]
        print("SEQ  : %d " % self.seq)

        payload = self.unescape( self.raw_data [ 20:] )
        
        pos = 0
        shdr = 0
        if pos > 0:
            shdr = payload[pos]
            pos += 1
            if shdr == 0x10bad:
                return
            else:
                shdr = 0

            self.payload = payload[pos : pos + self.streamers.g_data_width / 16]

            crc_ref = self.crc16([self.seq] + self.payload)
            crc = payload[pos]
            print("SFR  : %04x [%s] crc %x %x" % (shdr, self.formatPayload(subframe), crc, crc_ref))

            pos += 1

        #print("subframes: %d\n" % len(self.subframes))

    def swap_words(self, x):
        rv= []
        i=0
        while i < len(x) - 1:
            rv += [ x[i+1] ]
            rv += [ x[i] ]
            i += 2
        return rv


    def encode(self):
        #print("PlenE ", len(self.payload))
        
        seq = self.streamers.next_tx_seq()
        raw_payload=[ (self.tx_timestamp >> 16) & 0xffff, (self.tx_timestamp & 0xffff), 0x8000 | seq ]
        raw_payload += self.escape( self.payload )
        crc_in = [ 0x8000 | seq ] + self.payload
        #print("crcin;")
        #for k in crc_in:
        #    print("%04x" % k)

        raw_payload += [ self.streamer_crc16( [ 0x8000 | seq ] + self.payload ) ]
        #print(raw_payload)
        #print("PAYLOAD: ")
        #for k in self.payload:
            #print("P %04x" % k)

        while len(raw_payload) < 32:
            raw_payload += self.escape( [0x10bad] )

    	#for k in raw_payload:
	     #   print("%04x" % k )

        payload_b8 = ""

        for k in raw_payload:
            payload_b8 += chr( (k >> 8) & 0xff)
            payload_b8 += chr( (k) & 0xff)

        print("B8 payload (%d bytes): " % len(payload_b8))
        for b in payload_b8:
            sys.stdout.write("%02x " % ord(b) )
        print("")

        return payload_b8


class StreamersIface:
    def __init__(self, interface="enp114s0", ptp_snooping = False ):
        self.sock = rawsocketpy.RawSocket(interface, 0xdbff)
        self.sock_ptp = rawsocketpy.RawSocket(interface, 0x88f7)
        self.g_data_width = 6 * 32 + 16
        self.tx_seq = 0
        self.ptp_snooping = ptp_snooping

    def next_tx_seq(self):
        r = self.tx_seq
        self.tx_seq+=1
        return r

    def send(self, frame):
        payload8 = frame.encode()
        self.sock.send ( payload8, ethertype='\xdb\xff')

    def recv(self, frame):
        pass
