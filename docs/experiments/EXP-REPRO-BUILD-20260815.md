# EXP-REPRO-BUILD-20260815

## Objective

Verify that the new repository can rebuild the preserved DE5a Master/Slave
baseline inputs on `pain` with Quartus Prime 17.0, without changing WR
behavioral parameters.

## Inputs

- Git commit: `ff09c9db8eb45ef5e164e311ad9cf361f7d13581`
- Build host: `pain`
- Quartus: `/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`, Prime 17.0 Build 595
- Master project: `quartus/rs422_uart_diag/DE5a_wr_master_rs422.qpf`
- Slave project: `quartus/rs422_uart_diag/DE5a_wr_slave_rs422.qpf`
- Master generated MIF SHA256: `a664396b3d908d43d0810fa85f76dd2437dde10b1f8c3ed97514ecb304f8e29c`
- Slave generated MIF SHA256: `fca9e4aebfdf49674de2af31824f2d19bb422d305fcc2a0808495f515ccb7ade`

## Changes for reproducibility only

- The build wrapper restores executable bits for vendored shell helpers after
  a Windows transfer.
- pain's `riscv64-unknown-elf-*` tools are exposed through private
  `riscv32-elf-*` aliases for this build workspace because the WRPC makefiles
  request the latter command names.
- No PHY, QSFP, PTP, SoftPLL, DMTD, clock, role, lane or pre-emphasis setting
  was changed.

## Results

- Master firmware: PASS, `wrc.mif` generated.
- Slave firmware: PASS, `wrc.mif` generated.
- Master Quartus: PASS, `Full Compilation was successful`, 0 errors, 262 warnings.
- Slave Quartus: PASS, `Full Compilation was successful`, 0 errors, 262 warnings.
- Master generated SOF SHA256: `ea66406592d0734e7547d60ab88d6416c86bc4ef4fdfa4e4e90a330c19de1214`
- Slave generated SOF SHA256: `19fac5b4fe9d2c867f052683adb31b2d266900a52fe185b78330b15318ba8b21`

The warnings include the existing TimeQuest observation about two combinational
loops being analyzed as latches. They are recorded in the compile logs and were
not introduced by a WR functional change in this migration.

## Interpretation

This experiment proves source-to-MIF-to-SOF build reproducibility on pain. It
does not claim that the newly generated bitstreams have been programmed or that
White Rabbit time synchronization is complete. The preserved hardware baseline
and the generated build are intentionally separate artifact sets.
