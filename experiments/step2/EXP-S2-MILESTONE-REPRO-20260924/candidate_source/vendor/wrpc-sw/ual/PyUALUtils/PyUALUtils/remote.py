import subprocess
import ctypes
from ctypes.util import find_library

class UALBase(object):
    def get_bus_list(self):
        raise NotImplemented

    def get_pci_list(self):
        raise NotImplemented

    def iomap_pci(self, devid, dw, bar, size, offset, flags):
        raise NotImplemented

    def iomap_vme(self, dw, am, size, offset, flags):
        raise NotImplemented

    def iomap(self):
        raise NotImplemented

    def unmap(self):
        raise NotImplemented

    def readl(self, off):
        raise NotImplemented

    def readw(self, off):
        raise NotImplemented

    def writel(self, off, val):
        raise NotImplemented

    def writew(self, off, val):
        raise NotImplemented


class UALLocal(UALBase):
    def __init__(self):
        import PyUAL
        self.PyUAL = PyUAL

        libc = ctypes.CDLL(find_library('c'))
        self.pagesize = libc.getpagesize()

    def get_bus_list(self):
        return [b for b in self.PyUAL.bus_available()]

    def get_pci_list(self):
        pci_list = subprocess.check_output("lspci | awk '{print $1}'",
                                           shell=True).split()
        return pci_list

    def iomap_vme(self, dw, am, size, offset, flags):
        size = (size + self.pagesize - 1) & ~(self.pagesize - 1)
        desc = self.PyUAL.PyUALVME(ctypes.c_uint32(dw),
                                   ctypes.c_uint32(am),
                                   ctypes.c_uint64(size),
                                   ctypes.c_uint64(offset),
                                   ctypes.c_uint64(flags))
        self.ual = self.PyUAL.PyUAL('vme', desc)

    def iomap_pci(self, devid, dw, bar, size, offset, flags):
        size = (size + self.pagesize - 1) & ~(self.pagesize - 1)
        desc = self.PyUAL.PyUALPCI(ctypes.c_uint64(devid),
                                   ctypes.c_uint32(dw),
                                   ctypes.c_uint32(bar),
                                   ctypes.c_uint64(size),
                                   ctypes.c_uint64(offset),
                                   ctypes.c_uint64(flags))
        self.ual = self.PyUAL.PyUAL('pci', desc)

    def unmap(self):
        self.ual = None

    def readl(self, off):
        return self.ual.readl(off)

    def readw(self, off):
        return self.ual.readw(off)

    def writel(self, off, val):
        self.ual.writel(off, val)

    def writew(self, off, val):
        self.ual.writew(off, val)


class UALRemote(UALBase):
    def __init__(self, uri):
        import xmlrpc.client
        xmlrpc.client.Marshaller.dispatch[int] = \
            lambda _, v, w: w("<value><i8>%d</i8></value>" % v)
        self.client = xmlrpc.client.ServerProxy(uri)

    def get_bus_list(self):
        return self.client.get_bus_list()

    def get_pci_list(self):
        return self.client.get_pci_list()

    def iomap_vme(self, dw, am, size, offset, flags):
        self.client.iomap_vme(dw, am, size, offset, flags)

    def iomap_pci(self, devid, dw, bar, size, offset, flags):
        self.client.iomap_pci(devid, dw, bar, size, offset, flags)

    def unmap(self):
        self.client.unmap()

    def readl(self, off):
        return self.client.readl(off)

    def readw(self, off):
        return self.client.readw(off)

    def writel(self, off, val):
        self.client.writel(off, val)

    def writew(self, off, val):
        self.client.writew(off, val)
