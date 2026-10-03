# Current-root Step6 archive and independent fresh reproduction

Root qualification remains PASS: Master1191/1191 over302747ms and
Slave1190/1190 over302799ms, zero invalid rows. That evidence is separate
from the new independent reproduction below; it does not certify this boot.

STANDALONE_TIME_VALID_300S = NOT_ESTABLISHED

## Package and independent build

Laptop published the qualified products/report and packaging support;
Pain pulled2141bdfb. Packaging verified production manifest SHA256
`418bb2546c08cb7b67c09309b58ce1de4c4668e39e3ec84dc94a4add850c6e6a`,
all3117 inputs, root SOFs, root programming success and unchanged300s analyzer.
The previous WHOLE package was recoverably moved outside the canonical path:
`/home/b10504072/04_WR_step6_package_backups/20261003T160324Z/step6_global_time`.
The protected04_WR_archive_step6_pass directory was never modified.

Prepared an independent source repository inside the canonical milestone.
Native22-case actual-servo C tests with UBSan and12 source/analyzer tests PASS.
Fresh build began2026-10-04T00:04:49+08:00, using independent compile identity
`8e7d796353ccdfd8f359ec9c86b83206bff4f003`. Both full compiles completed;
Slave-to-Master programming succeeded from milestone/source/output, not root.

| Board | Fresh MIF SHA256 | Actual newly programmed SOF SHA256 |
|---|---|---|
| Master | `18a51d784d08acfdc3bc6f24cff768661ea3918d234c6b19a2d360614a0da3ea` | `cd7285f7c6799ad2200c3f69e3af6f13442ac72029edf2e26881632885fc086d` |
| Slave | `91c5d7f9629a8a5d2a05116f12efd9515326ad25ee897a85ab97c71fc242c379` | `ade6b05fc99f01d5818badaa8e9d615f5aaff933e9a0650924293076891a2ce3` |

Production source bytes and MIFs match the qualified root version. Full timing
closure is not an acceptance gate. No control/gain/threshold/calibration/PHY/
reset/SDC/firmware timeout modifications or power cycle occurred.

## First acquisition attempt: TIMEOUT, not a PASS

Observer began00:22:39+08:00 with a600s host acquisition bound. It timed out;
no full303s capture was started. Keep every readiness poll and the initial
cycle log. A compile/program success is NOT TIME_VALID300s reproduction.

Post-timeout read-only dashboard at00:33:56: both link paths PASS; Master
TIME_VALID/PPS_VALID1, Slave five lock flags1 but TIME_VALID/PPS_VALID0,
WR servo WAIT_OFFSET_STABLE and pointwise CKO-2353ps. This observation is not
proof of a cause or of persistent phase behaviour across the whole interval.

## FPGA configuration comparison

Quartus17.0 CPF converted both root-qualified and freshly rebuilt SOF pairs
to RBFs. `cmp` reports BYTE-IDENTICAL configuration data per corresponding
board, despite different SOF hashes/compile path metadata.

| Payload pair | Same RBF SHA256 |
|---|---|
| Root/fresh Master | `8e5f1ab2c0c44376493f5ff1dedc50c3e6423835e7f96de42ceda96758007f09` |
| Root/fresh Slave | `886650e7345968e1739087d3e82fb054caa31950d0eb0f7657e97b148ba908dc` |

Therefore missing archived production inputs or different FPGA configuration
is not supported as the reason for this session's failure to acquire TIME_VALID.
Runtime acquisition differs; its deeper physical/servo cause is NOT established.
Do not infer that all future boots will acquire identically from the root PASS.

## One bounded, same-session passive continuation

After the preserved first timeout and RBF audit, Laptop published the amended
plan/support script9be4c4ce and Pain pulled it. A second600s host observer wait
began00:39:05, in the SAME already-programmed session, without reprogramming,
reset, power cycle or controller changes. This only extends passive observation;
it does not modify firmware timeouts or weaken the unchanged300s analyzer.
Initial timeout remains a timeout even if this continuation later passes.

The continuation ALSO TIMED OUT. There was no303s qualification capture and
no qualification PASS. Across94 readiness polls, each with four samples per
board: Master376/376 TIME_VALID1, Slave0/376 TIME_VALID1. These discontinuous
readiness windows must NOT be treated as a continuous300s capture.

Final read-only dashboard2026-10-04T00:50:32+08:00: both link paths PASS,
Master TIME_VALID/PPS_VALID1; Slave five lock flags1 but TIME_VALID/PPS_VALID0,
WAIT_OFFSET_STABLE, pointwise CKO-2460ps. No further programming/tuning follows.

The ENTIRE unqualified independent repository, including caches/new SOFs/Git
identity/runtime records, was recoverably moved outside the canonical package:
`/home/b10504072/04_WR_step6_package_backups/20261003T165122Z-unqualified-rebuild/source`.
Fresh products, compile/program records, all94 readiness polls, configuration
comparison RBFs and post-failure dashboards are also copied into this experiment.
The canonical archive/alias pair remains the previously qualified ROOT version,
not the failed fresh pair. Its prepared source/output is restored byte-for-byte
to those qualified aliases;12 source/analyzer tests passed after restoration.

Final verdict: source/package integrity established; root TIME_VALID300s
qualification preserved; NEW FRESH STANDALONE REPRODUCTION NOT ESTABLISHED.
This does not disprove the earlier root PASS, nor prove acquisition reliability
across boots. The archive is not advertised as a newly reproduced300s PASS.

This work targets sampled TIME_VALID retention only, not strict±120ps offset,
absolute UTC/TAI accuracy, simultaneous board windows, physical PPS/SMA skew
or full timing closure. Existing historical servo acquisition is not forced.
