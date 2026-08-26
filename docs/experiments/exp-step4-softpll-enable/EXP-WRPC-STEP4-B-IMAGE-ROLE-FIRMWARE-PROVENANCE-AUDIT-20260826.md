# EXP-WRPC-STEP4-B-IMAGE-ROLE-FIRMWARE-PROVENANCE-AUDIT-20260826

## 實驗身分

- 日期：2026-08-26
- Branch：`exp/step4-softpll-enable`
- B functional commit：`73d16414cf015f9411431ae7f5a862afb8454098`
- Audit commit baseline：`3bd953e13ed0e3f365ca670d72fe97b2d1d99923`
- 實驗主機：`pain`
- Audit 類型：B image role / firmware / MIF / programming provenance 唯讀稽核
- 本輪動作：只讀取既有 build output、generated config、compile log、program log 與 source mapping；未修改 source、未 rebuild、未 reprogram

## 稽核目的與結論

branch2 要求先釐清 B image 造成 Step 2/3 barrier 失敗，是否來自 Master/Slave firmware role、MIF、program cable 或 runtime diagnostic source 錯置。本輪逐項核對後：

```text
MASTER_SLAVE_FIRMWARE_CONFIG = PASS
MASTER_SLAVE_MIF_MAPPING     = PASS
MASTER_SLAVE_PROGRAM_MAPPING = PASS
MAC_IDENTITY_MAPPING         = PASS
RUNTIME_ROLE_STATE            = MISMATCH
PROVENANCE_AUDIT              = PASS
FUNCTIONAL_FIX                = NONE
STEP4_ALLOWED                 = NO
```

沒有找到可授權的「只修正 MIF / firmware role / programmer mapping」問題，因此依停損規則不重建、不重新燒錄，也不把既有 Step 4 欄位當成有效 functional result。待 branch2 決定如何處理 runtime role/state mismatch。

## 1. Firmware role configuration

Build scripts 的輸入與輸出路徑是分離的：

| 項目 | Master | Slave |
|---|---|---|
| defconfig | `firmware/configs/de5a_master_defconfig` | `firmware/configs/de5a_slave_defconfig` |
| identity header | `firmware/configs/de5a_master_identity.h` | `firmware/configs/de5a_slave_identity.h` |
| firmware output | `build/firmware/master` | `build/firmware/slave` |
| generated `CONFIG_INIT_COMMAND` | `vlan off;ptp stop;mode master;ptp start` | `vlan off;ptp stop;mode slave;ptp start` |
| fallback MAC identity | ending `...01` | ending `...02` |

Pain 上這次 B build 的 generated `.config` 確實包含正確的 role-specific `CONFIG_INIT_COMMAND`；`wrc.elf` 的字串也分別包含 master 與 slave init command。兩邊同時設定的 `CONFIG_STEP2_DISABLE_PERSISTENT_INIT=y` 只停用 persistent flash init，並未移除 built-in role init。

Build output 的 firmware hashes 與 generated configuration evidence 保存在：

`raw/EXP-WRPC-STEP4-B-IMAGE-ROLE-FIRMWARE-PROVENANCE-AUDIT-20260826/provenance_snapshot.txt`

## 2. MIF 及 Quartus image mapping

Top-level VHDL 明確使用：

| Quartus top | `g_dpram_initf` | MIF SHA256 |
|---|---|---|
| `DE5a_wr_master_jtag` | `../../build/firmware/master/wrc.mif` | `861948c458411465ce84839871bbea3fa82539f87739f855b747363c57655f70` |
| `DE5a_wr_slave_jtag` | `../../build/firmware/slave/wrc.mif` | `57ea898297d07297f80bb12aa5b1c501fabbf089878bce90c36492219d0dd4aa` |

兩份 clean Quartus compile log 的 build identity 都是同一個 B functional commit `73d1641`，且各自記錄對應 role 的 `init_file` 與 MIF SHA256：

- Master compile log：`../../build/firmware/master/wrc.mif`
- Slave compile log：`../../build/firmware/slave/wrc.mif`

因此沒有看到 Master/Slave MIF 交叉引用或把舊 MIF 帶入 SOF 的證據。

## 3. SOF 與 programmer cable mapping

既有 program logs 顯示：

| Image | SOF SHA256 | Cable | Programmer result |
|---|---|---|---|
| Master | `c68f9c47683d47746594792ab270df86c59ce8d248c9631b52a102712bfb3939` | `DE5 [1-11.1]` | configuration succeeded; 0 errors, 0 warnings |
| Slave | `d03a01cdb2d4c3e831c1154d0d8da04c9cfe03881c0144c53da5bb6e1ef27536` | `DE5 [1-11.2]` | configuration succeeded; 0 errors, 0 warnings |

Programming checksum 分別是 `0x30B1722A` 與 `0x30B05EEB`。B barrier 的 runtime MAC 也交叉驗證為 Master `...01`、Slave `...02`，和兩份 identity header 相符；這不支持 cable 或 image swap 假說。

## 4. Runtime diagnostic source 對照

source audit 顯示：

- `vendor/wrpc-sw/shell/shell.c` 會把 `CONFIG_INIT_COMMAND` 拆成以分號分隔的命令執行。
- `vendor/wrpc-sw/wrc_main.c` 的 default startup 先以 Slave mode 啟動，built-in shell boot script 隨後才執行 role-specific command。
- `vendor/wrpc-sw/shell/cmd_ptp.c` 把 `mode master` / `mode slave` 對應到 WRC PTP mode。
- `vendor/wrpc-sw/lib/task-diags.c` 的 WDIAGS mode 來自 `wrc_ptp_get_mode()`，PTP state 則來自 PPSI state；兩者不是同一個欄位。

B barrier 中 Master endpoint MAC 正確，但曾讀到 `WDIAGS mode=3 SLAVE`，同時 PTP state 出現 MASTER/SLAVE 混合；Slave 也出現 mixed/inconsistent mode/state samples。這是可重現於既有 B raw logs 的 runtime role/state mismatch，但不能由本輪 provenance evidence 推論成 MIF、firmware role 或 cable mapping 錯誤。

## 判定與停損

```text
STEP1_REGRESSION = PASS       (from B barrier record)
STEP2_REGRESSION = FAIL/INVALID
STEP3_REGRESSION = FAIL/INVALID
STEP4_ALLOWED    = NO
PROVENANCE_AUDIT = PASS
RUNTIME_ANOMALY  = role/state telemetry mismatch
AB_RESULT        = INCONCLUSIVE
```

本輪不採取 firmware/MIF 修正，保留 B image 及既有 raw evidence，提交本 audit 後請 branch2 決定下一個單一動作。下一輪若要進入 functional Step 4，仍必須先讓 Step 2/3 regression barrier 通過。

## Raw evidence

- 本輪 provenance snapshot：`raw/EXP-WRPC-STEP4-B-IMAGE-ROLE-FIRMWARE-PROVENANCE-AUDIT-20260826/provenance_snapshot.txt`
- B build/program/compile/raw barrier：`raw/EXP-WRPC-STEP4-CORE-DMTD-DIV2-20260826/`
- B functional report：`EXP-WRPC-STEP4-CORE-DMTD-DIV2-20260826.md`
