# EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823

## 實驗基本資料

- Experiment ID：EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823
- 日期：2026-08-23
- branch：exp/step4-softpll-enable
- GitHub / pain exact HEAD：e9234266024157085affd070953c1d4aa0788c2a
- 前一輪診斷 commit：52a2b65a704631a4171574fc9d5ca2b86a4238ea
- 實驗目的：量測 dmtd_sampler 輸入端 clk_in=0 的最大連續 LOW sample，確認它是否對應 sampler 反相後 clk_sampled 的 HIGH qualification window。

## 唯一變因與安全邊界

本輪唯一變因是新增 read-only DMTD_INPUT_LOW_RUN_MAX。它與既有 DMTD_INPUT_HIGH_RUN_MAX 使用相同的 clk_dmtd_i/oversampling observation domain，只旁路記錄 clk_in=0 的最大連續 sample 長度，透過 Wishbone 0x00100254 回傳；不回饋功能資料路徑。

本輪沒有修改：

- Master/Slave role switching、PTP algorithm、WR signaling algorithm
- SoftPLL algorithm、DDMTD polarity、g_divide_input_by_2、g_reverse
- PI gain、lock threshold、DCO、SI5340 control
- PHY functional RTL、WRPC firmware functional behavior
- sampler pipeline、deglitch threshold、FSM、tag arbitration

所有板端讀取都是 JTAG read-only，沒有寫入任何 runtime control register。

## 建置、燒錄與 provenance

pain 使用 Quartus Prime 17.0.0 Build 595 04/25/2017 SJ Standard Edition。Master/Slave 都從 exact HEAD 先 clean build，再執行 Quartus full compile；兩份 build 都是 Full Compilation was successful，但 timing report 都是 timing_closed=NO。

| 項目 | Master | Slave |
|---|---|---|
| MIF SHA256 | 4063dde1c4109c1cd2e698358afb5ee4cd1e72ac38b3f77be707aead1ff44b66 | 9c180fdc6004bbb8cd4c06d5df875a2516501829e3d6a83c9f199e35349abb39 |
| SOF SHA256 | 83f94011e6c370d9dc5a89f13416ba75423928ecabb6f9ccf46b78f0e73fd50c | 12e93f775f07424a91b72062e04c0791f6e363872e3a733beb03149721d29c0c |
| QSF SHA256 | cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f | c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437 |
| SDC SHA256 | b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8 | b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8 |
| Programmer checksum | 0x30A9E6EE | 0x30AE5AD7 |
| 燒錄結果 | Configuration succeeded, 0 errors, 0 warnings | Configuration succeeded, 0 errors, 0 warnings |

完整 provenance、compile log、programmer log 與 JTAG raw log 保存在：

raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/

## 觀測方法

燒錄後立即執行 T0，等待約 60 秒後執行 T1。Step 2/3 使用既有 repeated focused scripts，Step 4 使用 10 samples 的 startup focused script；所有 STP script 都以 return code 0 完整結束。

```text
quartus_stp -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 20 500
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 20 500
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 10 500 all

quartus_stp -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 20 1000
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 20 1000
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 10 1000 all
```

## Step 1～Step 3 regression

### Step 1：PHY / Link

- Master/Slave CPU reset=0、fault=0、im_valid=1、marker=0xB004
- PHY/link/RX/TX ready 正常，RXERR=0
- status probe 在 runtime 有 0xEF/0xCF shadow 變化，但沒有因此宣稱 PHY failure

```text
STEP1_REGRESSION = PASS
```

### Step 2：Endpoint / MiniNIC / PTP

T1 focused window 為 20/20 valid samples：

- Master：MAC=02:00:22:33:44:01、MODE=2、穩態 PTP=6
- Slave：MAC=02:00:22:33:44:02、MODE=3、穩態 PTP=9
- Master/Slave PTP 與 MiniNIC counters 持續增加
- Slave FOREIGN=1/0、wr_config=3
- RXERR=0
- T1 focused PTP_TX_DELTA：Master 111、Slave 17

T0 早期 Slave PTP=8 視為 startup transitional state；T1 已回到穩態 PTP=9，因此不把早期值當成 regression failure。

```text
STEP2_REGRESSION = PASS
```

### Step 3：WR Parent / Signaling

Slave T1 repeated focused samples 保持：

- Foreign Master：1/0
- parent flags：1/0/1
- RX WR message：0x1001（LOCK）
- TX WR message：0x1000（SLAVE_PRESENT）
- LOCK_ENABLE=4

STATE_EVIDENCE=READ_INCONSISTENT 仍表示 local state shadow 與 handshake evidence 不完全一致；focused repeated evidence 仍通過，因此不把單一 shadow snapshot 改判成硬體失敗。

```text
STEP3_REGRESSION = PASS
```

## Step 4 T0/T1 結果

### DMTD_INPUT_HIGH_RUN_MAX 與 DMTD_INPUT_LOW_RUN_MAX

以下 packed word 的低 16 bits 是 REF、高 16 bits 是 FB：

| Window | Board | HIGH REF/FB | LOW REF/FB | HIGH raw | LOW raw |
|---|---|---:|---:|---|---|
| T0 | Master | 15 / 53644 | 65535 / 12796 | 0xD1EC000F | 0x31FCFFFF |
| T0 | Slave | 65535 / 28862 | 4 / 8703 | 0x70BEFFFF | 0x21FF0004 |
| T1 | Master | 15 / 53712 | 65535 / 12796 | 0xD1F0000F | 0x31FCFFFF |
| T1 | Slave | 65535 / 28862 | 4 / 8703 | 0x70BEFFFF | 0x21FF0004 |

Slave REF 方向的 LOW_MAX=4 與 HIGH_QUAL_MAX_STAB=2（T0）/3（T1）方向一致：對 sampler 反相後的 clk_sampled HIGH qualification，對應的 input LOW window 確實很短。這是目前最直接的新 evidence。

但 Slave FB 方向的 LOW_MAX=8703 與 HIGH_QUAL_MAX_STAB=1 不一致；而且這些 MAX 值是 cumulative history，不是目前每一個 pulse 的即時長度。因此不能只靠這一輪宣稱 sampler pipeline 或 clock polarity 已經找到根因。

### DMTD/deglitch/event chain

- T0/T1 sampled_ref、sampled_fb 都有大量 activity。
- T0/T1 accept_ref=0、accept_fb=0。
- DMTD accepted event、tag、TRR、IRQ、state transition、helper update 沒有 sustained positive delta。
- Slave RCER=1，但 accepted DMTD/event chain 尚未成立；PSTAT.locked=0 不影響本階段的判定，因為 Step 4 gate 尚未要求 closed-loop lock。
- T1 某些 sampled counter 出現 DECREASED_OR_RESET，只保留為可能 wrap/reset/cross-register read，不直接判硬體錯誤。

```text
STEP4_RESULT = NOT_PASS
```

## 判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
HARDWARE/FIRMWARE_FAILURE = ROOT_CAUSE_NOT_PROVEN
JTAG/DASHBOARD_MEASUREMENT_FAILURE = STATE_SHADOW_INCONSISTENCY_RETAINED
```

本輪排除了「所有 input HIGH window 都很短」這個過度簡化的解釋，並且在 Slave REF 方向看到 input LOW window 短與 output HIGH qualification 短的對應證據；但 FB 方向仍不一致，且 MAX 診斷是歷史最大值，不足以證明是哪一個 physical clock、polarity 或 sampler pipeline 節點造成問題。最保守的 blocker 定位仍是：

```text
clk_in LOW/HIGH waveform
  -> sampler polarity/pipeline
  -> clk_sampled HIGH qualification
  -> accepted DMTD edge
```

目前只能把這段 unresolved region 縮小，不能把 g_reverse、g_divide_input_by_2 或任何 SoftPLL/PHY 參數當成已證明根因。

## 下一步

先維持目前 bitstream 與所有 functional code 不變，進行 source-backed mapping audit：分別確認 REF/FB clk_in、clk_sampled 與 deglitcher state 的通道對應，以及 cumulative MAX register 的 clock-domain/時間語意。若仍需新增觀測，下一輪只觀察 sampler pipeline 中的單一中間節點，不修改 g_reverse、g_divide_input_by_2、threshold、FSM、SoftPLL、WR signaling、PI、DCO、SI5340 或 PHY。

## Raw evidence

- provenance：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/provenance.txt
- Master build info：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/build_info_jtag_master.txt
- Slave build info：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/build_info_jtag_slave.txt
- Master compile log：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/quartus_jtag_master_compile.log
- Slave compile log：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/quartus_jtag_slave_compile.log
- Master programmer log：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/program_master.log
- Slave programmer log：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/program_slave.log
- Step 2/3 T0：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/step23_t0.log
- Step 2/3 T1：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/step23_t1.log
- Step 3 T0：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/step3_t0.log
- Step 3 T1：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/step3_t1.log
- Step 4 T0：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/step4_t0.log
- Step 4 T1：raw/EXP-WRPC-STEP4-INPUT-LOW-RUN-20260823/step4_t1.log
