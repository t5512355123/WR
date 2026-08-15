# Universal Access Library {#mainpage}
![UAL logo](doc/ual.png)

The Universal Access Library (also known as UAL) it's a user-space library which
aim is to make transparent the access to the physical buses. The typical use
case is the development of tools that access an FPGA over VME bus or the PCI bus.

This library has been designed for debugging/testing purpose so the API is minimal
and **not** performance oriented. Any operational use of this library will not be supported.

Please, note that any example in this document is based on the
[FMC-ADC-100M14B4CH](https://gitlab.com/ohwr/project/fmc-adc-100m14b4cha/wikis)
FPGA application.

## Compile
You can compile the minimal UAL (PCI support only) by running the following
command:

    make

To add support to other buses, the VME bus for example, you can do:

    make VMEBRIDGE=/path/to/vmebridge CONFIG_VME=y

Look at the [supported buses](#supported-buses) section for the configuration
options of other buses.

Each `Makefile` includes, if it exists, a file named `Makefile.specific`.
The idea of the `Makefile.specific` is to include any specific configuration
for your environment. This is usefull when you want to compile the UAL using a
different environment than the default one.

You can execute the `make` command (as explained above) in any of the following
directories:
- `lib`: to compile only the library
- `tools`: to compile only the tools
- root directory: to compile the library and the tools

### CERN-BECO environment
The CERN-BECO compilation environment is a bit different than the one
provided by any Linux distribution; because of this when we want to compile
within the CERN environment we have to adjust a bit our configuration.

To set up the CERN-BECO environment we have to make use
of the `Makefile.specific` file. We have to create this file in
the directories: `lib` and `tools`. BECO already provide a generic Makefile
that setup the environment `/acc/src/dsc/co/Make.common`.
You have two alternatives. The first one is to create a symbolic link
to this file:

    cd /path/to/ual
    ln -s /acc/src/dsc/co/Make.common lib/Makefile.specific
    ln -s /acc/src/dsc/co/Make.common tools/Makefile.specific

The second one is to include the `Make.common` from the `Makefile.specific`:

    cd /path/to/ual
    echo "-include /acc/src/dsc/co/Make.common" > lib/Makefile.specific
    echo "-include /acc/src/dsc/co/Make.common" > tools/Makefile.specific

The `Make.common` Makefile requires you to set the cross-compilation
environment. You can do that by using the environment variable `CPU`
(L865 -> SLC5; L866 -> SLC6; L867 -> CC7)

    make CPU=L866

For the VME support, you will find VME libraries and headers
at `/acc/local/L866/drv/vmebus/1.0.0/`. So, your compilation command will look
like the following one:

    make CPU=L866 VMEBRIDGE=/acc/local/L866/drv/vmebus/1.0.0/ CONFIG_VME=y


## API
The API documentation is not part of this README. The API documentation can be
generated using doxygen. Run the following command in the doc directory:

    make doxygen

The directory `doxy-libual` will be created with the C API documentation in HTML
format and LaTeX format. While, in the directory `doxy-libual-python` you will
get the Python documentation.

The API documentation documents the full API. This means that it may documents
features available only for specific buses which have not been compiled.

If you want to contribute to the project you can get more information by
compiling the contributors doxygen documentation in which you will find
information about internal functions and structures.

    make doxygen-contrib


## Python Support
The support for the Python language is implemented by binding the C shared
library. This means that you must compile the library before being able to
use the Python class. For more details about the Python interface look at
the [API](#api) section.

The Python development is generally done using `Pyhton 3.5`, so we do not
guarantee that this will be 100% compatible with previous versions.

To install the PyUAL library into your Python environment you can run
the following command:

    cd PyUAL
    python3 setup.py install

To create a tarball:

    cd PyUAL
    python3 setup.py sdist

## Tools
This repository offers two main tools: `ualmem` and `ugui`. In both cases the
tool's aim is to give access to the device memory and make use of all the
features offered by the UAL [API](#api). The user interface is the only difference
between those two programs; `ualmem` is a command line application, `ugui` is
a Python graphical application. The functionalities are, in principal (with all
the user interface advantages and limitations), the same.

The `ualmem` tool is statically linked against the library so it is an
independent piece of software that can be executed without any dependency.
Here an example of the command line interface:

    $ ualmem --pci --pci-device 0b:00.0 --pci-bar 0 --address 0x3600
    [0x0000000000003600] R 0x000030cb
    $ ualmem --pci --pci-device 0b:00.0 --pci-bar 0 --address 0x3600 --value 0x0
    [0x0000000000003600] W 0x00000000

The `ugui` tool depends on the *PyUAL* module which depends on
the UAL shared library. If you do not want to install those dependencies on
your system, you can set up the following environment variables:

    LD_LIBRARY_PATH=/path/to/ual/library
    PYTHONPATH=/path/to/python/module

The `ugui` tool has been developed for Python 3.5, so please considere to update
your Python interpreter if necessary. In the `doc` directory you can find a little
demo in gif format.

![ugui](doc/uguidemo.gif)

## Supported Buses
For the time being the UAL support the following buses:
- PCI bus
- VME bus (`VMEBRIDGE=/path/to/vmebridge` and `CONFIG_VME=y` at compile time)

Any instance of the UAL (any .a or .so) support the PCI bus. Any other could be
not supported.


## Development
Following an example of tool that you can write using the UAL library.
The following example will:
1. map the memory over the PCI bus
2. read the current base time
3. reset the base time to zero
4. read the current base time

Here the example written in C language:

    /* the header's directory depends on your '-I' option in the compiler */
    #include <lib/ual.h>

    struct ual_bar_tkn *tkn;
    struct ual_desc_pci pci = {
        .devid = 0x0B0000; /* (bus << 16) | (dev << 8) | (func)*/
        .data_width = UAL_DATA_WIDTH_32; /* 32bit access, 4 byte access */
        .bar = 0; /* maps PCI device BAR 0 */
        .size = 4096 * 10; /* maps 10 pages */
        .offset = 0x0; /* maps from the BAR beginning */
        .flags = 0;
    };
    uint32_t val;

    tkn = ual_open(UAL_BUS_PCI, &pci);
    val = ual_readl(tkn, 0x3600);
    ual_writel(tkn, 0x3600, 0x0);
    val = ual_readl(tkn, 0x3600);

    ual_close(tkn);

Here the example written in Pyhton language:

    import PyUAL

    desc = PyUAL.PyUALPCI(0x0B0000,4,0,4096 * 10,0, 0)
    ual = PyUAL.PyUAL("pci", desc)
    ual.readl(0x3600)
    ual.writel(0x3600, 0)
    ual.readl(0x3600)