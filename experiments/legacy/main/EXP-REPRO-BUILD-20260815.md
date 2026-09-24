# EXP-REPRO-BUILD-20260815

## 目標

確認新的 repository 能在 `pain` 使用 Quartus Prime 17.0 重新建置保留的 DE5a Master/Slave 基準輸入，且不改變 WR 行為參數。

## 輸入

- Git commit：`ff09c9db8eb45ef5e164e311ad9cf361f7d13581`
- 建置主機：`pain`
- Quartus：`/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin`，Prime 17.0 Build 595
- Master project：`quartus/rs422_uart_diag/DE5a_wr_master_rs422.qpf`
- Slave project：`quartus/rs422_uart_diag/DE5a_wr_slave_rs422.qpf`
- Master 產生的 MIF SHA256：`a664396b3d908d43d0810fa85f76dd2437dde10b1f8c3ed97514ecb304f8e29c`
- Slave 產生的 MIF SHA256：`fca9e4aebfdf49674de2af31824f2d19bb422d305fcc2a0808495f515ccb7ade`

## 僅為可重現性所做的變更

- 建置 wrapper 會在 Windows 傳輸後，恢復 vendored shell helper 的 executable bit。
- 因為 WRPC makefile 要求 `riscv32-elf-*` command name，本建置 workspace 以 private alias 提供 pain 的 `riscv64-unknown-elf-*` 工具。
- 沒有修改 PHY、QSFP、PTP、SoftPLL、DMTD、clock、role、lane 或 pre-emphasis 設定。

## 結果

- Master 韌體：PASS，已產生 `wrc.mif`。
- Slave 韌體：PASS，已產生 `wrc.mif`。
- Master Quartus：PASS，`Full Compilation was successful`，0 errors，262 warnings。
- Slave Quartus：PASS，`Full Compilation was successful`，0 errors，262 warnings。
- Master 產生的 SOF SHA256：`ea66406592d0734e7547d60ab88d6416c86bc4ef4fdfa4e4e90a330c19de1214`
- Slave 產生的 SOF SHA256：`19fac5b4fe9d2c867f052683adb31b2d266900a52fe185b78330b15318ba8b21`

警告包含既有的 TimeQuest 觀察結果：兩個 combinational loop 被以 latch 分析。它們已記錄在編譯 log 中，不是本次遷移新增的 WR 功能變更。

## 乾淨 checkout 檢查

A second clean checkout at the latest commit `d98b0c8b7e24d70c1569a03f463727e8682bd5ea`
rebuilt both firmware images and compiled both Quartus projects successfully.
精確 commit checkout `ff09c9d` 也重新建置了兩份韌體。不同次執行產生的 MIF 不會 byte-for-byte identical，因為 vendored WRPC 原始碼刻意將 C 的 `__DATE__` 與 `__TIME__` 字串嵌入韌體。因此每個實驗都記錄每份產生 image 的 build identity 與 SHA256，這是此歷史韌體建置的預期可重現性模型。

## 解讀

本實驗證明在 pain 上可重現從原始碼到 MIF 再到 SOF 的建置流程。不代表新產生的 bitstream 已經燒錄，也不代表 White Rabbit 時間同步完成。保留的硬體基準與新產生的 build 刻意分成不同 artifact set。
