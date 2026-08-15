# Error Interpretation

- `link_up=1` and `link_ok=1`: the available PHY/PCS link indicators are asserted.
- `time_valid=0` or `pps_valid=0`: no valid WR time/PPS claim may be made.
- `rx_enc_err=1`: investigate the receive serial/PCS direction, lane mapping, polarity, alignment and optics before changing WR software.
- `No In-System Sources and Probes instance was found`: the JTAG script does not match the currently programmed bitstream; it is not by itself a WR link failure.
