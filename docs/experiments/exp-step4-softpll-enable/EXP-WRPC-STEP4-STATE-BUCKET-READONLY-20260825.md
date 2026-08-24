# EXP-WRPC-STEP4-STATE-BUCKET-READONLY-20260825

## 實驗名稱

Step 4 `WAIT_STABLE_0` state-gated stability bucket 唯讀觀察

## 實驗日期

2026-08-25

## Git 與限制

- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Git commit：`17f44104b5a547511761f4b00eab5540c35d6dab`
- 本次只修改 `scripts/jtag/read_step4_startup_focused.tcl`。
- 沒有修改任何 RTL、firmware、MIF、SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO、SI5340、PHY 或 Wishbone write 行為。
- 沒有 Quartus compile，也沒有 program FPGA。

## 為了驗證什麼

Reviewer 建議直接觀察 functional `WAIT_STABLE_0` 期間 `stab_cntr` 的最大值。source audit 發現完整 `dbg_stab_count_o` 雖由 `dmtd_with_deglitcher` 產生並同步到 `wr_softpll_ng`，但目前沒有被接到 Wishbone read map，因此在本輪禁止改 RTL 的條件下不能取得完整 counter。

本次改用既有的 `SPLL_DMTD_STATE` read-only packed snapshot：

- REF state：bits `[1:0]`
- FB state：bits `[3:2]`
- REF stability bucket：bits `[17:10]`
- FB stability bucket：bits `[25:18]`
- register：`0x001002DC`

Tcl 只在 snapshot 顯示 `WAIT_STABLE_0` 時，記錄該 bucket 的最大值與 sample count。這是**取樣的 coarse proxy**，不是完整 `stab_cntr` 最大值，也不會影響硬體。

## 執行設定

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step4_startup_focused.tcl \
  50 100 events
```

- samples：50
- sample gap：100 ms
- observation：約 12 秒含 JTAG mailbox overhead
- retries：5
- read-only：是
- pain exact checkout：`17f44104b5a547511761f4b00eab5540c35d6dab`
- raw log：`raw/20260825_state_bucket_audit/events.log`
- raw log SHA256：`1b11dcaefcd861579e79d72af4c691261d89c0b970545bbf337ad76f18cee3c9`

## 原始結果

Quartus 17 SignalTap/Tcl 正常完成：

```text
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

兩板其餘 Step 4 boundary counters 都是 50/50 valid、0 timeout、0 invalid。關鍵 state-gated coarse proxy：

```text
DE5 [1-11.1]
  ref_state=WAIT_STABLE_0 snapshots : 49
  ref bucket maximum                : 0
  fb_state=WAIT_STABLE_0 snapshots  : 0
  fb bucket maximum                 : 0

DE5 [1-11.2]
  ref_state=WAIT_STABLE_0 snapshots : 0
  ref bucket maximum                : 0
  fb_state=WAIT_STABLE_0 snapshots  : 50
  fb bucket maximum                 : 0
```

同一個 observation window：

```text
DEGLITCH_THRESHOLD       = 1000
REF/FB WAIT_EDGE_ENTRY   = 0
REF/FB GOT_EDGE_ENTRY    = 0
REF/FB ACCEPT            = 0
TAG/TRR/IRQ/helper/state = all delta=0
native sampled activity  = delta > 0
```

## 判讀

1. 在每 100 ms 的 JTAG snapshots 中，只要板卡被觀察到處於 `WAIT_STABLE_0`，其 stability bucket 都是 0；這表示觀測到的 `stab_cntr[17:10]` 沒有進入 1 以上的區間。
2. 由於 bucket 只保留高位、且 JTAG snapshot 不是逐 DMTD cycle 取樣，這不能證明完整 `stab_cntr` 在所有時間都小於 256，也不能證明它從未短暫接近 threshold=1000。
3. 這個結果與 `WAIT_EDGE_ENTRY=0` 的證據方向一致，但仍不足以區分輸入低電位 run、`clk_sampled` 轉換、counter reset timing 或跨 clock readout semantics。
4. 因此 Step 4 仍不能標示 PASS，也不能把 threshold、DDMTD polarity、clock quality、timing 或 FSM 宣稱為根因。

## 回歸狀態

- `STEP1_REGRESSION = PASS`
- `STEP2_REGRESSION = PASS`
- `STEP3_REGRESSION = PASS`
- `STEP4_REGRESSION = NOT_PASS`
- `STEP4_ALLOWED = YES`
- `STATE_EVIDENCE = READ_INCONSISTENT`
- `ROOT_CAUSE = NOT_PROVEN`
- `HARDWARE/FIRMWARE_FAILURE = NOT_PROVEN`
- `JTAG/DASHBOARD_MEASUREMENT_FAILURE = coarse bucket limitation documented`

本次沒有燒錄，所以這不是新的硬體 milestone；它是對目前已載入 fresh image 的 read-only 診斷補充。

## 下一步

如果仍禁止修改 RTL，現有 Wishbone/JTAG 只能提供這個 coarse proxy，不能取得精確的 state-gated `stab_cntr` max。要回答 reviewer 的精確問題，下一個必要變更是新增一個**純 read-only、state-gated 的 diagnostic counter 並重新 build/program**；在取得明確授權前，本分支不會自行修改該 functional tree。SoftPLL、DDMTD polarity、PI、lock threshold、DCO、SI5340 與 PHY 仍全部保持不變。
