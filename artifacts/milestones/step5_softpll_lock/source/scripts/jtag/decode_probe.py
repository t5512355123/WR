#!/usr/bin/env python3
"""Decode the 16-bit DE5a WR diagnostic probe without external packages."""

import argparse


BITS = (
    "si_config_done",
    "phy_ready",
    "tm_link_up",
    "link_ok",
    "time_valid",
    "pps_valid",
    "rx_ready",
    "tx_ready",
    "MOD_PRS_n",
    "INTERRUPT_n",
    "tx_disable",
    "phy_rst",
    "si_id_error",
    "rx_enc_err",
    "tx_enc_err",
    "CPU_RESET_n",
)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("value", help="probe value such as 0x82CF")
    args = parser.parse_args()
    value = int(args.value, 0) & 0xFFFF
    print(f"probe=0x{value:04X}")
    for bit, name in enumerate(BITS):
        print(f"bit{bit:02d} {name:16s}={1 if value & (1 << bit) else 0}")


if __name__ == "__main__":
    main()
