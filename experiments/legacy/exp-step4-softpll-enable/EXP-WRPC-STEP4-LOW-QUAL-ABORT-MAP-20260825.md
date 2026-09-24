# EXP-WRPC-STEP4-LOW-QUAL-ABORT-MAP-20260825

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-LOW-QUAL-ABORT-MAP-20260825`
- 日期：2026-08-25
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Git commit：`031e3c5018bd5a6487f7d80235cb9946dcbcdd8d`
- 實驗類型：fresh SOF、Step 2/3 regression、LOW qualification abort 唯讀觀測
- 是否修改功能演算法：否

## 實驗目的

上一輪 Step 4 觀測顯示 DMTD native/sample 與 D0 stable-hit 有活動，但 qualification 之後的 accept、tag、TRR、IRQ、helper 沒有活動。這次只增加一個既有 RTL 計數器的唯讀 Wishbone 映射，用來確認 `dbg_low_qual_abort_count` 是否真的增加。

本輪唯一變因是：

- `SPLL_DEGLITCH_THR` 的 read-side upper 16 bits 映射 REF `dbg_low_qual_abort_count(15 downto 0)`。
- `SPLL_OCER` 的 read-side upper 16 bits 映射 FB `dbg_low_qual_abort_count(15 downto 0)`。
- 原有 threshold、OCER lower bits、write behavior、SoftPLL FSM 與演算法均未修改。

本輪沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL algorithm、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。

## Source-backed 映射

來源是 `dmtd_with_deglitcher.vhd` 既有的 `dbg_low_qual_abort_count_o`，由 `wr_softpll_ng.vhd` 傳入 `spll_wb_slave.vhd` 的 read-only diagnostic port。

| Wishbone address | read-side diagnostic field | 功能欄位保留 |
|---|---|---|
| `0x00100248` | REF low qualification abort count low16，對應 `DEGLITCH_THR[31:16]` | `DEGLITCH_THR[15:0]` |
| `0x00100228` | FB low qualification abort count low16，對應 `OCER[31:16]` | `OCER[7:0]` |

Tcl 以 50 個 sample 的 modulo-16 delta 判斷計數器是否增加；每個欄位都保存 valid/invalid 狀態。這不是新的硬體計數器，也沒有寫入任何控制暫存器。

## Fresh build provenance

- Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`
- Build commit：`031e3c5018bd5a6487f7d80235cb9946dcbcdd8d`
- Master build：`Full Compilation was successful`
- Slave build：`Full Compilation was successful`
- Fitter：Master/Slave 均 `Successful`
- Timing：既有報告為 `TIMING_CLOSED=NO`，不能把本次 compile success 解讀成 timing closure success。

| 項目 | Master | Slave |
|---|---|---|
| Project | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| MIF SHA256 | `4a8341407ad4b45282794d61f109ff2b303f35d1eb95c1a12fa8157c661711ba` | `6c5575e8494a6bf93ba7294ad515ac8ce17399787781660f2fceba101032e7b6` |
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| SOF SHA256 | `d022ec35ad5150b30dc23d037c9816ba799c8493d940569c6412650dbdbe4364` | `0e6ee8e5f204697bc87d573192344caffb68780a14f5eddba980aeddacf3c39f` |
| Programmer checksum | `0x30B3DBD7` | `0x30B313A7` |

## 燒錄結果

Master 使用 `DE5 [1-11.1]`，Slave 使用 `DE5 [1-11.2]`。兩次 programmer 都得到：

```text
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

這次確實是 `031e3c5` fresh build 的 SOF，不是 historical `c88cc05` 或上一輪 `3f02966` SOF。

## Step 2 regression

使用既有 `read_master_ptp_slave_parent_long.tcl` 20 samples、500 ms gap，並以 Step 3 focused script 再次觀察 counters。

### Master

- MAC：`02:00:22:33:44:01`
- `MODE=2`
- `PTP=6`
- PTP RX/TX、MiniNIC TX/RX 持續增加
- `RXERR=0`

### Slave

- MAC：`02:00:22:33:44:02`
- `MODE=3`
- startup 曾短暫出現 `PTP=8`，之後穩定為 `PTP=9`
- 多數 sample 為 `FOREIGN=03000001`
- PTP RX/TX、MiniNIC TX/RX 持續增加
- `RXERR=0`

結論：

```text
STEP2_REGRESSION = PASS
```

單點 dashboard 的 mailbox snapshot 偶爾出現 `FOREIGN=00000001` 或 status bit 短暫變化；focused repeated sample 的 valid evidence 才用於本 gate，沒有把孤立 snapshot 當成硬體 failure。

## Step 3 regression

使用 `read_wr_handshake_focused.tcl`，30 samples、500 ms gap、每筆最多 25 次 mailbox poll。

Slave 30/30 samples 均為 valid，且一致觀察到：

- foreign master：`1/0`
- parent is WR：`1`
- parent calibrated：`1`
- RX WR message：`0x1001`，count `>0`
- TX WR message：`0x1000`，count `>0`
- `LOCK_ENABLE=4`
- `RCER=0x00000001`
- PTP TX delta：`14`
- `counter_decreased=0`

WR current state 讀值仍回報 `local_state=0 / next_state=0`，所以保留：

```text
STATE_EVIDENCE = READ_INCONSISTENT
```

此欄位沒有被拿來推論 SoftPLL 已 lock；依既有 focused gate，parent/signaling/lock-enable evidence 仍通過。

結論：

```text
STEP3_REGRESSION = PASS
STATE_EVIDENCE = READ_INCONSISTENT
```

## Step 4 唯讀結果

### LOW qualification abort counter

`read_step4_startup_focused.tcl 50 200 low_abort`：

| Board | samples | REF valid | FB valid | REF delta | FB delta | 結果 |
|---|---:|---:|---:|---:|---:|---|
| Master | 50 | 50 | 50 | 0 | 0 | VALID |
| Slave | 50 | 50 | 50 | 0 | 0 | VALID |

因此本次 read path 本身有效，但在 50 samples 期間沒有觀察到 `dbg_low_qual_abort_count` 增加。

### 同一次 `all` focused observation 的關鍵值

| 證據 | Master | Slave |
|---|---:|---:|
| `SPLL_STATE` | `0x00020009` | `0x00030009` |
| `RCER` | `0` | `1` |
| `OCER` lower value | `0x01` | `0x01` |
| DMTD native edge delta | `2167784689` | `2171132110` |
| D0 stable-hit delta | `2167843479` | `2171245210` |
| D0 transition delta | `2152373527` | `2167778657` |
| `WAIT_STABLE0` max | `0` | `0` |
| tag/TRR/IRQ/helper/state-transition delta | `0` | `0` |
| `GOT_EDGE_HIGH_ABORT` sticky evidence | 有 | 有 |

觀測到的 qualification boundary：

- Master：`ref_max_before_abort=8`、`fb_max_before_abort=7`
- Slave：`ref_max_before_abort=40`、`fb_max_before_abort=1`
- threshold：`1000`
- `DMTD_REF/FB_WAIT_EDGE_ENTRY` delta：`0`
- `DMTD_REF/FB_GOT_EDGE_ENTRY` delta：`0`
- `DMTD_REF/FB_ACCEPT` delta：`0`
- tag、TRR write、IRQ、helper update、state transition：均為 `0`

`DMTD_NATIVE_EDGE_COUNT64`、D0 stable-hit、D0 transition 與 `CURRENT_TICS` 持續增加，表示 DMTD/sample clock 與前段統計路徑有活動；但沒有進入後段 accept/tag/TRR/servo 路徑。

結論：

```text
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
```

這不是 JTAG invalid read：LOW abort 映射 50/50 valid，其他 counters 也能穩定讀取。現有證據把第一個可重現的阻塞位置收斂在 `GOT_EDGE_HIGH_ABORT` 後、`WAIT_EDGE/ACCEPT` 之前；但本輪沒有修改 functional code，因此不能宣稱已確定根因是某一個 RTL/PHY 元件。

## Dashboard 輸出完整性

`read_wb_runtime.tcl` 執行成功，Quartus SignalTap II 回報 0 errors、0 warnings。Dashboard 讀值與 focused script 一致：

- Step 1：兩板 pass
- Step 2：兩板 pass
- Step 3：Slave pass，但 `WRS_IDLE`/`READ_INCONSISTENT` 保留為注意證據
- Step 4：event counters 為零，因此 dashboard 顯示 error；focused script 同時證明前段 DMTD/sample activity 存在

Step 4 event counter 的零值不應與 DMTD native/sample activity 混為同一個計數器；前者代表後段事件，後者代表前段取樣/統計活動。

## 證據檔案

原始檔案位於：

`docs/experiments/exp-step4-softpll-enable/raw/20260825-low-abort-map-031e3c5/`

- `03-build-info-master.txt`
- `04-build-info-slave.txt`
- `06-program-master.log`
- `07-program-slave.log`
- `09-step2-long.log`
- `10-step3-focused.log`
- `11-step4-low-abort.log`
- `12-step4-all.log`
- `13-dashboard.log`
- `08-artifact-sha256.txt`

## Observation

1. Fresh/current hardware 上的 Step 2 packet path 可重現。
2. Fresh/current hardware 上的 Step 3 parent/signaling/lock-enable focused gate 可重現，但 WR current-state evidence 仍為 `READ_INCONSISTENT`。
3. LOW qualification abort counter 的新增唯讀映射有效，但 delta=0；因此它沒有支持「LOW qualification abort counter 持續增加」這個假設。
4. DMTD input/sample 與 D0 stable/transition counters 持續增加，但 GOT_EDGE/ACCEPT/tag/TRR/IRQ/helper 沒有活動。
5. Quartus build 成功但 timing 尚未 closed；這是獨立的 build quality issue，本紀錄不把它直接等同 runtime root cause。

## Conclusion

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STATE_EVIDENCE = READ_INCONSISTENT
STEP4_ALLOWED = YES
STEP4_RESULT = NOT_PASS
```

本次沒有證明 SoftPLL 已完成 Step 4 startup。證據較支持「JTAG 讀值有效，前段 DMTD/sample 活動存在，但 qualification boundary 之後沒有進入後段 event path」。目前應把問題視為需要進一步的 source-backed/read-only diagnosis；不能把它寫成已確定的 PHY、SoftPLL algorithm 或 DCO failure。

## Next Step

維持 `031e3c5` 與目前 fresh SOF 不變，先與 reviewer 釐清下一個單一唯讀觀測點。下一輪仍不得同時修改 threshold、FSM、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340；在取得共識前不進行新的 functional experiment。
