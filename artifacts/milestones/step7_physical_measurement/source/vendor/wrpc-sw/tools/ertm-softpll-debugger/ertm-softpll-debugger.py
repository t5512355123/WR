#!/usr/bin/python

import matplotlib.pyplot as plt
import numpy
import sys
import time
import serial
import struct
import getopt
import signal
import sys

kill_usb = False

def signal_handler(sig, frame):
        global kill_usb
        print('You pressed Ctrl+C!')
        kill_usb = True
        sys.exit(0)

class SerialIF:
    def __init__(self, device="/dev/ttyUSB1"):
        self.ser = serial.Serial(
            port=device, baudrate=921600, timeout=0, rtscts=False)
        #self.ser.set_buffer_size(rx_size = 12800, tx_size = 12800)

    def reset_board(self):
        self.ser.setRTS(True)
        time.sleep(0.01)
        self.ser.setRTS(False)
        time.sleep(0.01)
        self.ser.setRTS(True)
        time.sleep(0.01)

    def send(self, x, wait=0):
        if isinstance(x, int):
            self.ser.write(struct.pack("B", x))
        elif isinstance(x, str):
            #print("SendSTR '%s'" % x)
            for c in x:
                self.ser.write(c)
                if(wait):
                    time.sleep(wait)
        else:
            self.ser.write(x)

    def recv(self):
        global kill_usb
        while True:
            if kill_usb:
                return None
            try:
                #print("State")
                state = self.ser.read(1)
                if state == None or len(state) == 0:
                    continue
                return ord(state)
            except:
                pass

    def recv_nonblock(self):
        try:
            state = self.ser.read(1)
            return ord(state)
        except:
            return None


    def recv_n(self,n=1):
        rv=""
        for i in range(0,n):
            rv+=chr(self.recv())
        return rv

    def recv_u32(self):
        return struct.unpack(">I", self.recv_n(4))


    def purge(self, timeout=0.2):
        t_start = time.time()
        n=0
        #print("Purge strt\n")
        while(time.time() < t_start + timeout):
            k = self.recv_nonblock()
            if k != None:
                #print('RX %c', chr(k))
                n+=1
        #print("Purged %d bytes" % n)

import threading
def sign_extend(value, bits):
    sign_bit = 1 << (bits - 1)
    return (value & (sign_bit - 1)) - (value & sign_bit)

class SPLLSample:
    EVT_START = 1
    EVT_LOCKED = 2
    EVT_GAIN_SWITCH = 3

    DBG_Y = 0
    DBG_ERR = 1
    DBG_TAG = 2
    DBG_REF = 5
    DBG_PERIOD = 3
    DBG_SAMPLE_ID = 6
    DBG_GAIN = 7


    DBG_TAG_MASK = 0x70
    DBG_TAG_SHIFT = 4

    DBG_EVENT = 0x40
    DBG_HELPER = 0x20
    DBG_EXT = 0x10
    DBG_MAIN = 0x0


    def __init__(self,id=0):
        self.is_event = False
        self.event_id = 0
        self.m_y = None
        self.h_y = None
        self.m_ref = None
        self.m_tag = None
        self.m_err = None
        self.h_err = None
        self.m_gain_stage = None
        self.id = id

    def parse(self, x):
        last = True if (x & 0x80000000) else False
        value = x & 0xffffff
        what = x >> 24
        if ( what & self.DBG_TAG_MASK ) == self.DBG_MAIN:
            if ( what & 0xf ) == self.DBG_Y:
                self.m_y = value
            elif ( what & 0xf ) == self.DBG_GAIN:
                self.m_gain_stage = value * 10000
            elif ( what & 0xf ) == self.DBG_ERR:
                self.m_err = sign_extend(value,24)
            elif ( what & 0xf ) == self.DBG_REF:
                self.m_ref = value
            elif ( what & 0xf ) == self.DBG_TAG:
                self.m_tag = value
        elif ( what & self.DBG_TAG_MASK ) == self.DBG_HELPER:
            if ( what & 0xf ) == self.DBG_Y:
                self.h_y = value
            elif ( what & 0xf ) == self.DBG_ERR:
                self.h_err = sign_extend(value,24)
        elif ( what & self.DBG_EVENT ):
            self.is_event = True
            evt_str = ""
            if (what & 0x30) == self.DBG_HELPER:
                evt_str="helper"
            elif (what & 0x30) == self.DBG_MAIN:
                evt_str="main"
            evt_str+="-"
            if(value & 0xf) == self.EVT_START:
                evt_str+="start"
            elif(value & 0xf) == self.EVT_LOCKED:
                evt_str+="locked"
            elif(value & 0xf) == self.EVT_GAIN_SWITCH:
                evt_str+="gain-switch"
            self.event_id =evt_str
#            print("Event %x" % self.event_id)
        return last


class LoggerThread(threading.Thread):
    def __init__(self, port):
        threading.Thread.__init__(self)
        self.port = port
        self.samples=[]
        self.finish = False
        self.n_samples = 0

    def run(self):
        print("Logger started\n")
        nsamples = 0
        self.n_samples = nsamples

        syncw = [ 0, 0, 0, 0];
        #print(len(syncw[0:3]))
        while not self.finish:
            syncw = [ syncw[1], syncw[2], syncw[3], self.port.recv() ];
            #print("%x %x %x %x" % (syncw[0], syncw[1], syncw[2], syncw[3]))
            if syncw == [0xca, 0xfe, 0xba, 0xbe]:
                #print ("Sync Found")
                break
            nsamples += 1
            if nsamples > 100:
                return

        nsamples = 0
        s = SPLLSample(nsamples)
        while not self.finish:
            self.port.send('x'[0])
            ns = self.port.recv_u32()[0]
            #print("ns %d" % ns)
            for i in range(0, ns):
                x = self.port.recv_u32()[0]
                #if x & 0xff000000 == 0x20000000:
                    #sys.stdout.write("* ")
                #print("%08x" % x)
                if( s.parse(x) ):
                    self.samples.append(s)
                    s = SPLLSample(nsamples)
                    nsamples+=1
                    self.n_samples = nsamples
            #if nsamples > 10:
             #   break
            x = self.port.recv_u32()[0]
            #print("Last %x" % x)
            
        
        #for s in self.samples:
            #print(s.h_y)

    def get_samples(self):
        return self.samples

    def get_samples_count(self):
        return self.n_samples

    def kill(self):
        self.finish = True

def main(argv):
    signal.signal(signal.SIGINT, signal_handler)

    if len(argv) <= 1:
        print ("eRTM14 SoftPLL debugger - a tool for recording live SoftPLL response.\n")
        print ("Usage: %s usb_port_device [acq_time] [restart_pll]" % argv[0])
        print ("Where:")
        print (" - acq_time: optional time (in seconds) of data acquisition, default = 10s")
        print (" - restart_pll: when 1, the PLL is restarted prior to acquisition (default = 0)")
        print ("")
        print ("WARNING: This is an internal toy of WRPC developers. Don't ask for any support or documentation.")
        return

    our_port = argv[1]
    acq_time = 10 if len(argv) <= 2 else int(argv[2])
    restart_pll = 1 if len(argv) <= 3 else int(argv[3])
    port = SerialIF( device = our_port )

    port.send(chr(0x1b), wait=0.1);
    port.send(chr(0x1b), wait=0.1);

    port.purge();
    port.send('\r\rptp stop\r', wait=0.01);
    port.purge();
    port.send('\r\rpll init 4 0 0\r', wait=0.01);
    port.purge();
    port.send('pll init 3 0 0\r', wait=0.01);
    port.purge();
    port.send('pll dbgdump\r', wait=0.01);

    meas_thread = LoggerThread(port)
    meas_thread.start()

    #while True:
        #n = len( meas_thread.get_samples() )
        #print("Acquired %d samples\n" % n )
        #if n > 100:
            #break
        #time.sleep(0.2)
    
    for i in range(0, acq_time):
        sys.stdout.write('Acquiring data (got %d samples, %d seconds to go)         \r' %( meas_thread.get_samples_count(),  acq_time - i) )
        sys.stdout.flush()
        time.sleep(1)

    meas_thread.kill()
    meas_thread.join()

    samples = meas_thread.get_samples()
    n = len(samples)
    print(n)
    ht=[]
    hy=[]
    herr=[]
    mt=[]
    my=[]
    merr=[]
    events=[]
    mref=[]
    mtag=[]
    mstage=[]
    for s in samples:
        if s.h_y != None:
            ht.append( s.id )
            hy.append( s.h_y )
            herr.append( s.h_err )
        if s.m_y != None:
            mt.append( s.id )
            my.append( s.m_y )
            mref.append( s.m_ref )
            mtag.append( s.m_tag )
            merr.append( s.m_err )
            mstage.append( s.m_gain_stage )


        if s.is_event:
            events.append(s)
            
    #print(my)
#    print (map( lambda s : s.h_y, samples ))
 #   plt.plot(t, map( lambda s : s.h_y, samples ) )
    plt.plot(ht, hy, label = "helper[y]")
    plt.plot(ht, herr, label = "helper[err]")
    plt.plot(mt, my, label = "main[y]")
    plt.plot(mt, merr, label = "main[err]")
    #plt.plot(mt, mstage, label = "main[stage]")
    #plt.plot(mt, mref, label = "main[int]")

    #plt.plot(mt, mref, label = "main[ref tag]")
    #plt.plot(mt, mtag, label = "main[fb tag]")
    plt.legend();

    f_out = open("hpll.csv","wb")
    f_out.write("ERROR DAC\n")
    for s in samples:
        if s.h_y != None:
            f_out.write("%d %d\n" % (s.h_err, s.h_y) )
    f_out.close()
    
    f_out = open("mpll.csv","wb")
    f_out.write("ERROR DAC\n")
    for s in samples:
        ref = s.m_ref if s.m_ref != None else 0
        fb = s.m_tag if s.m_tag != None else 0
        y = s.m_y if s.m_y != None else 0
        err = s.m_err if s.m_err != None else 0
        f_out.write("%d %d %d %d\n" % (err, y, ref, fb) )
    f_out.close()
            

    for e in events:
        print("PROCEVT %s" % e.event_id)
        plt.text(e.id, 0, e.event_id, rotation="vertical")



    plt.grid()
    plt.show()


if __name__ == "__main__":
    main(sys.argv)
