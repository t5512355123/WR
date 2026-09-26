"""@package docstring

@author: Federico Vaga <federico.vaga@cern.ch>
@copyright: Copyright (c) 2014 CERN
@license: LGPLv3
"""

import tkinter as tk
import tkinter.font
import tkinter.filedialog
import tkinter.ttk as ttk

try:
    import cheby.tree
    import cheby.parser
    import cheby.layout
    import cheby.expand_hdl
    with_cheby = True
except ImportError as e:
    with_cheby = False

import os
import re
import time
import yaml
import threading
import PyUALUtils.remote
import argparse

poll_list_lock = threading.Lock()
poll_list = []
gual = None
tab_view = False
opt_filename = None

class Register(tk.Frame):
    def __init__(self, parent, base_address, reg):
        self.parent = parent
        self.register = reg
        self.address = base_address + self.register["offset"]
        super(Register, self).__init__(self.parent)

        print("Discover Register '%s' at absolute offset '0x%x'" %
              (self.register["name"], self.address))
        self.initUI()
        self.register_update()

    def destroy(self):
        print("Remove %s '%s'" % (type(self), self.register["name"]))
        poll_list_lock.acquire()
        if self in poll_list:
            poll_list.remove(self)
        poll_list_lock.release()

        super(Register, self).destroy()

    def initUI(self):
        # since all the widgets have the same size except for the
        # label, use RIGHT side
        self.poll = tk.IntVar()
        self.chk_poll = tk.Checkbutton(self, text="Update on Poll",
                                       variable=self.poll,
                                       command=self.__poll_mode_toggle)
        self.chk_poll.pack(side=tk.RIGHT)

        self.btn_set = tk.Button(self, text="SET", command=self.set_value)
        self.btn_set.pack(side=tk.RIGHT)

        self.btn_get = tk.Button(self, text="GET", command=self.get_value)
        self.btn_get.pack(side=tk.RIGHT)

        self.ent_value = tk.Entry(self)
        self.ent_value.pack(side=tk.RIGHT)

        self.cmb_fmt = ttk.Combobox(self, width=6, state="readonly",
                                    values=["hex", "dec", "oct", "ascii"])
        self.cmb_fmt.current(0)
        self.cmb_fmt.pack(side=tk.RIGHT)
        self.cmb_fmt.bind("<<ComboboxSelected>>", self.change_fmt)

        self.cmb_end = ttk.Combobox(self, width=3,
                                    values=["LE", "BE"],
                                    state="readonly")
        self.cmb_end.set(gual.bar.desc.cmb_hend.get())
        self.cmb_end.pack(side=tk.RIGHT)
        self.cmb_end.bind("<<ComboboxSelected>>", self.change_endianess)

        label = "%s (0x%08X +) 0x%04X" % \
                (self.register["name"],
                 self.address - self.register["offset"],
                 self.register["offset"])
        self.lbl_name = tk.Label(self, text=label.strip())
        self.lbl_name.pack(side=tk.RIGHT)

        self.pack(side=tk.TOP, fill=tk.X)

    def register_update(self):
        self.get_value()

    def change_fmt(self, event):
        self.get_value()

    def change_endianess(self, event):
        print("Change endianess to '%s' for  '%s' at address '0x%X'" %
              (self.cmb_end.get(), self.register["name"], self.address))
        self.get_value()

    def print_value(self, value):
        dw = int(gual.bar.desc.dw.get())
        self.ent_value.delete(0, tk.END)
        if self.cmb_fmt.get() == "hex":
            self.ent_value.insert(0, str("%0" + str(dw * 2) + "X") % value)
        elif self.cmb_fmt.get() == "dec":
            self.ent_value.insert(0, "%u" % value)
        elif self.cmb_fmt.get() == "oct":
            self.ent_value.insert(0, "%o" % value)
        elif self.cmb_fmt.get() == "ascii":
            astr = ""
            for i in range(dw - 1, -1, -1):
                astr += chr((value >> (i * 8)) & 0xFF)
            self.ent_value.insert(i, astr)
        else:
            raise Exception("Unknown data format")

    def scan_value(self):
        if self.cmb_fmt.get() == "hex":
            return int(self.ent_value.get(), 16)
        elif self.cmb_fmt.get() == "dec":
            return int(self.ent_value.get(), 10)
        elif self.cmb_fmt.get() == "oct":
            return int(self.ent_value.get(), 8)
        elif self.cmb_fmt.get() == "ascii":
            value = 0
            nbyte = int(gual.bar.dw.get())
            for i in range(0, nbyte):
                value |= ord(self.ent_value.get()[i]) << ((nbyte - 1 - i) * 8)
            return value
        else:
            raise Exception("Unknown data format")

    def fix_endianess(self, value):
        if self.cmb_end.get() == gual.bar.desc.cmb_hend.get():
            return value

        print("    Fix endianess")
        if gual.bar.desc.dw.get() == "2":
            return ((value >> 8) & 0xff) | \
                   ((value << 8) & 0xff00)
        elif gual.bar.desc.dw.get() == "4":
            return ((value >> 24) & 0xff) | \
                   ((value << 8) & 0xff0000) | \
                   ((value >> 8) & 0xff00) | \
                   ((value << 24) & 0xff000000)

    def get_value(self):
        print("Read '%s' at address '0x%X'" %
              (self.register["name"], self.address))
        if int(gual.bar.desc.dw.get()) == 2:
            value = my_ual.readw(self.address)
        elif int(gual.bar.desc.dw.get()) == 4:
            value = my_ual.readl(self.address)
        value = self.fix_endianess(value)
        print("    Value = 0x%x" % value)
        self.print_value(value)

    def set_value(self):
        print("Write '%s' at address '0x%X'" %
              (self.register["name"], self.address))
        value = self.scan_value()
        value = self.fix_endianess(value)
        print("    Value = 0x%x" % value)
        if int(gual.bar.desc.dw.get()) == 2:
            value = my_ual.writew(self.address, value)
        elif int(gual.bar.desc.dw.get()) == 4:
            my_ual.writel(self.address, value)

        self.get_value()

    def __poll_mode_toggle(self):
        poll_list_lock.acquire()
        if self.poll.get():
            poll_list.append(self)
        else:
            poll_list.remove(self)
        poll_list_lock.release()



class RegisterGroupClose(tk.Frame):
    """
    It is a simple tkinter Frame that show a close button for a RegisterGroup.
    It generates a <<RegisterGroupClosed>> event when the close button is
    pressed
    """
    def __init__(self, parent):
        self.parent = parent
        super(RegisterGroupClose, self).__init__(self.parent)
        self.initUI()

    def initUI(self):
        self.btn_enable = tk.Button(self, text="x", fg="red",
                                    activeforeground="red",
                                    command=self.remove)
        self.btn_enable.pack(side=tk.LEFT, fill=tk.X)

    def remove(self):
        self.event_generate("<<RegisterGroupClosed>>")


class RegisterGroup(tk.LabelFrame):
    def __init__(self, parent, base_address, group):
        self.parent = parent
        self.group = group
        self.subgroups = []
        if "offset" in self.group:
            self.address = base_address + self.group["offset"]
        elif "memory" in self.group:
            self.address = base_address + self.group["memory"][0]
        else:
            raise Exception("Not a valid %s, missing 'offset'/'memory'",
                            type(self))
        super(RegisterGroup, self).__init__(self.parent)

        if not isinstance(self.parent, RegisterGroup) and \
           self.group in gual.mmap.ranges["components"]:
            # It is the first grouping level for ranges (No files)
            # We can identify ranges by checking if the group to map belongs to
            # the ranges description
            self.lbl = RegisterGroupClose(self)
            self.configure(text="%s (0x%x)" % (self.group["name"],
                                               self.address),
                           borderwidth=0, labelanchor="ne",
                           labelwidget=self.lbl)
            self.lbl.bind("<<RegisterGroupClosed>>", self.__close)
        else:
            self.configure(text="%s (0x%x)" % (self.group["name"],
                                               self.address))

        print("Discover Register Group '%s' at absolute offset '0x%x'" %
              (self.group["name"], self.address))
        self.initUI()

    def destroy(self):
        print("Remove %s '%s'" % (type(self), self.group["name"]))
        # Destroy all sub groups or registers
        for g in self.subgroups:
            g.destroy()
        del self.subgroups[:]
        super(RegisterGroup, self).destroy()

    def initUI(self):
        if "registers" in self.group:
            for r in self.group["registers"]:
                print(self.address)
                self.subgroups.append(Register(self, self.address, r))
        if "map" in self.group:
            for g in self.group["map"]:
                rg = RegisterGroup(self, self.address, g)
                rg.pack(side=tk.TOP)
                self.subgroups.append(rg)

    def register_update(self):
        for g in self.subgroups:
            g.register_update()

    def __close(self, event):
        self.event_generate("<<RegisterGroupClosed>>")


class MemoryMaps(ttk.Notebook):
    def __init__(self, parent):
        self.ranges = {"components": []}
        self.parent = parent
        super(MemoryMaps, self).__init__(self.parent)
        self.initUI()

    def initUI(self):
        pass

    def register_update(self):
        for g in self.winfo_children():
            g.register_update()

    def size(self, comp):
        max_size = 0
        for c in comp:
            size = 0
            if "memory" in c:
                size = c["memory"][1]  # take the end
            if size > max_size:
                max_size = size
            if "components" in c:
                size = self.size_get(c["components"])
            if size > max_size:
                max_size = size
        return max_size

    def rm_descriptor(self):
        for w in self.winfo_children():
            w.destroy()
        self.ranges = {"components": []}

    def add_descriptor(self, desc):
        self.rm_descriptor()
        for c in desc["components"]:
            self.add(c, allow_overlap=True)

    def rm(self, group):
        print("Remove component %s" % (group))
        print(self.ranges)
        self.ranges["components"].remove(group)
        # RegisterGroup instance is remove by __close_group() event
        # Maybe I should put it here

        if not len(self.ranges["components"]):
            print("Enable BAR modifications")
            gual.bar.enable(True)

    def add(self, group, allow_overlap=False):
        """
        It adds new components to the current Memory map
        """
        if not allow_overlap:
            for c in self.ranges["components"]:
                if c["memory"][0] <= group["memory"][0] and \
                   c["memory"][1] >= group["memory"][1]:
                    raise Exception("Memory range [0x%x, 0x%x] already mapped" %
                                    tuple(group["memory"]))

        self.ranges["components"].append(group)
        print("Add new component %s" % (group))
        print(self.ranges)
        try:
            print("Open UAL")
            gual.bar.desc.iomap(self.size(self.ranges["components"]))
        except Exception as e:
            self.ranges["components"].remove(group)
            print(e)
            return

        reg = RegisterGroup(self, 0, group)
        reg.bind("<<RegisterGroupClosed>>", self.__close_group)
        if tab_view:
            super(MemoryMaps, self).add(reg, text=group["name"])
        else:
            reg.pack(side=tk.TOP)

        if len(self.ranges["components"]):
            print("Disable BAR modifications")
            gual.bar.enable(False)

    def reload(self):
        desc = self.ranges
        self.rm_descriptor()
        self.add_descriptor(desc)

    def __close_group(self, event):
        if tab_view:
            self.forget("current")
        event.widget.destroy()
        self.rm(event.widget.group)


class OptionPoll(tk.LabelFrame):
    def __init__(self, parent):
        self.parent = parent
        super(OptionPoll, self).__init__(self.parent, text="Polling")
        self.is_polling = False
        self.initUI()

    def initUI(self):
        self.ms = tk.IntVar()
        self.spn_ms = tk.Spinbox(self, from_=1, to=10000,
                                 width=6, textvariable=self.ms)
        self.ms.set(500)
        self.spn_ms.pack(side=tk.LEFT)

        self.lbl_ms = tk.Label(self, text="ms")
        self.lbl_ms.pack(side=tk.LEFT)

        self.btn_enable = tk.Button(self, text="Start", bg="#a7d1b0",
                                    activebackground="#a7d1b0",
                                    command=self.enable)
        self.btn_enable.pack(side=tk.LEFT, fill=tk.X, expand=True)

    def enable(self):
        if self.is_polling:
            self.is_polling = False
            self.after_cancel(self.__jobid)
            self.btn_enable.configure(text="Start", bg="#a7d1b0",
                                      activebackground="#a7d1b0")
        else:
            self.is_polling = True
            self.btn_enable.configure(text="Stop", bg="#d1aca7",
                                      activebackground="#d1aca7")
            try:
                ms = self.ms.get()
            except Exception as e:
                print("%s. Use default polling time 500ms")
                ms = 500
            self.__jobid = self.after(ms, self.poll)

    def poll(self):
        poll_list_lock.acquire()
        for reg in poll_list:
            reg.get_value()
        poll_list_lock.release()
        if self.is_polling:
            try:
                ms = self.ms.get()
            except Exception as e:
                print("Invalid pollig time. Use default polling time 500ms")
                ms = 500
            self.__jobid = self.after(ms, self.poll)


class OptionRange(tk.LabelFrame):
    def __init__(self, parent):
        self.parent = parent
        super(OptionRange, self).__init__(self.parent, text="Range",
                                          padx=5, pady=5, borderwidth=0)
        self.initUI()

    def initUI(self):
        self.lbl_mem_s = tk.Label(self, text="Start")
        self.lbl_mem_s.pack(side=tk.LEFT)
        self.ent_mem_s = tk.Entry(self, width=10)
        self.ent_mem_s.insert(0, "0x%X" % 0)
        self.ent_mem_s.pack(side=tk.LEFT)
        self.lbl_mem_l = tk.Label(self, text="Count")
        self.lbl_mem_l.pack(side=tk.LEFT)
        self.length = tk.IntVar()
        self.spn_mem_l = tk.Spinbox(self, from_=1, to=1000,
                                    textvariable=self.length, width=5)
        self.spn_mem_l.pack(side=tk.LEFT)
        self.btn_load = tk.Button(self, text="Add",
                                  command=self.mem_add)
        self.btn_load.pack(side=tk.LEFT, fill=tk.X, expand=True)

    def mem_add(self):
        start = int(self.ent_mem_s.get(), 16)
        step = int(gual.bar.desc.dw.get())
        mem = [start, start + (self.length.get() * step)]
        comp = {"name": "Address (0x%x, 0x%x)" % tuple(mem),
                "memory": mem,
                "registers": []}
        for i in range(0, self.length.get()):
            comp["registers"].append({"name": "", "offset": i * step})

        try:
            gual.mmap.add(comp)
        except Exception as e:
            print(e)


class OptionFile(tk.LabelFrame):
    def __init__(self, parent):
        self.parent = parent
        super(OptionFile, self).__init__(self.parent, text="File",
                                         padx=5, pady=5, borderwidth=0)
        self.initUI()

    def initUI(self):
        self.ent_path = tk.Entry(self, width=15)
        self.ent_path.insert(0, default_filename or os.getcwd())
        self.ent_path.xview(tk.END)
        self.ent_path.pack(side=tk.TOP, fill=tk.X, expand=True)

        self.frm_cnt = tk.Frame(self)
        self.frm_cnt.pack(side=tk.TOP, fill=tk.X, expand=True)
        self.btn_sel = tk.Button(self.frm_cnt, text="Select",
                                 command=self.file_select)
        self.btn_sel.pack(side=tk.LEFT, fill=tk.X, expand=True)
        self.btn_load = tk.Button(self.frm_cnt, text="Load",
                                  command=self.file_load)
        self.btn_load.pack(side=tk.LEFT, fill=tk.X, expand=True)

        if not with_cheby:
            self.btn_sel.config(state=tk.DISABLED)
            self.btn_load.config(state=tk.DISABLED)

    def file_select(self):
        self.file_opt = options = {}
        options['defaultextension'] = '.yml'
        options['filetypes'] = [('all files', '.*'), ('yml files', '.yml')]
        options['parent'] = self
        options['title'] = 'Select the register map file'
        filename = tk.filedialog.askopenfilename(**self.file_opt)
        self.ent_path.delete(0, tk.END)
        self.ent_path.insert(0, filename)
        self.ent_path.xview(tk.END)

    def cheby_extract_regs(self, t):
        res = []
        if isinstance(t, cheby.tree.Reg):
            res.append({'name': t.name, 'offset': t.c_address})
        elif isinstance(t, cheby.tree.Array):
            pass
        elif isinstance(t, cheby.tree.CompositeNode):
            for e in t.elements:
                res.extend(self.cheby_extract_regs(e))
        return res

    def file_load(self):
        filename = self.ent_path.get()
        t = cheby.parser.parse_yaml(filename)
        cheby.layout.layout_cheby(t)
        cheby.expand_hdl.expand_hdl(t)
        regs = self.cheby_extract_regs(t)
        desc = {'components': [{'memory': [0, t.c_size],
                                'name': t.name,
                                'registers': regs}]}
        gual.mmap.add_descriptor(desc)


class OptionMemoryMap(tk.LabelFrame):
    def __init__(self, parent):
        self.parent = parent
        super(OptionMemoryMap, self).__init__(self.parent,
                                              text="Memory")
        self.initUI()

    def initUI(self):
        self.use_tab = tk.IntVar()
        self.chk_tab = tk.Checkbutton(self, text="Use tab view",
                                      variable=self.use_tab,
                                      command=self.__tab_view_toggle)
        self.chk_tab.pack(side=tk.TOP, fill=tk.X, expand=True)
        self.file = OptionFile(self)
        self.file.pack(side=tk.TOP, fill=tk.X, expand=True)
        self.range = OptionRange(self)
        self.range.pack(side=tk.TOP, fill=tk.X, expand=True)

    def __tab_view_toggle(self):
        global tab_view
        tab_view = not tab_view


class Options(tk.Frame):
    def __init__(self, parent):
        self.parent = parent
        super(Options, self).__init__(self.parent)
        self.initUI()

    def initUI(self):
        self.mem = OptionMemoryMap(self)
        self.mem.pack(side=tk.TOP, fill=tk.X, expand=True)
        self.poll = OptionPoll(self)
        self.poll.pack(side=tk.TOP, fill=tk.X, expand=True)

        self.btn_load = tk.Button(self, text="Update all",
                                  command=self.update_all, padx=5, pady=5,
                                  bg="#a7d1b0", activebackground="#a7d1b0")
        self.btn_load.pack(side=tk.TOP, fill=tk.X, expand=True)

    def update_all(self):
        gual.mmap.register_update()


class Desc(object):
    def __init__(self, parent):
        self.parent = parent

    def initUI(self):
        print("Generate Generic")
        self.lbl_dw = tk.Label(self.parent, text="wordsize")
        self.lbl_dw.grid(row=2, column=0, sticky="NSWE")
        self.dw = ttk.Combobox(self.parent, width=8,
                               values=["2", "4"],
                               state="readonly")
        self.dw.set("4")
        self.dw.grid(row=2, column=1)

        self.lbl_off = tk.Label(self.parent, text="Offset")
        self.lbl_off.grid(row=2, column=2, sticky="NSWE")
        self.offset = tk.Entry(self.parent, width=10)
        self.offset.insert(0, "0x0")
        self.offset.grid(row=2, column=3)

        self.lbl_end = tk.Label(self.parent, text="Endianess")
        self.lbl_end.grid(row=4, column=0, sticky="NSWE")
        self.lbl_dend = tk.Label(self.parent, text="Device")
        self.lbl_dend.grid(row=5, column=0, sticky="NSWE")
        self.cmb_dend = ttk.Combobox(self.parent, width=8,
                                     values=["LE", "BE"],
                                     state="readonly")
        self.cmb_dend.set("LE")
        self.cmb_dend.grid(row=5, column=1)
        self.cmb_dend.bind("<<ComboboxSelected>>", self.change_endianess)

        self.lbl_hend = tk.Label(self.parent, text="Host")
        self.lbl_hend.grid(row=5, column=2, sticky="NSWE")
        self.cmb_hend = ttk.Combobox(self.parent, width=8,
                                     values=["LE", "BE"],
                                     state="readonly")
        self.cmb_hend.set("LE")
        self.cmb_hend.grid(row=5, column=3)
        self.cmb_hend.bind("<<ComboboxSelected>>", self.change_endianess)

    def iomap(self, size):
        pass

    def change_endianess(self, event):
        gual.mmap.reload()

    def bus_list(self):
        return my_ual.get_bus_list()


class DescPCI(Desc):
    def __init__(self, parent):
        super(DescPCI, self).__init__(parent)
        self.initUI()

    def initUI(self):
        print("Generate PCI GUI")
        pci_list = my_ual.get_pci_list()

        self.lbl_devid = tk.Label(self.parent, text="Device ID")
        self.lbl_devid.grid(row=1, column=0, sticky="NSWE")
        self.cmb_devid = ttk.Combobox(self.parent, values=pci_list,
                                      state="readonly",
                                      width=8)
        self.cmb_devid.grid(row=1, column=1, sticky="NSWE")

        self.lbl_bar = tk.Label(self.parent, text="BAR")
        self.lbl_bar.grid(row=1, column=2, sticky="NSWE")
        self.bar = tk.IntVar()
        self.spn_bar = tk.Spinbox(self.parent, from_=0, to=5,
                                  state="readonly",
                                  wrap=True,
                                  textvariable=self.bar, width=8)
        self.spn_bar.grid(row=1, column=3, sticky="NSWE")
        super(DescPCI, self).initUI()
        self.cmb_dend.set("LE")

    def iomap(self, size):
        try:
            offset = int(self.offset.get(), 10)
        except ValueError:
            offset = int(self.offset.get(), 16)
        dw = int(self.dw.get())

        flags = 0  # Clear endianess
        if self.cmb_hend.get().upper() == "BE":
            flags |= (1 << 1)
        if self.cmb_dend.get().upper() == "BE":
            flags |= (1 << 0)

        tmp = re.split(":|\.", self.cmb_devid.get())
        if len(tmp) != 3:
            raise Exception("Invalid PCI Device ID '%s'." %
                            self.devid.get())
        devid = (int(tmp[0], 16) & 0xFF) << 16 | \
                (int(tmp[1], 16) & 0xFF) << 8 | \
                (int(tmp[2], 16) & 0xFF)

        my_ual.iomap_pci(devid, dw, self.bar.get(), size, offset, flags)


class DescVME(Desc):
    def __init__(self, parent):
        super(DescVME, self).__init__(parent)
        self.initUI()

    def initUI(self):
        vme_am = ["0x00", "0x01", "0x03", "0x04", "0x05", "0x08", "0x09",
                  "0x0A", "0x0B", "0x0C", "0x0D", "0x0E", "0x0F", "0x10",
                  "0x11", "0x12", "0x13", "0x14", "0x15", "0x16", "0x17",
                  "0x18", "0x19", "0x1A", "0x1B", "0x1C", "0x1D", "0x1E",
                  "0x1F", "0x20", "0x21", "0x29", "0x2C", "0x2D", "0x2F",
                  "0x32", "0x34", "0x35", "0x37", "0x38", "0x39", "0x3A",
                  "0x3B", "0x3C", "0x3D", "0x3E", "0x3F"]
        self.lbl_am = tk.Label(self.parent, text="AM")
        self.lbl_am.grid(row=1, column=0, sticky="NSWE")
        self.cmd_am = ttk.Combobox(self.parent, values=vme_am,
                                   state="readonly",
                                   width=8)
        self.cmd_am.set("0x39")
        self.cmd_am.grid(row=1, column=1)
        super(DescVME, self).initUI()
        self.cmb_dend.set("BE")

    def iomap(self, size):
        try:
            offset = int(self.offset.get(), 10)
        except ValueError:
            offset = int(self.offset.get(), 16)
        dw = int(self.dw.get())

        flags = 0  # Clear endianess
        if self.cmb_hend.get().upper() == "BE":
            flags |= (1 << 1)
        if self.cmb_dend.get().upper() == "BE":
            flags |= (1 << 0)

        am = int(self.cmd_am.get(), 16)
        my_ual.iomap_vme(dw, am, size, offset, flags)


class BaseAddressRegister(tk.LabelFrame):
    def __init__(self, parent):
        self.parent = parent
        self.prev = None
        super(BaseAddressRegister, self).__init__(parent,
                                                  text="Base Address Register")
        self.initUI()

    def initUI(self):
        self.name_bus = tk.Label(self, text="Bus")
        self.name_bus.grid(row=0, column=0, sticky="NSWE")
        try:
            self.cmb_bus = ttk.Combobox(self, width=8, values=self.bus_list(),
                                    state="readonly")
        except tkinter.TclError as e:
            print("TclError raised at ttk.Combobox instantiation, ignoring")
        self.cmb_bus.grid(row=0, column=1, sticky="NSWE")
        self.cmb_bus.bind("<<ComboboxSelected>>", self.change_bus)

        self.cmb_bus.set("pci")
        self.desc = DescPCI(self)

    def change_bus(self, event):
        if self.cmb_bus.get() == self.prev:
            return

        for w in self.grid_slaves():
            if int(w.grid_info()["row"]) >= 1:
                w.grid_forget()

        if self.cmb_bus.get() == "pci":
            self.desc = DescPCI(self)
        elif self.cmb_bus.get() == "vme":
            self.desc = DescVME(self)

        self.prev = self.cmb_bus.get()
        self.event_generate("<<BusChanged>>")

    def bus_list(self):
        return my_ual.get_bus_list()

    def enable(self, value):
        st = "readonly" if value else tk.DISABLED
        self.cmb_bus.configure(state=st)
        if hasattr(self.desc, "cmb_devid"):
            self.desc.cmb_devid.configure(state=st)
        if hasattr(self.desc, "spn_bar"):
            self.desc.spn_bar.configure(state=st)
        if hasattr(self.desc, "cmb_am"):
            self.desc.cmb_am.configure(state=st)
        self.desc.offset.configure(state="normal" if value else tk.DISABLED)
        self.desc.dw.configure(state=st)
        self.desc.cmb_dend.configure(state=st)
        self.desc.cmb_hend.configure(state=st)


class GuiUal(tk.Frame):
    def __init__(self, parent):
        self.parent = parent
        super(GuiUal, self).__init__(parent)
        self.initUI()

    def initUI(self):
        self.frm_cnt = tk.Frame(self)
        self.frm_cnt.pack(side=tk.LEFT, fill=tk.X, anchor="n")

        self.bar = BaseAddressRegister(self.frm_cnt)
        self.bar.pack(side=tk.TOP, fill=tk.X, anchor="n")
        self.bar.bind("<<BusChanged>>", self.bus_changed)

        self.options = Options(self.frm_cnt)
        self.options.pack(side=tk.TOP, fill=tk.X, anchor="n")

        self.mmap = MemoryMaps(self)
        self.mmap.pack(side=tk.LEFT, fill=tk.X, anchor="n")

    def bus_changed(self, event):
        my_ual.unmap()

        # Destory all MemoryMaps contents
        for w in self.mmap.winfo_children():
            w.destroy()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='GUI for io access')
    parser.add_argument('-r', '--remote', help='url of the remote server')
    parser.add_argument('-f', '--filename', help='specify default filename')

    args = parser.parse_args()
    root = tk.Tk()
    try:
        default_font = tk.font.nametofont("TkDefaultFont")
        default_font.configure(family="monospace")
    except tkinter.TclError:
        print('failed to set up default fonts, continuing')

    default_filename = args.filename

    if args.remote is None:
        my_ual = PyUALUtils.remote.UALLocal()
    else:
        my_ual = PyUALUtils.remote.UALRemote(args.remote)

    gual = GuiUal(root)
    gual.pack(fill=tk.BOTH, expand=True)
    root.mainloop()
