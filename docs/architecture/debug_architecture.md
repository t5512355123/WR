# Debug Architecture

Debug evidence is split into three layers:

1. FPGA configuration and Quartus reports.
2. Link/status probe evidence.
3. WRPC runtime evidence such as UART, PTP state, SoftPLL and PPS.

A link-up probe is not treated as proof of time synchronization. Each experiment must state which layer it actually proves.
