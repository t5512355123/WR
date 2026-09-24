# EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823`
- 日期：2026-08-23
- branch：`exp/step4-softpll-enable`
- GitHub / pain exact HEAD：`52a2b65a704631a4171574fc9d5ca2b86a4238ea`
- 歷史 Step 3 參考 commit：`b7d262b5321d0d273c36b6aeb6a8fc57d76ea82e`
- 實驗目的：在不改變 White Rabbit 功能行為的前提下，觀測 `dmtd_sampler` 輸入管線前 `clk_in` 的最大連續 HIGH sample 長度，判斷問題是否只是輸入 HIGH pulse 太短。

## 唯一變因與安全邊界

本輪唯一變因是增加 read-only diagnostic：`DMTD_INPUT_HIGH_RUN_MAX`。它在 `dmtd_sampler` 觀測輸入端連續 HIGH sample，並透過既有 JTAG/Wishbone read-only mailbox 回傳；不回饋 DMTD、deglitcher、SoftPLL 或 WR signaling 功能路徑。

本輪沒有修改：

- Master/Slave role switching、PTP algorithm、WR signaling algorithm
- SoftPLL algorithm、DDMTD polarity、PI gain、lock threshold
- DCO、SI5340 control、PHY functional RTL、WRPC firmware functional behavior
- sampler pipeline、deglitch threshold、FSM、tag arbitration、任何 control register 行為

所有板端觀測都是 read-only，沒有寫入任何 runtime control register。

## 建置、燒錄與 provenance

pain 主機使用 Quartus Prime `17.0.0 Build 595 04/25/2017 SJ Standard Edition`。Master/Slave 均從 exact HEAD 執行 clean firmware build 與 Quartus full compile，結果都是 `Full Compilation was successful`；但兩份 timing report 都是 `timing_closed=NO`。

| 項目 | Master | Slave |
|---|---|---|
| MIF SHA256 | `b20499d4e61c68d428e02583c140f7305a3afb0b7040327479ba48474c06eee3` | `8494790413fe547eb55bde20662e36d90b48f8f5770e1bc692dce36655b87205` |
| SOF SHA256 | `c8c0ab049e78fee47c204d673204e58a0fb66dd8416baec78070501e8b32d040` | `f674a92874ee0b5e19ca333728f6c8df9f31fc0c462649a11cd3d0ec7f33d0e0` |
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| Programmer checksum | `0x30ABDAF9` | `0x30AB0F26` |
| 燒錄結果 | `Configuration succeeded`, 0 errors, 0 warnings | `Configuration succeeded`, 0 errors, 0 warnings |

完整 provenance 與 log 保存在：

`raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/`

## 觀測方法

Step 2/3 使用既有 focused repeated sampling，避免單一 dashboard snapshot 作結論：

```text
quartus_stp -t scripts/jtag/read_master_ptp_slave_parent_long.tcl 20 1000
quartus_stp -t scripts/jtag/read_wr_handshake_focused.tcl 20 1000
```

Step 4 使用既有 startup focused script，分成燒錄後立即的 T0 與等待約 60 秒的 T1：

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 10 500 all
```

兩個時間點的 Tcl/STP 都以 return code 0 完整結束，沒有 Tcl exception。

## Step 1～Step 3 regression

### Step 1：PHY / Link

- Master status probe：`0xFF`
- Slave status probe：主要為 `0xEF`，另有 runtime status shadow 變化
- 兩板 CPU `reset=0`、`fault=0`、`im_valid=1`、`marker=0xB004`
- PHY/link/RX/TX ready 正常，`RXERR=0`

```text
STEP1_REGRESSION = PASS
```

### Step 2：Endpoint / MiniNIC / PTP

等待 startup 後的 focused T1 window 為 20/20 valid samples，無 invalid mailbox sample：

- Master：`MAC=02:00:22:33:44:01`、`MODE=2`、`PTP=6`
- Slave：`MAC=02:00:22:33:44:02`、`MODE=3`、穩態 `PTP=9`
- Master/Slave PTP 與 MiniNIC counters 都有增加
- Slave `FOREIGN=1/0`、`wr_config=3`
- `RXERR=0`
- T1 `PTP_TX_DELTA`：Master `104`、Slave `9`

短窗口個別 counter 的 delta=0 或 decrease 只保留為 measurement warning，不單獨判定硬體失敗。

```text
STEP2_REGRESSION = PASS
```

### Step 3：WR Parent / Signaling

Slave focused T1 samples 持續觀測到：

- Foreign Master：`1/0`
- parent flags：`1/0/1`
- RX WR message：`0x1001`（LOCK）
- TX WR message：`0x1000`（SLAVE_PRESENT）
- `LOCK_ENABLE=4`

`STATE_EVIDENCE=READ_INCONSISTENT`（20 個 sample 的 `local_state=0` 與 handshake/message evidence 不一致）保留為 mailbox shadow consistency evidence；focused gate 仍根據 repeated accepted evidence 判定通過。

```text
STEP3_REGRESSION = PASS
```

## Step 4 T0/T1 結果

### DMTD 輸入 HIGH run max

| Window | Board | REF max high run | FB max high run | raw packed value |
|---|---|---:|---:|---|
| T0 | Master | `8753` | `4608` | `0x12002231` |
| T1 | Master | `8753` | `4608` | `0x12002231` |
| T0 | Slave | `65535` | `12640` | `0x3160FFFF` |
| T1 | Slave | `65535` | `12664` | `0x3178FFFF` |

這些輸入端觀測值明顯大於先前 HIGH qualification abort 的 `0..5` stability depth。因此「輸入 HIGH pulse 只有 1～5 個 sample」不能解釋目前結果。

### DMTD/deglitch/event chain

- `sampled_ref` / `sampled_fb` 在 T0/T1 有大量 activity。
- `accept_ref=0`、`accept_fb=0`。
- DMTD accepted event、tag valid、TRR write、IRQ、state transition、helper update 在 T1 都沒有 sustained positive delta。
- Slave `RCER=1`，但 `PSTAT.locked=0`；這不是本階段要求 lock 的理由，而是後續 evidence。
- Slave T1 的部分 sampled/current counter 出現 `DECREASED_OR_RESET`，依規則只標記可能 wrap/reset/cross-register read，不直接宣稱硬體錯誤。

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

本輪證明 fresh HEAD 的 Step 2/3 regression 可重現，且新增的輸入 HIGH-run read-only evidence 不是短 HIGH pulse。它沒有證明根因已經是光路、時鐘域、sampler pipeline、deglitcher 或其他單一節點；目前只能把「輸入脈衝太短」排除為主要解釋，並保留 upstream clock relationship、`clk_in` 觀測語意與 sampler/deglitch boundary 的 source audit 為下一步。

## 下一步

先維持目前 bitstream 與 functional RTL 不變，進行 source-backed read-only audit：確認 `dmtd_sampler` 的 `clk_in` 實際來源、觀測 counter 所在 clock domain，以及 sampler pipeline 前後的訊號語意。下一輪仍只允許新增或使用 read-only observability；在原因更明確前，不修改 `g_divide_input_by_2`、`g_reverse`、threshold、FSM、SoftPLL、WR signaling 或 PHY。

## Raw evidence

- [provenance](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/provenance.txt)
- [Master build info](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/build_info_jtag_master.txt)
- [Slave build info](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/build_info_jtag_slave.txt)
- [Master programmer log](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/program_master.log)
- [Slave programmer log](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/program_slave.log)
- [Step 2/3 T0](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/step23_t0.log)
- [Step 2/3 T1](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/step23_t1.log)
- [Step 4 T0](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/step4_t0.log)
- [Step 4 T1](raw/EXP-WRPC-STEP4-INPUT-HIGH-RUN-20260823/step4_t1.log)
