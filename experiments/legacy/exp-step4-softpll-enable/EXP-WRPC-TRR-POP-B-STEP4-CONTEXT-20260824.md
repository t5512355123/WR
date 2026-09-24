# EXP-WRPC-TRR-POP-B-STEP4-CONTEXT-20260824

## 實驗設定

- 實驗名稱：`Phase B：最小 TRR_POP read-only observability 與 Step 2/3 回歸`
- 日期：2026-08-24
- 工作 branch：`exp/step4-softpll-enable`
- 實驗 HEAD：`812cfcebb2301da4c0dc55e52b53a4bbf10417ac`
- 參考 control：`7dd298bb143d35b73d16dc9007c26d88c7da5622`
- 功能基準要求：`51864b8743759bc20bea817af4bcd19ea81ab4ac`
- 實驗類型：fresh firmware build、Quartus clean compile、雙板 program、read-only runtime observation

本輪沒有修改 FPGA role、PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。

## 目的

先確認 B 版本在加入最小 `TRR_POP` 觀測後，仍然能重現 Step 2 / Step 3；接著以 read-only registers 觀察 Step 4 的資料鏈：

```text
DMTD sampled transition
    -> deglitch accept
    -> tag
    -> TRR write
    -> TRR POP
    -> helper update
    -> sequencer activity
```

本輪不是要讓 SoftPLL lock，也不是要修改 SoftPLL。唯一的功能性差異是增加一個成功讀取 `SPLL->TRR_R0` 後才遞增的 firmware counter，並透過 dedicated read-only WDIAGS export 讀回。

## 相較 control 的唯一修改

相較 `7dd298bb`，B 版本的 source diff 是 6 個檔案、19 行新增或修改：

```text
vendor/wr-cores/modules/wrc_core/wrc_periph.vhd
vendor/wrpc-sw/dev/wdiags.c
vendor/wrpc-sw/include/dev/wdiags.h
vendor/wrpc-sw/lib/task-diags.c
vendor/wrpc-sw/softpll/softpll_ng.c
vendor/wrpc-sw/softpll/softpll_ng.h
```

修改內容只有：

- 在成功執行 `TRR_R0` pop 後遞增 `wrpc_spll_trr_pop_count`。
- 在 `spll_very_init()` 清除該 counter。
- 透過 WDIAGS private offset `0x154`、對應 physical Wishbone address `0x00100B54` 提供 read-only 值。

這個 counter 不會寫入任何 control register，也不會改變 tag、TRR、helper、servo 或 sequencer 的控制流程。

## Fresh build 與 provenance

pain 先 checkout exact HEAD，再執行 firmware build 與 Quartus clean compile。使用 Quartus Prime 17.0.0 Build 595 Standard Edition。

### Firmware MIF

```text
Master MIF SHA256 = ff9834e4c7dad2a63e0be6f6159668006ca397397fdd56558b2971dbbf524c3e
Slave  MIF SHA256 = 3c7c7836006ea0bcee2b000368483b7034e370235ecf667793863af3c9112b09
```

### Quartus input hash

```text
Master QSF SHA256 = cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f
Slave  QSF SHA256 = c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437
SDC SHA256        = b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8
```

### Fresh SOF

```text
Master SOF SHA256 = 59294d398a96eb1ef5bc1c5a2ad4bfc05abc4562aa107b3bfd50de62f1160698
Slave  SOF SHA256 = f2f6b6a6e84a017c53349365ff2d8f5b80093a079bf49c2d160154b9b9fd2cb0
```

Quartus fitter 與 full compilation 均成功。該次報告的 timing closure 仍為 `NO`，不是本輪 runtime regression 的判定條件：Master WNS setup `-0.399 ns`、Slave WNS setup `-0.182 ns`。

## 燒錄結果

使用 exact HEAD fresh build 產生的 SOF，沒有使用 historical SOF：

```text
Master cable: DE5 [1-11.1]
Configuration succeeded
Programmer checksum: 0x30AA3EE5
0 errors, 0 warnings

Slave cable: DE5 [1-11.2]
Configuration succeeded
Programmer checksum: 0x30B06A0E
0 errors, 0 warnings
```

## Step 2 / Step 3 focused regression

燒錄後等待約 60 秒，再執行：

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_wr_handshake_focused.tcl 20 500 25
```

### Master

```text
valid_samples       = 20/20
invalid_samples     = 0
counter_decreased   = 0
MODE                = 2
PTP                 = 6
PTP_TX delta        = 69
STEP2_REGRESSION    = PASS
```

Master 的 MAC、MiniNIC/PTP activity 與 `RXERR=0` 均符合 gate。

### Slave

```text
valid_samples       = 20/20
invalid_samples     = 0
counter_decreased   = 0
MODE                = 3
PTP                 = 9
FOREIGN             = 1/0
parent flags        = 1/0/1
RX WR message       = 0x1001 LOCK
TX WR message       = 0x1000 SLAVE_PRESENT
LOCK_ENABLE         = 4
RCER                = 0x00000001
RXERR               = 0
PTP_TX delta        = 12
STEP2_REGRESSION    = PASS
STEP3_REGRESSION    = PASS
```

focused script 另外回報：

```text
POST_STEP3_LOCK_STAGE = TIMEOUT
STATE_EVIDENCE        = READ_INCONSISTENT
signal_good           = 20
signal_bad            = 0
state_idle            = 20
state_good            = 0
```

因此本輪採用 repeated accepted samples 判定 Step 2 / Step 3。`WRS_IDLE` 的 current-state 欄位與其餘已通過的 handshake evidence 互相衝突，先標為 read inconsistency，不把單一 mailbox snapshot 擴大解讀成 Step 2 / Step 3 failure。

## Step 4 read-only event-chain observation

執行的 diagnostics：

```text
read_step4_event_chain.tcl 1000
read_step4_runtime_context.tcl 10 500
read_step4_dmtd_boundary.tcl 5 500
```

三個 Tcl 執行均成功，沒有 Tcl exception，也沒有寫入 runtime control register。`TRR_R0` 本身沒有被 diagnostics 讀取；只讀取 B 版本新增的 `TRR_POP` counter。

### Slave 穩定觀測

```text
RCER                 = 0x00000001
LOCK_ENABLE          = 4
SPLL_STATE           = 0x00030009
DMTD_STATE           = 0x0C000002  (REF_STATE=2, FB_STATE=0)
REF_EVENTS           = 0x05CCB775
FB_EVENTS            = 0x0646FFF7
TAG_VALID            = 0
TRR_WRITE            = 0
TRR_POP              = 0
IRQ                  = 0
HELPER_UPDATE        = 0
```

在 5 個、間隔 500 ms 的 boundary samples 中：

- `SAMPLED_REF` 與 `SAMPLED_FB` 會變化，表示 sampled transition 有活動跡象。
- `ACCEPT_REF=0x152101C1`、`ACCEPT_FB=0x16E0D28F` 在五個 Slave samples 中保持不變。
- `DMTD REF/FB event` 也沒有在這段 observation 中增加。
- `TAG_VALID`、`TRR_WRITE` 與下游 `TRR_POP` 仍為 0。

Master 也觀察到 sampled/event raw 欄位與 mailbox snapshot 可能出現跨欄位不一致；因此 raw boundary values 只作趨勢證據，不用單次跨 register snapshot 直接證明功能根因。

### 目前最前面的觀測邊界

根據 source-backed register mapping，目前最早看到的「上游有變化、下游沒有持續活動」邊界是：

```text
sampled transition -> deglitch accept
```

這只是目前最早的觀測線索，不是已證明的 root cause。現有證據尚不能區分 deglitch qualification、CDC/mailbox snapshot、DMTD 狀態條件或其他既有 functional path 問題。

## 結果與判定

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED     = YES
STEP4_RESULT      = NOT_PASS

B_NONREGRESSION   = PASS
TRR_POP_ACTIVITY   = NONE_OBSERVED
ROOT_CAUSE        = NOT_PROVEN
```

### 證據分類

- **不是 JTAG/Tcl exception：** 三個 Step 4 diagnostics 與 focused regression 都成功結束。
- **不是 Step 2/3 regression failure：** Master/Slave 都有 20/20 accepted samples，角色、PTP、Foreign Master、WR message、LOCK_ENABLE 與 counter activity 均符合 focused gate。
- **Step 4 尚未通過：** `RCER=1`、`LOCK_ENABLE=4` 與初始化狀態已存在，但從 DMTD sampled/deglitch 之後沒有觀察到 tag、TRR write、TRR pop 或 helper update 的 sustained activity。
- **目前不能宣稱硬體或 firmware 根因：** boundary log 中存在非 atomic mailbox snapshot 的可能性，且本輪只做觀測，沒有對 functional path 作 A/B 修改。

因此目前應寫成：

> B 版本已通過 Step 2 / Step 3 non-regression。Step 4 的 SoftPLL downstream event chain 尚未通過；最早的觀測阻塞點位於 sampled transition 到 deglitch accept 之間，但 root cause 尚未確定。這是 Step 4 evidence gap / functional-path blocker 的待查項，不是可直接歸因於 JTAG 讀取失敗。

## 原始證據

本次 raw logs 與 provenance 位於：

```text
docs/experiments/exp-step4-softpll-enable/raw/20260824-b-trr-pop/
```

包括：

- `exp_step4_b_firmware_build.log`
- `exp_step4_b_master_compile.log`
- `exp_step4_b_slave_compile.log`
- `exp_step4_b_master_program.log`
- `exp_step4_b_slave_program.log`
- `exp_step4_b_step23_20x500.log`
- `exp_step4_b_event_chain.log`
- `exp_step4_b_runtime_context.log`
- `exp_step4_b_dmtd_boundary_5x500.log`

## Next Step

先請 White Rabbit reviewer 複核這份 B 版本證據，再決定下一個 Step 4 單一變因。下一輪仍應保持：

1. 不修改 Master/Slave role、PTP、WR signaling、SoftPLL 演算法或 PHY。
2. 不把 `SPLL locked`、`time_valid` 當成本階段 gate。
3. 若要修改 functional path，先做 source audit，並只選一個可回溯的變因。
4. 先保留本 B 版本作為 Step 2/3 PASS、Step 4 downstream activity 未觀測到的基準。
