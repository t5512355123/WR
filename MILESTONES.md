# White Rabbit milestone index

## Latest live-root verification — 2026-10-05

**Step6 sampled TIME_VALID 300 s = PASS on both boards**, in the already-running
Pain main-root session: Master 1190/1190 valid rows over 302874 ms (max gap 257 ms),
Slave 359/359 over 302667 ms (max gap 909 ms), zero invalid samples/capture errors.
Retained root products were compiled from `bcb84305`, collected at `9b8a231c`.
Control remains `/2 + /12`, 60/120 ps; operating scripts remain editable without
SHA acceptance checks. No build/program/reset or canonical package modification
was performed during this live verification.

Slave CKO, 243 trusted unique updates: −490..+459 ps, 949 ps peak-to-peak,
median −44 ps, stddev 171.3 ps. All five sampled PLL locks remained 1; sampled reset
identity did not change. This revalidates TIME_VALID retention, NOT sustained
±60/120 ps accuracy, physical jitter/skew or deterministic cold startup.
The old failed standalone startup remains documented in the sealed package.

[Latest report / timeline chart](experiments/step6/EXP-S6-LIVE-TIME-VALID-CKO-300S-PROMOTION-20261005/REPORT.md).
The table below indexes the sealed artifacts, not the current root SOF pair.
Its Step6 source/SOF references are corrected to the package's existing records;
the read-only package itself is unchanged.

Only a frozen source that has been clean-built, programmed, and runtime-
validated on both DE5a boards is marked `PASS` here. Historical reports and
SOF hashes are provenance; they do not replace reproduction evidence. Under
the user-revised Step 6 acceptance (2026-10-01), both boards must independently
maintain exported `STATUS_TIME_VALID=1` across sampled windows of at least 300
seconds. Snapshot/PPS flags, counter payload/progression, phase offset, Step
1/link, Step 5 locks, and timing closure are not gates.

| Step | Goal | Status | Canonical milestone path | Source commit | Master SOF SHA-256 | Slave SOF SHA-256 | Experiment evidence | Known limitations |
|---:|---|---|---|---|---|---|---|---|
| 1 | PHY / link | **PASS** | [`artifacts/milestones/step1_phy_link/`](artifacts/milestones/step1_phy_link/) | `b8d4c3d0526f0c2ca282600ef06648dd9f0af595` | `f2e2136e8159ba9135313536f1a641c0865dbf36f267e06ef7826e0363f8c07e` | `15997ca2dd2ea2597d7f25af5522afc0144219769450824c0a7e31526cd44112` | [`experiments/step1/EXP-S1-MILESTONE-REPRO-20260924/`](experiments/step1/EXP-S1-MILESTONE-REPRO-20260924/) | Does not claim endpoint/PTP or later-step behavior. |
| 2 | Endpoint / MiniNIC / PTP | **PASS** | [`artifacts/milestones/step2_endpoint_ptp/`](artifacts/milestones/step2_endpoint_ptp/) | `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00` | `891ba2ca901cf307edc92223f1115387895b64f20441d8c4adeb3994179548ee` | `fd4339f4d324d9b63cf60c3fb7e627abe6d6a3ff4f7f2e1df558f764ad5a270c` | [`experiments/step2/EXP-S2-MILESTONE-REPRO-20260924/`](experiments/step2/EXP-S2-MILESTONE-REPRO-20260924/) | Master time series had 20/30 accepted consistent rows; timing closure is not claimed or required. |
| 3 | WR parent / signaling handshake | **PASS** | [`artifacts/milestones/step3_wr_handshake/`](artifacts/milestones/step3_wr_handshake/) | Frozen package commit `f235b557ad09d9b37adff2c2b11b36f615f66e9e`; source origin `054d06874dfc4d6be8acd1f60b8cba1e7a4c5b00` | `0cae1a4d4c800c3a67e5dcac7ca4abf739475867119ac333d0d71ef39380acf2` | `f196de1f5d431a493c2a8ce0aaeeb34d202f4d04f30c340977a4b771049896de` | [`experiments/step3/EXP-S3-MILESTONE-REPRO-20260924/`](experiments/step3/EXP-S3-MILESTONE-REPRO-20260924/) | Proves WR parent/signaling and the SoftPLL lock-entry hook only; it does not claim SoftPLL lock, global time, or timing closure. No source-backed reset-generation counter is exposed; report states the sampled reset observability limit. |
| 4 | SoftPLL startup | **PASS** | [`artifacts/milestones/step4_softpll_startup/`](artifacts/milestones/step4_softpll_startup/) | Frozen package `393f402c6af420b45e9ffa1f0b936cdfd017982c`; historical origin `a1980bff30231376a3182486fd786d906876c2d4` | `55cb04191f3e0793623a55ada6c9e842b6d92d26ba196f1b057c5d5595d57717` | `b6b87623d8c7cb4660a04e97bd7a0ce5792783fdd3e6d04a64880307bb26612e` | [`experiments/step4/EXP-S4-MILESTONE-REPRO-20260924/`](experiments/step4/EXP-S4-MILESTONE-REPRO-20260924/) | Step 4A/4B startup and event chain reproduced. Step 5 first inactive boundary was MAIN_PHASE_LOCK; timing closure is NO and not claimed. |
| 5 | SoftPLL full lock | **PASS** | [artifacts/milestones/step5_softpll_lock/](artifacts/milestones/step5_softpll_lock/) | Frozen source 26e138fdc0bfc8426704b397141d563cf4d580a2; observer 47d9a394e53eda31476c82de2a85ad82573494ed; reproduced from checkout 6f1096d7f957beeb2f0c065f7219960bae47bb61 | f72501285cef7f6a892b9334e7de93a5a86f8aff7311417f577c14acfd213a30 | d4efd77c91ddc96cd6444e3f47cadf529a4f19da4c9f6b0876ce00557d63ca20 | [experiments/step5/EXP-S5-MILESTONE-REPRO-20260924/](experiments/step5/EXP-S5-MILESTONE-REPRO-20260924/) | Four required locks persisted for 301253 ms; 300291 ms fresh-data span. Timing closure is NO; eight histogram accounting warnings and sideband/schedule observability limits are documented. |
| 6 | Sampled TIME_VALID for 300 seconds on both boards | **PASS — sealed root qualification; live-root revalidated 2026-10-05** | [Read-only Step6 package](artifacts/milestones/step6_global_time/README.md) | Sealed origin `00b2342b22c8de000b08be4f4fc9ac1eb44f215e`; Master step64/bootstrap2048; Slave `/2 + /12` | `33e58bf47e7e944a30d90cb791eba0416213ad9838b073642e44b1057ea42134` | `fa5e4d2ce52e3cbbdf65ceaa14a34b0360d0e2af47bfb3fdd4385893b3e99c6f` | [Sealed qualification](experiments/step6/EXP-S6-MAIN-ROOT-TIME-VALID-300S-BACKTRACK-20261003/REPORT.md); [latest live-root check](experiments/step6/EXP-S6-LIVE-TIME-VALID-CKO-300S-PROMOTION-20261005/REPORT.md) | Sealed root: Master1191/1191 over302747ms, Slave1190/1190 over302799ms. Fresh standalone acquisition NOT_ESTABLISHED. Latest live-root windows separately pass300s; not precision, physical skew, timing closure or universal startup proof. |

Historical pointwise phase-offset and earlier captures remain in experiment
records and Git history. There is only one operational Step6 milestone: its
`source.tar.gz` contains the qualified code, all scripts/dashboard, firmware/FPGA
products and the two-cycle evidence. Run `prepare_source.sh` to create its
independent `source/` checkout. Old Step6 packages were moved outside the repo
for recovery, not retained as competing versions here. Keep physical skew separate.
