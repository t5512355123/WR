#!/usr/bin/env python3
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

"""@package docstring

@author: Federico Vaga <federico.vaga@cern.ch>
@copyright: Copyright (c) 2014 CERN
@license: LGPLv3
"""

from ctypes import *
import errno
import mmap
import os
import os.path

libual_default_name = 'libual.so'
libual_path_env = 'LIBUAL_PATH'
libual = None

def load_libual(libual_path=None):

    """determine libual.so location in order: explicit, environment
       or system default
    """

    libual_path = libual_path or os.getenv(libual_path_env)
    libual_name = libual_default_name
    if libual_path:
        libual_name = os.path.join(libual_path, libual_default_name)
    try:
        libual = CDLL(libual_name, use_errno=True)
    except OSError:
        libual = None
    if libual is None:
        print("could not load libual as %s" % libual_name)
        exit(1)
    return libual

libual = load_libual()

class PyUALPCI(Structure):
    """PCI mapping descriptor
    PyUALPCI(<pci-id>, <data-width-byte>, <bar>, <size>, <offset>, <flags>)
    """
    _fields_ = [
        ("devid", c_uint64),
        ("data_width", c_uint32),
        ("bar", c_uint32),
        ("size", c_uint64),
        ("offset", c_uint64),
        ("flags", c_uint64),
    ]

    def __str__(self):
        return "PCI: Device: %02x:%02x.%x, BAR: %d, Offset: 0x%x, Size: 0x%x, DataWidth:%d" % \
            ((self.devid >> 16) & 0xFF,
             (self.devid >> 8) & 0xFF,
             (self.devid) & 0xFF,
             self.bar, self.offset, self.size, self.data_width)



class PyUALVME(Structure):
    """VME mapping descriptor
    PyUALVME(<data-width-byte>, <am>, <size>, <offset>, <flags>)
    """
    _fields_ = [
        ("data_width", c_uint32),
        ("am", c_uint32),
        ("size", c_uint64),
        ("offset", c_uint64),
        ("flags", c_uint64),
    ]

    def __str__(self):
        return "VME: AM: 0x%x, Offset: 0x%x, Size: 0x%x, DataWidth:%d" % \
            (self.am, self.offset, self.size, self.data_width)



class timespec(Structure):
    """Data structure representing `struct timespec`"""
    _fields_ = [
        ('tv_sec', c_long),
        ('tv_nsec', c_long)
    ]


class PyUALException(Exception):
    """Dedicated Exception for the UAL class"""
    def __init__(self, msg):
        """It initialize the UAL exception

        Keyword arguments:
        msg: message to show
        """
        super(PyUALException, self).__init__(msg)


def bus_available():
    """
    It provides information about the available (supported) buses

    Return:
    It returns a dictionary with all supported busses in the form:
            <key>: <value>  =>  <bus-name>: <id>
    """
    buses = {}
    if hasattr(libual, 'ual_pci'):
        buses["pci"] = 0
    if hasattr(libual, 'ual_vme'):
        buses["vme"] = 1
    return buses


def strerror(errnumber):
    """It returns a string corresponding to the given error code

    Keyword arguments:
    errnumber -- error code
    """
    libual.ual_strerror.restype = c_char_p
    return libual.ual_strerror(errnumber)


class PyUAL(object):
    """
    Python wrapper for libual C library.

    This is just a wrapper of the C library. The pydoc associated to this
    class is (more or less) the same doxygen documentation from the C library.
    During time it is possible that both document are not aligned. So, if
    unsure refer to the C library documentation.
    """

    def __init__(self, busname, desc, libual_path=None):
        """It binds to 'libual.so', initialize the library and open it

        Keyword arguments:
        busname -- name of the bus to use: 'pci', 'vme'
        desc -- the memory map descriptor to map a range of addressed
                   on the given bus
        libual_path -- path to libual.so directory, overrides
                    LIBUAL_PATH and system default

        Exceptions:
        OSError - on C library errors
        ValueError -- on invalid parameters checks by this class
        PyUALException -- errors from the UAL library
        """

        self.libual = libual

        # open the UAL device
        self.tkn = self.open(busname, desc)

    def __del__(self):
        """It closes the UAL device"""
        self.close()

    def __str__(self):
        """It returns  a string representing the mapped address space"""
        return str(self.desc)

    def _int(self, num):
        """Convert string into integer

        It tries with decimal format, hexadecimal and then octal.

        Keyword arguments:
        num -- string representing a number in dec, hex or oct format
        """
        try:
            return int(num)
        except Exception as e:
            try:
                return int(num, 16)
            except Exception as e:
                return int(num, 8)

    def open(self, busname, desc):
        """It opens and maps and address space

        After some preliminary check it calls the UAL library function ual_open()
        Usually, this is not necessary since any instance of PyUAL
        automatically maps the given address space when created

        Keyword arguments:
        busname -- name of the bus to use: 'pci', 'vme'
        desc -- the memory map descriptor to map a range of addressed
                   on the given bus

        Exceptions:
        OSError - on C library errors
        ValueError -- on invalid parameters checks by this class
        PyUALException -- errors from the UAL library

        Return:
        It returns a token that uniquely identify the memory mapped area
        """
        if busname not in bus_available():
            raise ValueError("Invalid bus name")
        if desc is None:
            raise ValueError("Invalid memory map descriptor")

        self.busname = busname
        self.desc = desc

        ual_open = self.libual.ual_open
        ual_open.argtypes = [c_int, c_void_p]
        ual_open.restype = POINTER(c_void_p)

        ret = ual_open(bus_available()[self.busname], byref(self.desc))
        if not ret:
            raise PyUALException(strerror(get_errno()))
        return ret

    def close(self):
        """It closes a given UAL device

        If still open it calls the UAL library function ual_close().
        Usually, this is not necessary since any PyUAL instance will be closed
        when the instance will be destroied

        Exceptions:
        OSError -- from the C library
        """
        if hasattr(self, "tkn"):
            self.libual.ual_close(self.tkn)

    def get_descriptor(self):
        """It returns a dictionary describing the memory mapped area"""
        return {"bus":self.busname, "desc": self.desc}

    def writel(self, addr, value):
        """It writes into memory 32bit value(s)

        It routes the call to the corresponent UAL library function.
        You can provide a single value or a list of values. If you provide
        a list of values they will be written in consecutive addresses
        starting from the given one.

        Keyword arguments:
        addr -- address offset within the memory mapped space
        value -- an integer value (or a list of them)

        Exceptions:
        OSError - on C library errors
        """
        if isinstance(value, list):
            n = len(value)
            arr = (c_uint32 * n)(*value)
            self.libual.ual_writel_n.argtypes = [c_void_p, c_uint32,
                                                 POINTER(c_uint32), c_int]
            self.libual.ual_writel_n(self.tkn, c_uint32(self._int(addr)),
                                     arr, n)
        else:
            self.libual.ual_writel(self.tkn, c_uint32(self._int(addr)),
                                   c_uint32(self._int(value)))

    def readl(self, addr, count=1):
        """It reads from the memory a value or a list of values (32 bit)

        It routes the call to the corresponent UAL library function.

        Keyword arguments:
        addr -- address offset within the memory mapped space
        count -- number of values to read (default: 1)

        Exceptions:
        OSError - on C library errors
        ValueError - when a negative value of count is provided

        Return:
        An integer value when count is 1, otherwise a list of integer values
        """

        if count == 1:
            return c_uint32(self.libual.ual_readl(self.tkn,
                                                  c_uint32(self._int(addr)))).value
        elif count > 1:
            arr = (c_uint32 * count)()
            self.libual.ual_readl_n.argtypes = [c_void_p, c_uint32,
                                                POINTER(c_uint32), c_int]
            self.libual.ual_readl_n(self.tkn, c_uint32(self._int(addr)),
                                    arr, count)
            return [arr[i] for i in range(count)]
        else:
            raise ValueError("The variable 'count' can't be negative")

    def writew(self, addr, value):
        """It writes into memory 16bit value(s)

        It routes the call to the corresponent UAL library function.
        You can provide a single value or a list of values. If you provide
        a list of values they will be written in consecutive addresses
        starting from the given one.

        Keyword arguments:
        addr -- address offset within the memory mapped space
        value -- an integer value (or a list of them)

        Exceptions:
        OSError - on C library errors
        """
        if isinstance(value, list):
            n = len(value)
            arr = (c_uint16 * n)(*value)
            self.libual.ual_writew_n.argtypes = [c_void_p, c_uint32,
                                                 POINTER(c_uint16), c_int]
            self.libual.ual_writew_n(self.tkn, c_uint32(self._int(addr)),
                                     arr, n)
        else:
            self.libual.ual_writew(self.tkn, c_uint32(self._int(addr)),
                                   c_uint16(self._int(value)))

    def readw(self, addr, count=1):
        """It reads from the memory a value or a list of values (16 bit)

        It routes the call to the corresponent UAL library function.

        Keyword arguments:
        addr -- address offset within the memory mapped space
        count -- number of values to read (default: 1)

        Exceptions:
        OSError - on C library errors
        ValueError - when a negative value of count is provided

        Return:
        An integer value when count is 1, otherwise a list of integer values
        """

        if count == 1:
            return c_uint16(self.libual.ual_readw(self.tkn,
                                                  c_uint32(self._int(addr)))).value
        elif count > 1:
            arr = (c_uint16 * count)()
            self.libual.ual_readw_n(self.tkn, c_uint32(self._int(addr)),
                                    arr, count)
            return [arr[i] for i in range(count)]
        else:
            raise ValueError("The variable 'count' can't be negative")

    def writeb(self, addr, value):
        """It writes into memory 8bit value(s)

        It routes the call to the corresponent UAL library function.
        You can provide a single value or a list of values. If you provide
        a list of values they will be written in consecutive addresses
        starting from the given one.

        Keyword arguments:
        addr -- address offset within the memory mapped space
        value -- an integer value (or a list of them)

        Exceptions:
        OSError - on C library errors
        """
        if isinstance(value, list):
            n = len(value)
            arr = (c_uint8 * n)(*value)
            self.libual.ual_writeb_n.argtypes = [c_void_p, c_uint32,
                                                 POINTER(c_uint8), c_int]
            self.libual.ual_writeb_n(self.tkn, c_uint32(self._int(addr)),
                                     arr, n)
        else:
            self.libual.ual_writeb(self.tkn, c_uint32(self._int(addr)),
                                   c_uint8((self._int(value))))

    def readb(self, addr, count=1):
        """It reads from the memory a value or a list of values (32 bit)

        It routes the call to the corresponent UAL library function.

        Keyword arguments:
        addr -- address offset within the memory mapped space
        count -- number of values to read (default: 1)

        Exceptions:
        OSError - on C library errors
        ValueError - when a negative value of count is provided

        Return:
        An integer value when count is 1, otherwise a list of integer values
        """

        if count == 1:
            return c_uint8(self.libual.ual_readb(self.tkn,
                                                 c_uint32(self._int(addr)))).value
        elif count > 1:
            arr = (c_uint8 * count)()
            self.libual.ual_readb_n(self.tkn, c_uint32(self._int(addr)),
                                    arr, count)
            return [arr[i] for i in range(count)]
        else:
            raise ValueError("The variable 'count' can't be negative")

    def event_wait(self, addr, mask, period=100000, timeout=10000000):
        """It waits for an event to happen on the given register (address)

        It routes the call to the corresponent UAL library function

        Keyword arguments:
        addr -- offset within the selected BAR
        mask -- bitmask to apply on the read value
        period -- polling period in microseconds
        timeout -- timeout for the event to occur in microseconds.
                   It will updated with the time left
        Exceptions:
        OSError - on C library errors

        Return:
        It returns the value that triggered the event (already masked).
        0 on error and errno is appropriately set.
        """
        ual_event_wait = self.libual.ual_event_wait
        ual_event_wait.argtypes = [c_void_p, c_uint64, c_uint64,
                                   POINTER(timespec), POINTER(timespec)]
        ual_event_wait.restype = c_uint64

        p = timespec()
        p.tv_sec = int(period / 1000000)
        p.tv_nsec = period - (p.tv_sec * 1000000)
        t = timespec()
        t.tv_sec = int(timeout / 1000000)
        t.tv_nsec = timeout - (t.tv_sec * 1000000)
        return c_uint64(ual_event_wait(self.tkn, c_uint64(self._int(addr)),
                                       c_uint64(self._int(mask)),
                                       byref(p), pointer(t))).value
