# EXP-WRPC-STEP4-LOW-QUAL-ABORT32-20260824

## 實驗資訊

- Experiment ID：`EXP-WRPC-STEP4-LOW-QUAL-ABORT32-20260824`
- 日期：2026/08/24
- Branch：`exp/step4-softpll-enable`
- 診斷 source commit：`126dda8550db3f8de33c9e37303e4a16aa730350`
- 狀態：fresh build、雙板燒錄與實機 JTAG 量測完成

## 想驗證什麼

上一輪已確認 Slave REF/FB 的 sampled transition 持續增加，但 deglitch FSM 停在
`WAIT_STABLE_0`，`WAIT_EDGE_ENTRY` 在 T0/T1 視窗皆沒有增加。本輪只回答：

> LOW qualification 是否已開始累積，卻在達到 threshold 前反覆被 HIGH sample 中斷？

## 相較上一輪的唯一修改

- 保留既有 LOW qualification abort 條件不變：
  `state = WAIT_STABLE_0 && stab_cntr != 0 && clk_sampled != 0`。
- 將既有 LOW qualification abort 診斷計數器由 16-bit 擴成 32-bit。
- 透過唯讀 JTAG alias 分別讀回 REF/FB 完整計數器：
  - `0x00100250`：REF LOW qualification abort count
  - `0x00100254`：FB LOW qualification abort count
- 保留 `WAIT_EDGE_ENTRY`、accept 與 downstream event 計數器，以便同一視窗比較。

本輪沒有修改 WR role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、
lock threshold、DCO、SI5340、PHY functional RTL 或 WRPC firmware functional behavior。

## Build 與 Artifact Provenance

- Quartus version：17.0.0 Build 595 Standard Edition
- Master MIF SHA256：`e1b83b06e1c589ce76bce59aebddae9e080331ebb479dde93c65c0599748ec2d`
- Slave MIF SHA256：`b7410ed150e30b42f8ac0bdae97ad4b50c9bca3fedc7b19c4c4cfa9865f0a5be`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master/Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`486c54a8deb633a46decab57340ecc16b07a5833c91532a8ea2879eb86c5f108`
- Slave SOF SHA256：`cdfaf06ddca05aa9a972d990fb907c8980d87fc338f81ce7efeeba8f011c9a81`
- Master compile：PASS，`timing_closed=NO`，setup/hold WNS=`-0.400 ns / +0.037 ns`
- Slave compile：PASS，`timing_closed=NO`，setup/hold WNS=`-0.216 ns / +0.038 ns`，recovery WNS=`-0.166 ns`

## 燒錄結果

- Master：2026/08/24 02:34，`DE5 [1-11.1]`，checksum `0x30A84EF1`；configuration succeeded，0 errors / 0 warnings。
- Slave：2026/08/24 02:35，`DE5 [1-11.2]`，checksum `0x30B13132`；configuration succeeded，0 errors / 0 warnings。

Master 燒錄前兩次嘗試只停在非互動 `sudo` 驗證，Quartus Programmer 尚未啟動，因此不構成 FPGA 燒錄實驗；第三次改以 `sudo -S` 執行同一 fresh SOF 後成功。

## JTAG / Runtime 原始結果

### Step 1～3 regression barrier

`read_wr_handshake_focused.tcl 30 1000`：

| Gate | Master | Slave |
|---|---|---|
| 有效 samples | 30/30 | 30/30 |
| 無效 samples | 0 | 0 |
| Counter decrease | 0 | 0 |
| PTP TX delta | 168 | 27 |
| Step 2 | PASS | PASS |
| Step 3 | N/A | PASS |

Slave 30/30 samples 均維持 foreign=`1/0`、parent=`1/0/1`、RX=`LOCK 0x1001`、
TX=`SLAVE_PRESENT 0x1000`、`LOCK_ENABLE=4`。live state 仍為 `WRS_IDLE`，因此保留
`STATE_EVIDENCE=READ_INCONSISTENT` 與 `POST_STEP3_LOCK_STAGE=TIMEOUT`，但 repeated
handshake evidence 足以維持 Step 3 PASS。

### Step 4 T0/T1

兩次 `read_step4_startup_focused.tcl 10 500 all` 均完整結束，沒有 Tcl exception。

| Board | Window | REF sampled delta | FB sampled delta | REF LOW abort | FB LOW abort | REF/FB state | WAIT_EDGE/accept/downstream |
|---|---:|---:|---:|---:|---:|---|---|
| Master | T0 | 687,910,962 | 685,879,212 | 0 | 0（累計已為 0xFFFFFFFF） | `GOT_EDGE/WAIT_STABLE_0` | 全部 delta=0 |
| Master | T1 | 687,520,494 | 685,488,709 | 0 | 0（累計已為 0xFFFFFFFF） | `GOT_EDGE/WAIT_STABLE_0` | 全部 delta=0 |
| Slave | T0 | 689,191,849（32-bit wrap） | 686,599,947（32-bit wrap） | 0 | 0 | `GOT_EDGE/GOT_EDGE` | 全部 delta=0 |
| Slave | T1 | 689,245,762 | 686,649,006 | 0 | 0 | `GOT_EDGE/GOT_EDGE` | 全部 delta=0 |

Slave T0 的 script 原始輸出是 `DECREASED_OR_RESET`，因為 before/after 跨過
`0xFFFFFFFF -> 0x00000000`。依 unsigned 32-bit modulo 計算後，REF/FB delta 分別為
689,191,849 與 686,599,947，且 T1 得到相近數值；這支持 counter wrap，不是本輪的
硬體 reset 證據。

LOW abort 累計原始值：

- Master REF：`0x00000000`；Master FB：`0xFFFFFFFF`，後者已飽和，無法再用 delta 判斷目前活動。
- Slave REF/FB：皆為 `0x00000000`，T0/T1 皆沒有增加。

兩片的 WAIT_EDGE entry、accepted DMTD、DMTD sys event、tag pending/grant/valid、TRR、
IRQ、sequencer transition 與 helper update 在 T0/T1 都沒有 sustained delta。Dashboard
再次顯示兩片 Step 1/2 PASS、Slave Step 3 PASS、Slave Step 4 error；Tcl 成功結束，
0 errors / 0 warnings。

### Raw evidence

原始檔位於：

`docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-LOW-QUAL-ABORT32-20260824/`

- firmware、Quartus compile 與 build-info logs
- Master/Slave TimeQuest 摘要
- Master/Slave programmer logs
- `step23.log`
- `step4-t0.log`、`step4-t1.log`
- `dashboard.log`
- artifact provenance 與 SHA256

## 判讀規則

- `WAIT_EDGE delta = 0` 且 `LOW_ABORT32 delta > 0`：LOW qualification 正在反覆開始又被中斷。
- `WAIT_EDGE delta = 0` 且 `LOW_ABORT32 delta = 0`：沒有觀測到「累積到一半被中斷」，下一步才檢查 counter 是否根本無法有效累積或 threshold reach 條件。
- 累計值非零只代表歷史曾發生；本輪 sustained activity 必須以 T0/T1 delta 判斷。
- Quartus timing failure 只能列為 caveat，不能在沒有直接證據時宣稱為根因。

## Observation

1. Fresh image 再次通過 Step 1～3 regression barrier，允許解讀 Step 4 diagnostics。
2. Slave LOW-abort REF/FB 從 reset 至量測時仍為 0，且 T0/T1 delta=0。因此沒有證據支持
   「LOW qualification 已開始累積，卻在達到 threshold 前反覆被 HIGH sample 中斷」。
3. Slave 在本輪 fresh image 的兩個視窗都位於 `GOT_EDGE/GOT_EDGE`，與上一輪觀測到的
   `WAIT_STABLE_0/WAIT_STABLE_0` 不同。不能把上一輪的 current-state 定位直接套用到本輪。
4. Master FB LOW-abort 已飽和，因此它的 delta=0 不代表沒有活動；Master REF 累計為 0。
5. sampled transition 仍有大量活動，但 accept 與後續 event chain 都沒有 sustained activity，
   所以 Step 4 gate 仍未通過。
6. 本輪只排除一個假設，沒有證明 DDMTD polarity、clock quality、threshold、時序違反或任一
   RTL assignment 是根因。`timing_closed=NO` 仍是重要 caveat，但不是已證明根因。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
SLAVE_LOW_QUAL_ABORT_ACTIVE = NO_EVIDENCE
SLAVE_CURRENT_DEGLITCH_STATE = GOT_EDGE/GOT_EDGE
ROOT_CAUSE = NOT_PROVEN
JTAG_MEASUREMENT = VALID_WITH_SAMPLED_COUNTER_WRAP_NOTED
```

Step 4 尚未達成。本輪的 source-backed evidence 不支持 Slave LOW qualification 正在反覆
累積後被中斷；目前未形成 sustained activity 的邊界仍在 deglitch acceptance 之前，但因
current state 已位於 `GOT_EDGE`，下一個診斷應聚焦 HIGH qualification/accept，而不是直接
修改 functional behavior。

## Next Step

將 exact source commit、原始 log 與本紀錄推送 GitHub，交由「分支 · White Rabbit 技術應用」
覆核；下一輪只依 reviewer 建議增加一個 read-only、source-backed observability 變因。
