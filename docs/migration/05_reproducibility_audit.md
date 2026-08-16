# Reproducibility Audit

## Source-of-truth

- Laptop repository: `C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_WR`
- pain bare repository: `/home/b10504072/de5a-white-rabbit.git`
- pain working clone: `/home/b10504072/de5a-white-rabbit-repo`
- Initial migration-audit commit: `2fb75aafe0e2c03c6a20bab8d5a14ccddb7d4f6a`
- Local and pain working trees: clean at the final audit

## Build evidence

The formal pain clone produced both firmware images and both Quartus SOFs.
Quartus Prime 17.0 Build 595 reported `Full Compilation was successful` and
0 errors for Master and Slave. The full logs and reports are in
`artifacts/EXP-REPRO-BUILD-20260815/`.

The generated image hashes from the recorded build were:

| Image | SHA256 |
|---|---|
| Master MIF | `a664396b3d908d43d0810fa85f76dd2437dde10b1f8c3ed97514ecb304f8e29c` |
| Slave MIF | `fca9e4aebfdf49674de2af31824f2d19bb422d305fcc2a0808495f515ccb7ade` |
| Master SOF | `ea66406592d0734e7547d60ab88d6416c86bc4ef4fdfa4e4e90a330c19de1214` |
| Slave SOF | `19fac5b4fe9d2c867f052683adb31b2d266900a52fe185b78330b15318ba8b21` |

The later build-identity and timing-wrapper validation is recorded in
`artifacts/EXP-REPRO-BUILD-TIMING-20260815/` at commit
`0a8f44afa5b26111a1103903968bf173e210ee92`. Its `build_info_master.txt` and
`build_info_slave.txt` include Quartus version, SOF hash, Fitter status,
timing slack and unconstrained-path counts.

This document is part of the later repository history; the final repository
commit is recorded by `STATUS.md` and the Git log. The artifact build commit
above remains the exact source identity that produced the recorded SOFs.

## Timing interpretation

Compile success is not timing closure. The recorded TimeQuest reports show:

| Revision | Worst setup | Worst hold | Worst recovery | Worst removal | Unconstrained clocks | Input paths | Output paths | Timing closed |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| Master | -3.812 ns | 0.039 ns | -1.975 ns | 0.298 ns | 3 | 1992 | 83 | NO |
| Slave | -3.103 ns | 0.030 ns | -1.839 ns | 0.326 ns | 3 | 2001 | 83 | NO |

These are observations of the preserved design and are not a reason to alter
the WR function in this migration task. Timing closure remains a separate
technical investigation.

## Clean checkout

From a new clone of the pain bare repository at the latest commit, Master and
Slave firmware and Quartus compilation both completed. A second clean checkout
at the exact artifact build commit also rebuilt both firmware images. The WRPC
source embeds `__DATE__` and `__TIME__`, so separate invocations are expected
to have different image hashes even when the functional source is unchanged.

## Functional baseline comparison

The path changes are limited to the new repository layout and fixed MIF
locations. The preserved probe mapping, QSFP-A lane 0 choice, clock periods,
Master/Slave roles and pre-emphasis assignments were not changed.
