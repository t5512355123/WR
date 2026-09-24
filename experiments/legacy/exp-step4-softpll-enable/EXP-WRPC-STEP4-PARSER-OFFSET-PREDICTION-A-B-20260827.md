# EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827

## 實驗目的

依分支 2 最新建議執行 WP0：只改 Master 的 built-in init command 順序，驗證目前觀測到的
`0x00017956 - 0x00017938 = 30` 是否為 `build_init_readcmd_p` 在執行 `mode master` 時留下的
合法 firmware parser state，而不是 RAM、M20K 或 Port-B read corruption。

本輪只改 functional input `CONFIG_INIT_COMMAND`；不修改 Slave、不修改 RTL、MIF、RAM mode、
`read_during_write_mode`、SoftPLL 參數、DMTD 除二拓撲或 PHY。既有 pre-main raw-pointer reader
`scripts/jtag/read_pre_main_raw_p_storage_diag.tcl` 沿用，不改 diagnostic semantics。

## 實驗邊界與 provenance

```text
BASE_COMMIT = 33fcd00b3cb75e8c051fbd18535444b7f306aefe
BRANCH = exp/step4-softpll-enable
WORK_PACKAGE = WP0
FUNCTIONAL_VARIABLE = CONFIG_INIT_COMMAND ordering (Master only)
DIAGNOSTIC_CHANGE = none
ROOT_CAUSE = NOT_PROVEN
```

## Hypothesis

Master 的 `+30` 不是 RAM corruption，而是 `build_init_readcmd_p` 已先越過目前 command 與分號，
接著才呼叫 `shell_exec()`；若 CPU 在 `mode master` 執行途中停止，pointer 會保留在該 command
之後。這個假說預測保存的 offset 應隨 command 順序改變。

## Controlled variable

```text
Only: CONFIG_INIT_COMMAND ordering in firmware/configs/de5a_master_defconfig
```

舊值與本輪新值：

```text
OLD = "vlan off;ptp stop;mode master;ptp start"
NEW = "mode master;vlan off;ptp stop;ptp start"
```

兩者 script 長度都為 39 bytes，因此仍須由新 build 的 ELF/map 重新確認
`SHELL_INIT_CMD_ADDR` 與 `BUILD_INIT_READCMD_P_STORAGE_ADDR`；判定使用 offset，不使用硬編碼 raw
pointer address。

## Pre-registered prediction

若 wedge 確實發生在第一個 `mode master` command 執行中：

```text
EXPECTED_P_OFFSET_AT_WEDGE = len("mode master;") = 12
P_OFFSET = OBSERVED_POINTER - SHELL_INIT_CMD_ADDR
```

使用既有 reader 取得：

```text
P_RAW_AT_RESET_ENTRY
P_RAW_AFTER_DATA_INIT
```

至少進行 3 次 fresh-program → read（若硬體環境允許），並分清
`FRESH_FPGA_PROGRAM` 與 `CPU_RESET_ONLY`。不把 CPU hold/release 當作 fresh FPGA configuration。

## 判定與停損

### Case A — prediction 命中

Master earliest pre-main/runtime preserved pointer 的 calculated offset 為 `+12`，且重複結果一致：

```text
PARSER_STATE_HYPOTHESIS = STRONGLY_CONFIRMED
RAM_LINE = CLOSED for the observed build_init_readcmd_p +offset anomaly
PARSER_OFFSET_ORIGIN = PROVEN
CPU_RESTART_PERSISTENCE = NOT_YET_PROVEN
ROOT_CAUSE = NOT_PROVEN
```

這只證明 observed value follows parser command ordering；不把 CPU restart mechanism 本身寫成已證明。

### Case B — prediction 失敗

若 offset 仍固定為 `+30`，或結果不是由新 command ordering 可解釋的 deterministic offset：立即停止。
不得進入 WP1，不修改 RAM、M20K、`altsyncram` 或 internal Port-B probe；重新審查 fresh-program
provenance、pointer 的真正 write/read 時間與 memory observation path。

### Case C — 其他 deterministic offset

記錄原始值與完整 raw output，不自行解釋成 PASS，立即停止並回報分支 2。

## 執行後填寫項目

```text
MODIFICATION_COMMIT = bf628b99f8827a8f7bbc8b7364b6170a83c8d082
MASTER_MIF_SHA256 = 2d88eb25f8794669e9444c3b8f09f246bd2d6c3418c1eb6ef290b420e7c0c2d9
SLAVE_MIF_SHA256 = 8b018b8f1dcb520877848d8dc6659e9337c6bb9f3a12a709f82b4fe4e88aadfb
MASTER_SOF_SHA256 = 766b1d5c8b4ee2c568cd8187329ed77dc30fb84af9517b79089a424a4a3d4496
SLAVE_SOF_SHA256 = 13d698c18bdf38535317eb64f29767fc00f4f8917e6f6ef26071bdc33cadeff0
SHELL_INIT_CMD_ADDR = 0x00017938 (Master and Slave)
BUILD_INIT_READCMD_P_STORAGE_ADDR = 0x0001C304 (Master and Slave)
P_RAW_AT_RESET_ENTRY = Master 0x00017944; Slave 0x00017938
P_RAW_AFTER_DATA_INIT = Master 0x00017944; Slave 0x00017938
P_OFFSET_AT_RESET_ENTRY = Master +0x0000000C (+12); Slave +0x00000000 (+0)
P_OFFSET_AFTER_DATA_INIT = Master +0x0000000C (+12); Slave +0x00000000 (+0)
REPEATED_RUN_CONSISTENCY = Master 4/4 at +12; Slave 4/4 at +0
QUARTUS_VERSION = 17.0.0 Build 595 04/25/2017 SJ Standard Edition
MASTER_PROGRAMMER_CHECKSUM = 0x30B1C0C2
SLAVE_PROGRAMMER_CHECKSUM = 0x30B1E32B
TIMING_CLOSED = NO (both)
MASTER_WNS = -0.213 ns
MASTER_HNS = +0.039 ns
SLAVE_WNS = -0.239 ns
SLAVE_HNS = +0.039 ns
WP0_VERDICT = PASS — parser offset prediction matched
ROOT_CAUSE = NOT_PROVEN
```

## 原始證據

完成編譯、燒錄與量測後，將 compile/program/JTAG raw logs、ELF/map、MIF/SOF hash 與本報告的
完整 provenance 收進：

```text
docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/
```

## 實際執行結果

### Build / program

本輪在 pain 以 exact commit `bf628b99f8827a8f7bbc8b7364b6170a83c8d082` 執行：

- Master firmware 與 Slave firmware 均成功建置；Master staged config 確認為
  `mode master;vlan off;ptp stop;ptp start`，Slave config 未變。
- Master/Slave Quartus 17 clean/full compile 均成功，Fitter Status 均為 Successful。
- Master SOF SHA256 為 `766b1d5c8b4ee2c568cd8187329ed77dc30fb84af9517b79089a424a4a3d4496`，
  programmer checksum `0x30B1C0C2`。
- Slave SOF SHA256 為 `13d698c18bdf38535317eb64f29767fc00f4f8917e6f6ef26071bdc33cadeff0`，
  programmer checksum `0x30B1E32B`。
- 兩台 DE5a 都回報 JTAG ID `0x02E660DD`、`Configuration succeeded`、0 errors/0 warnings。
- 兩個 fit 都是 `TIMING_CLOSED=NO`；Master worst setup/hold `-0.213/+0.039 ns`，
  Slave `-0.239/+0.039 ns`。這只列為 implementation caveat。

### Pointer observation

新 build 的 ELF symbol extraction 顯示兩個 image 都是：

```text
shell_init_cmd        = 0x00017938
build_init_readcmd_p  = 0x0001C304
```

新 Master script 長度仍為 39 bytes；`mode master;` 長度為 12 bytes。四次
fresh-program → CPU-hold → JTAG read 的 decoded CPU words 如下：

| cycle | Master reset/after-data | Master offset | Slave reset/after-data | Slave offset |
|---:|---|---:|---|---:|
| 1 | `0x00017944 / 0x00017944` | `+12` | `0x00017938 / 0x00017938` | `+0` |
| 2 | `0x00017944 / 0x00017944` | `+12` | `0x00017938 / 0x00017938` | `+0` |
| 3 | `0x00017944 / 0x00017944` | `+12` | `0x00017938 / 0x00017938` | `+0` |
| 4 | `0x00017944 / 0x00017944` | `+12` | `0x00017938 / 0x00017938` | `+0` |

因此本輪為 Case A：

```text
PARSER_STATE_HYPOTHESIS = STRONGLY_CONFIRMED
RAM_LINE = CLOSED for the observed build_init_readcmd_p +offset anomaly
PARSER_OFFSET_ORIGIN = PROVEN
CPU_RESTART_PERSISTENCE = NOT_YET_PROVEN
ROOT_CAUSE = NOT_PROVEN
```

這個結果只證明 observed value follows parser command ordering；沒有把 CPU restart
mechanism、IRQ storm、fault handler 或整體 Step 4 寫成已證明。依分支 2 最新指示，WP0 到此
停止，不自行開始 WP1。

## 原始證據索引

- [measurement_summary.txt](raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/measurement_summary.txt)
- [symbol_addresses.txt](raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/symbol_addresses.txt)
- [read_1.log](raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/read_1.log) 至 `read_4.log`
- [program_master_2.log](raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/program_master_2.log) 至 `program_master_4.log`
- [program_slave_2.log](raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/program_slave_2.log) 至 `program_slave_4.log`
- [build_info_jtag_master.txt](raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/build_info_jtag_master.txt)
- [build_info_jtag_slave.txt](raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/build_info_jtag_slave.txt)
- [artifact_sha256.txt](raw/EXP-WRPC-STEP4-PARSER-OFFSET-PREDICTION-A-B-20260827/artifact_sha256.txt)

WP0 完成後 STOP，等待分支 2 下一輪建議；不自行開始 WP1。
