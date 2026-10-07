Introduction
============

This is a simple example testbench, to demonstrate how to use the SystemVerilog BFM of the GN4124 to
perform simple accesses over wishbone.

The testbench simply connects the wishbone master of the GN4124 to its own DMA configuration
wishbone slave and attaches a pre-initialised dummy RAM with a wishbone interface to the pipelined
DMA interface in order to perform a DMA read.

Dependencies
============

To build this, you will need [hdl-make][1], using commit `968fa87` (or newer), as well as GNU Make.

The testbench also makes use of [general-cores][2], a dependency handled via git submodules.

To run it, you will need Modelsim/Questa. It has been tested with Questa 10.5c on Linux.

Build/Run Instrunctions
=======================

1. If not already done, pull all dependencies using `git submodule update --init` from within the
   gn4124 repository.
2. Run `hdlmake` from the example_tb directory.
3. Run `make` on the hdlmake-generated Makefile.
4. Run `vsim -c -do run.do`.

[1]: https://www.ohwr.org/projects/hdl-make/wiki
[2]: https://www.ohwr.org/projects/general-cores/wiki
