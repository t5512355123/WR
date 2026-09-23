# EXP-STEP4B-REBUILD-IDENTITY-AUDIT-20260924

## Verdict

- SOURCE_COMMIT_MATCHES_HISTORICAL_BUILD = YES
- MASTER_FULL_COMPILE = PASS
- SLAVE_FULL_COMPILE = PASS
- REBUILT_IMAGES_MATCH_HISTORICAL_SOF = NO
- REBUILT_IMAGES_MATCH_HISTORICAL_MIF = NO
- HARDWARE_PROGRAMMING = NOT_RUN
- STEP4B_RUNTIME_RESULT = NOT_EVALUATED
- STEP4B_MILESTONE_CHANGED = NO

This was a compile-only artifact identity audit. The rebuilt images are not
the previously validated Step4B milestone images and must not be programmed
or labelled as those images. No Step4B functional verdict is inferred from a
successful compile.

## Purpose and source

The historical repeat-fresh-program report identifies source commit
266703a89917b5d73ef74baa3658baba46c4ac7f and records exact Master and Slave
SOF/MIF hashes. Those exact SOFs were not found in the Pain artifact inventory.
To determine whether the same source could recreate the artifacts, both
Quartus projects were fully compiled on Pain from a detached worktree at that
commit using Quartus 17.0.0 Build 595.

Build times from the captured build metadata:

- Master: 2026-09-24T03:47:53+08:00
- Slave: 2026-09-24T03:53:04+08:00

The full-compilation logs report success for both projects. The build metadata
also reports timing not closed (Master worst setup slack -0.177 ns, Slave
-0.272 ns); this audit does not use timing closure as a Step4B functional
criterion.

## Artifact identity comparison

| Board | Historical validated SOF | Rebuilt SOF | Historical MIF | Rebuilt MIF |
| --- | --- | --- | --- | --- |
| Master | 94244a9e713c519a73c5f42419b24f75efb5f19e706445d76baebc9ac981fefb | 929033652d6f660afb81cbb3dd81c81ac27cc5ba103822164e5c285d380aa5a9 | fe2398e7d1be2ff762e321a0b0cd74a62a6caf501550892b36fed47e20da5954 | 9b96326d085d86a2c1a909647ae327bc8fa63a31716f22b571eed911b7a89f0d |
| Slave | 83a6ae959722194eeb2355e93215eb8d3858eaf59bcf2a64b991cf12346ec54e | 4d052860fad8af986533e86a4d66f72d659d0b0afa737e7603414fa24be63d9e | a671a1dd1bce53546421eb336203d43c0c5b31058c3b00e532c9b2bd9ab73ab1 | e22c78286bf3e374a8eb6895f97e1207fadf3d5cac939fec3a372948683e97d9 |

The source commit matches, but both rebuilt SOFs and both firmware MIFs differ
from the historical hashes. The cause of the byte-level difference is
unresolved; build-time macros or other nondeterministic build inputs are
possible explanations, not established findings.

## Build configuration

| Board | QSF SHA-256 | SDC SHA-256 | Result |
| --- | --- | --- | --- |
| Master | a913d21905b21460590d89e650f3060b84b8a59cfe3626338f3f2d1ee8db641a | 921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b | Full compilation successful |
| Slave | c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437 | 921e0918187eece1e2445e59e1220d3bba4795bb17111f29b63b16ba54d9095b | Full compilation successful |

## Hardware and retention

There was no JTAG programming, reset, power-cycle, or live-board observation
during this audit. Rebuilt SOF/MIF outputs are deliberately not copied into
the retained milestone-artifact set. The historical hashes and the complete
build logs/manifests below preserve the audit trail without misrepresenting
the rebuild as a validated milestone.

STEP4B_PASS = NOT_REASSESSED_BY_THIS_COMPILE_ONLY_AUDIT

## 2026-09-24 retention follow-up

After the Pain cleanup, the full Laptop `04_WR` workspace was inventoried for
SOF/MIF files (21 SOFs and 6 MIFs); none matched the historical Step4B SOF or
MIF hashes listed above. A full Pain-home MIF hash search also found no exact
historical Step4B or Step5 milestone MIF. The Step4B validated runtime report
and raw logs remain preserved, but its exact historical binary pair is not
currently retained. The non-identical rebuild in this report is not promoted
to a replacement milestone and was not programmed. The latest Step6 capture
separately records Step4 startup PASS in the same run that passes Step5 and
Step6; this does not restore the missing historical Step4B artifact identity.

## Retained evidence

The six files in raw/build/ were copied from the Pain rebuild worktree and
SHA-256 checked against the remote copies:

| File | SHA-256 |
| --- | --- |
| build_info_jtag_master.txt | 335c6d11bab5d4df63f0f4cc09fadefc9a78b69045d2438ed71f8239eccac77d |
| build_info_jtag_slave.txt | 2e59f659d555bdd07baa02c8c4eeaba20e9c8f16b861ea781c5dbecb25f73833 |
| build_jtag_master.log | 41fb98110b20bc73db5c49787b466d3bfa31591174b72d00ffc33a27a4b23b5a |
| build_jtag_slave.log | 91e8afae074a1b240683fd350042f2f93fc76b73aebb5464ebb2a179bb4fccf9 |
| master-build_hashes.sha256 | e3eed3e02e705f7dbf65cb5128c5e37696505cfb984ea729214705f37349b4c3 |
| slave-build_hashes.sha256 | 3c4048c053f9770a0a6a24661d3b821ab9efa28bd91756d2918f88625dbfc440 |
