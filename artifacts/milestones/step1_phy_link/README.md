# Step 1 milestone — PHY / Link

**Verdict: PASS**

This frozen checkpoint proves the two DE5a boards' White Rabbit PHY/link
foundation. It does not claim Step 2–Step 6 completion.

## Frozen source and provenance

- Historical source commit: `b8d4c3d0526f0c2ca282600ef06648dd9f0af595`
- Reproduction branch commit on Pain: `0d21ae848f4e767dffc487ed0b318768f63bc1d8`
- Frozen, self-contained source: [`source/`](source/)
- Source manifest: 3,118 entries; SHA-256 of `source/SHA256SUMS`:
  `971d863f6171d2f6c496b197f84dc774e2d56d7495f874db2c815f0c00f5a96b`
- Quartus Prime: 17.0.0 Build 595, Standard Edition
- Firmware toolchain: `riscv64-unknown-elf-gcc` 9.3.0; GNU ld 2.34

The historical JTAG experiment reports Master/Slave SOF hashes
`25567908d38334491b1b7e25f5bd3a8c890743d541e2a3cf72ab2031a54e33be` and
`0d4528b3cb2a26ae3c20b3cc395481441ebb81385c87c9e93ff4923aec63edc5`.
Those are provenance only; the images below were freshly rebuilt and are the
images that were programmed and runtime-validated for this milestone.

## Rebuild results

Both role images were clean-compiled from the frozen candidate on Pain. The
Slave Quartus revision was explicitly cleaned after the Master build because
Quartus shares its project database directory. Each full compilation ended
with **0 errors and 267 warnings**.

| Role | Rebuilt SOF SHA-256 | Rebuilt firmware MIF SHA-256 |
|---|---|---|
| Master | `f2e2136e8159ba9135313536f1a641c0865dbf36f267e06ef7826e0363f8c07e` | `1748846b04070b25a391fbc31fbbbb4a1fb9a91b8d71a0505c443fdd02ce1e1e` |
| Slave | `15997ca2dd2ea2597d7f25af5522afc0144219769450824c0a7e31526cd44112` | `480e5c80b08ecd0bb719a371154be6aa2521f2d09f228e2cf7430270bf20619e` |

The historical firmware MIF hashes were Master
`968e3863f2622fe67d468327bec1d8832e955344f74973cde7e2bc19fcf7347d` and Slave
`88f5dce3198e17ad75933e353c9852fdd43069ebc92b7e94734c0db9c270cfef`. The
rebuilt MIFs are not bit-identical to those historical files; the generated
MIFs and their hashes are preserved in the experiment evidence. No claim of
binary identity is made.

## Programming

Programming order followed the historical Step 1 procedure:

1. Slave on `DE5 [1-11.2]` — configuration succeeded, 0 errors/warnings.
2. Master on `DE5 [1-11.1]` — configuration succeeded, 0 errors/warnings.

Quartus identified both JTAG chains as DE5a 10AX115H devices. The freshly
rebuilt SOF files are [`slave.sof`](slave.sof) and [`master.sof`](master.sof).

## Runtime acceptance

A read-only JTAG capture sampled probe instance 0 at a requested 100 ms
interval. Each board produced 360 contiguous, readable samples over more than
36 seconds. The offline analyzer found:

| Acceptance signal | Master gate drops | Slave gate drops |
|---|---:|---:|
| PHY ready (`wr_ready`) | 0 | 0 |
| RX ready | 0 | 0 |
| TX ready | 0 | 0 |
| RX locked to data | 0 | 0 |
| TM link up | 0 | 0 |
| Core link OK | 0 | 0 |
| CPU reset released | 0 | 0 |
| Encoding/disparity error samples | 0 | 0 |
| Maximum consecutive error samples | 0 | 0 |

Capture totals: 720 sample rows, 0 malformed rows, 0 read failures. The
analyzer verdict was `STEP1_OVERALL=PASS`.

## Evidence and limitations

Full build, firmware build, programming, and raw observation records are in
[`experiments/step1/EXP-S1-MILESTONE-REPRO-20260924/`](../../../experiments/step1/EXP-S1-MILESTONE-REPRO-20260924/).
The source probe confirms `CPU_RESET_n` remained asserted high at every sample;
this legacy Step 1 probe does not expose a separate boot-generation counter.

Timing closure is not claimed or required for this Step 1 checkpoint. PTP
endpoint behavior, WR handshake, SoftPLL, lock, and global time are outside its
acceptance criteria and remain for later milestones.
