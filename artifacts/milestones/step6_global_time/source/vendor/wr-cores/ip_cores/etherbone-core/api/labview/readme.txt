Readme for lvEtherbone, d.beck@gsi.de, 20-June-2011
===================================================
Version 0.03
- based on Etherbone api svn revision 178
- patch to Etherbone api: commented two calls to "RS_code(divsize, fragments);" in fec.cpp, 
  since FEC is presently not fully implemented.


Why lvEtherbone?
================
Etherbone was triggered by the development of a LabVIEW interface for
Etherbone (see ohwr.org). It is based on the Etherbone API (which has 
been developed by Wesley Terpstra). A wrapper around that API is
necessary for a LabVIEW interface to Etherbone.

Source Files
============
- lvEtherbone.c/h (wrapper for LabVIEW stuff) in THIS folder
- MS-Windows: solution and project files for MS-Visual Studio (Express) in sub-folder "visual"
- Linux: just use "gmake all" and the Makefile in THIS folder
- binaries (dll/so) in sub-folder bin together with compiled MS-Windows binaries for eb_snoop/write/read
- doc: some documentation
- LabVIEW interface in sub-folder LabVIEW/LVXXXX, where XXXX is the LabVIEW version number.


Getting Started
===============
- Etherbone(Windows): use the pre-compiled binaries in sub-folder "bin". Please note, that pre-compiled
  binaries of the original test programs eb_snoop/write/read are available as well.
- Etherbone(Linux): need to compile via "gmake all" in folder "../src".
- Etherbone(LabVIEW): open the LabVIEw project in folder "LAbVIEW/LVXXXX" and have a look at the examples.


License Agreement
=================
The  license agreement  for this  software  is contained  in the  file
license.txt that can be found in each package. Most of the software is
GPL licensed.

Bugs and Features 
=================
Please submit reports about  bugs, (un)funny features comments to d.beck@gsi.de





