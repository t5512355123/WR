# White Rabbit Project Migration Plan

Generated: 2026-08-15
Scope: Phase 0-3 only. No source tree was moved, deleted, merged, or overwritten.

## 1. Safety backup evidence

Laptop backup:
- C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_White_Rabbit_backups\de5a_wr_pre_restructure_20260815_214635.zip
- SHA256: 23ACB94353A238CADE38723848E360FBE6B28EA3864B8621C43288B86059D2A2
- Includes the current laptop snapshot. It is outside the project root.

pain backup:
- /home/b10504072/04_White_Rabbit_backups/de5a_wr_pre_restructure_20260815_2147.tar.gz
- SHA256: aa84661a8765020b892fb8f0e33113ac8fcd728bea2b721bc7775d1b41048a2e
- Includes /home/b10504072/04_White_Rabbit, excluding only rebuildable db/, incremental_db/, and simulation/ directories.
- SOF, MIF, Quartus reports, compile logs, source, vendor, firmware, diagnostic folders, and experiment records were retained.

## 2. Inventory evidence

Laptop root:
- C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\04_White_Rabbit
- 106 selected files in the final manifest, 2,916,088 selected bytes.
- No Git repository was found.

pain root:
- /home/b10504072/04_White_Rabbit
- 4,196 selected files in the final manifest, 2,551,225,021 selected bytes.
- Full root is approximately 4.6G.
- No Git repository was found.
- Large generated directories remain in place and were not deleted.

Detailed evidence:
- 01_laptop_inventory.md and laptop_manifest.tsv
- 02_pain_inventory.md and pain_manifest.tsv

## 3. Exact relative-path comparison

- Same SHA256: 59
- Same relative path but different SHA256: 9
- Laptop-only: 38
- pain-only: 4,128

Detailed evidence:
- comparison.tsv
- 03_version_comparison.md

Important observations:
- week02/v01/DE5a_wr_master.vhd: exact SHA256 match.
- week02/v01/DE5a_wr_slave.vhd: exact SHA256 match.
- week02/v01/DE5a_wr_master.sdc: exact SHA256 match.
- week02/v01/DE5a_wr_slave.sdc: exact SHA256 match.
- week02/v01/DE5a_wr_master.qsf: different only in the discovered LAST_QUARTUS_VERSION assignment.
- week02/v01/DE5a_wr_slave.qsf: different only in the discovered LAST_QUARTUS_VERSION assignment.
- The laptop does not contain the complete pain-side vendor/wrpc-sw tree, firmware MIF set, RS422 baseline project, or pain-side Quartus output artifacts.

## 4. Current known-good baseline candidate

The current board-restored baseline is the pain-side rs422_uart_diag build, because the latest verified programming operation used:

Master:
- Source top: /home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_master_rs422.vhd
- QSF: /home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_master_rs422.qsf
- SDC: /home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_master_rs422.sdc
- SOF: /home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/output_files_master_rs422/DE5a_wr_master_rs422.sof
- Quartus programmer checksum: 0x3088011E

Slave:
- Source top: /home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_slave_rs422.vhd
- QSF: /home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_slave_rs422.qsf
- SDC: /home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/DE5a_wr_slave_rs422.sdc
- SOF: /home/b10504072/04_White_Rabbit/week02/v01/rs422_uart_diag/output_files_slave_rs422/DE5a_wr_slave_rs422.sof
- Quartus programmer checksum: 0x308FFC95

Firmware MIF:
- /home/b10504072/04_White_Rabbit/week02/v01/firmware/wrc_de5a_master.mif
- SHA256: 0d7e79f0a33d82b5afaf850e19c169bb88ea479a58029f9c19b60de561ccb5f2
- /home/b10504072/04_White_Rabbit/week02/v01/firmware/wrc_de5a_slave.mif
- SHA256: 9a9c23628ef235c6cb24376c039120bf06b2dac5d213374fc591e6f5992d1c19

Evidence for baseline:
- Master and Slave programming both reported Configuration succeeded.
- Earlier complete Quartus logs report 0 errors.
- The restored board check retained low16 probe 0x82CF on both boards: link_up=1, link_ok=1, no RX/TX encoding error.
- This baseline is known-good for FPGA configuration and PHY/PCS link, not proven White Rabbit time synchronization. time_valid, pps_valid, SoftPLL lock, TRACK_PHASE, and sub-ns PPS alignment remain unproven.

This is a provisional baseline candidate, not yet a Git main commit.

## 5. Source/generated/artifact classification

Source of truth candidates:
- Top-level VHDL/Verilog, QPF/QSF/SDC, TCL, shell/Python scripts, firmware source/configuration, wr-cores and wrpc-sw source.

Generated files:
- db/, incremental_db/, simulation/, Quartus temporary database files.
- These should remain outside Git except where an exact Quartus-generated input is required.

Milestone artifacts:
- SOF, MIF, map/fitter/STA reports, compile logs, probe logs, and metadata.
- These must be copied into artifacts/EXP-XXX folders by a controlled collection script rather than scattered manually.

Legacy experiments:
- jtag_wb_diag, clock625_jtagwb_diag, simplewa, DCO, SFP I2C, runtime probe, loadprobe, RS422, nosfpmatch, staging, and related diagnostic folders.
- Preserve first; do not delete or merge automatically.

## 6. Conflicts and unresolved decisions

1. There is no Git repository on either machine, so there is currently no commit, branch, or authoritative source identity.
2. Laptop and pain are structurally different. The laptop snapshot cannot reproduce pain's current build.
3. The root QSF differs by LAST_QUARTUS_VERSION metadata only, but this does not prove that all diagnostic QSF files are equivalent.
4. Pain contains multiple generations of firmware MIF and diagnostic SOF. The correct firmware/source pair must be selected from experiment records and compile logs, not by mtime.
5. The pain-side vendor and wrpc-sw trees are essential build inputs and are absent or incomplete in the laptop snapshot.
6. The current board baseline is a pain-side artifact. It must be copied into a new Git repository only after its source, MIF, QSF, SDC, report, and probe evidence are bundled together.
7. Time synchronization is still a technical bottleneck, but this migration phase must not change WR algorithm, PHY, PTP, SoftPLL, DMTD, port, lane, pre-emphasis, role, or PPS behavior.

## 7. Staging repository created

The non-destructive staging repository is now available at:

- Laptop: `C:\Users\t5512\OneDrive\桌面\Google 雲端硬碟\碩士班研究資料\de5a-white-rabbit`
- pain working snapshot: `/home/b10504072/de5a-white-rabbit`
- initial baseline commit: `47e705cb2d3a1ecb031962426240d911399ac44d`

The commit includes canonical Quartus source paths, vendored WR source,
firmware configurations, migration evidence, experiment templates, scripts and
the named baseline MIF/SOF/probe records. The original projects and the two
pre-restructure archives are unchanged.

## 8. Proposed next phases after review

Phase 4:
- Create a new de5a-white-rabbit repository in a separate staging location.
- Do not initialize Git inside the existing project root until the baseline snapshot is copied and verified.

Phase 5:
- Copy the pain-side baseline source and required vendor/firmware inputs into the staging repository.
- Preserve original paths and hashes in a migration manifest.

Phase 6:
- Add reproducible Master/Slave firmware build scripts and verify the exact MIF SHA256 before Quartus compile.

Phase 7:
- Add fixed Quartus 17 build scripts that fail on missing MIF and collect compile, Fitter, and TimeQuest identity.

Phase 8:
- Add experiment templates and artifact collection scripts.
- Keep diagnostic generations under legacy/archive until each one has an evidence-backed classification.

Phase 9:
- Clone the exact commit to pain, build without direct source edits, and compare functional inputs plus reports against the baseline.

Phase 10:
- Perform clean-checkout reproducibility validation before considering the migration complete.

## 8. Explicit safety decision

Do not delete, rename, merge, or overwrite any existing Laptop or pain project until the migration plan is reviewed. The current evidence supports copying pain's baseline into a new staging repository, not replacing pain with the laptop snapshot.
