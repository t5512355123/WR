# Vendored dependency provenance

This file records the dependency state found on `pain` during migration. The
working trees were copied into this repository without their nested `.git`
directories so that the top-level repository owns the experiment snapshot.

## `vendor/wr-cores`

- Original path: `/home/b10504072/04_White_Rabbit/week02/v01/vendor/wr-cores`
- Remote: `https://gitlab.com/ohwr/project/wr-cores.git`
- HEAD: `0f8fbced87988254f5c9ca55c0e04585b29b485c`
- State at inventory: detached HEAD, modified `ep_tx_framer.vhd` and
  `wrc_urv_wrapper.vhd`

## `vendor/wrpc-sw`

- Original path: `/home/b10504072/04_White_Rabbit/week02/v01/vendor/wrpc-sw`
- Remote: `https://gitlab.com/ohwr/project/wrpc-sw.git`
- HEAD: `4528c0faa64138a6c97f15e6b911090f7df373ff`
- State at inventory: detached HEAD, modified Makefile and `dev/pps_gen.c`,
  plus the existing `ppsi` submodule state and local build/configuration files

## `vendor/wrpc-sw_nosfpmatch_diag`

- Original path: `/home/b10504072/04_White_Rabbit/week02/v01/vendor/wrpc-sw_nosfpmatch_diag`
- HEAD: `4528c0faa64138a6c97f15e6b911090f7df373ff`
- Preserved as a legacy diagnostic snapshot; it is not the canonical build input.

The modified vendor contents are intentionally preserved. They are not cleaned
or reset during migration because they may be part of the historical bitstream
provenance.
