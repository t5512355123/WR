# JTAG

JTAG programming uses the two DE5 cables:

- Master: `DE5 [1-11.1]`
- Slave: `DE5 [1-11.2]`

JTAG Wishbone mailbox scripts belong to diagnostic builds and must identify the compatible bitstream before use. The RS422 baseline does not contain the mailbox instance.
