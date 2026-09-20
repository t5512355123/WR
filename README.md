# DE5a White Rabbit

本 repository 是 DE5a Arria 10 White Rabbit 專案的正式原始碼 repository。

## 硬體

- Terasic DE5a / Arria 10
- White Rabbit core (`xwr_core`)
- Arria 10 WR PHY
- QSFP-A lane 0，作為 WR 1 GbE link
- QSFP-B reference clock，作為約 124.992 MHz 的 DMTD clock
- SI5340/DCO clock control
- uRV RISC-V soft CPU
- PPS output to SMA_CLKOUT

## Repository 規則

原始碼、建置輸入與說明文件會納入版本控制。Quartus database 與一般建置輸出會被忽略。里程碑 SOF/MIF/report/probe 成套證據應放在 `artifacts/EXP-XXX/`，並附上 `metadata.md`。

原始 Laptop 與 pain 專案保留在本 repository 外部。遷移證據位於 `docs/migration/`。

原始碼、產生式輸入與里程碑 artifact 規則整理在
`docs/migration/05_reproducibility_audit.md`. Path mapping and unresolved
Laptop/pain 衝突記錄在 `docs/migration/06_path_mapping.md` 與
`docs/migration/07_open_decisions.md`。
分支、建置、artifact 與復原規則位於 `docs/git_workflow.md`。

## 目前狀態

請先閱讀 `STATUS.md`。目前已找到曾同時看到 HPLL/Helper lock、Main frequency
lock、Main phase lock 與 `PSTAT.locked=1` 的版本，並在同一個有效 WR session
維持連續 300 秒，因此目前 Step5 functional milestone 已 PASS。精確證據、
SOF/MIF provenance 與 raw observer output 見
[`EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/REPORT.md`](docs/experiments/exp-step5-softpll-lock/EXP-S5-MAIN-FREQ-THRESH20-PHASE-KI1-F4L-STABILITY-300S-20260920/REPORT.md)。
Step5 不要求 Quartus timing closure 全部為 0；本次 Master WNS=-0.289 ns、
Slave WNS=-0.361 ns，timing closure 是獨立的後續工作，詳見
[`docs/experiments/exp-step5-softpll-lock/STEP5-PASS-MILESTONE.md`](docs/experiments/exp-step5-softpll-lock/STEP5-PASS-MILESTONE.md)。

## 在 pain 上建置

```sh
scripts/pain/pain_status.sh
scripts/build/build_master.sh
scripts/build/build_slave.sh
```

這些 script 預設使用 Quartus Prime 17.0，且編譯前需要 `build/firmware/` 下的精確 MIF 檔案。
建置身份會記錄 Git commit、Quartus 版本、QSF/SDC/MIF/SOF hash、Fitter 狀態、timing slack 與 unconstrained-path 數量。編譯成功不代表 timing closure，請參閱 `STATUS.md`。

## 韌體

```sh
firmware/scripts/build_master_firmware.sh
firmware/scripts/build_slave_firmware.sh
```

這些 script 會從 vendored `wrpc-sw` tree 的暫存副本進行建置，避免 Kconfig 或產生式檔案修改已納入版本控制的原始碼 tree。

## 燒錄與證據

```sh
scripts/program/program_master.sh
scripts/program/program_slave.sh
scripts/experiment/collect_artifacts.sh EXP-XXX
```

請使用 `docs/experiments/EXP-XXX_TEMPLATE.md` 實驗模板，並記錄精確的 Git commit、MIF、QSF、SDC、SOF 與 probe 證據。
