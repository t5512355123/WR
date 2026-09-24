# EXP-WRPC-STEP4-PRE-ACCEPT-READONLY-20260825

## 實驗名稱

Step 4 qualification pre-accept 唯讀回讀確認

## 實驗日期

2026-08-25

## Git 與硬體來源

- GitHub repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Git commit：`0ee3cba2b5cf6dcb1310d9c7716b85cbc88609dd`
- 本次修改：只在 `scripts/jtag/read_step4_startup_focused.tcl` 增加 `STEP4_PRE_ACCEPT` 唯讀輸出別名。
- FPGA RTL、firmware、MIF、register address、SoftPLL、PHY 與任何功能行為：未修改。
- 本次沒有 Quartus compile，也沒有 program FPGA。
- 讀值使用當前已載入、前一輪由 fresh HEAD `b040d1bc98843a1175ac32767a6b05ff944a1887` 產生的雙板 SOF。

## 為了驗證什麼

確認 Step 4 的第一個 qualification 邊界是否真的有通過，並把「pre-accept」對應到既有、由 source 定義的 `WAIT_STABLE_0 -> WAIT_EDGE` predicate counter。

這次不新增 RTL probe，也不改變 state machine。`STEP4_PRE_ACCEPT` 只是重複讀取原本的：

- `DMTD_REF_WAIT_EDGE_ENTRY`：Wishbone `0x001002A0`
- `DMTD_FB_WAIT_EDGE_ENTRY`：Wishbone `0x001002A4`

source 中的功能條件是 `state = WAIT_STABLE_0` 且 `stab_cntr = deglitch_threshold` 時進入 `WAIT_EDGE`，既有 debug counter 正是依照相同條件累加。

## 執行方式

```text
/mnt/ds1515/opt/intelFPGA/17.0/quartus/bin/quartus_stp \
  -t /home/b10504072/04_WR/scripts/jtag/read_step4_startup_focused.tcl \
  50 100 events
```

- observation samples：50
- sample interval：100 ms
- read mode：read-only
- retries：5
- 原始輸出：`raw/20260825_pre_accept_audit/events.log`
- 原始 log SHA256：`1879ef17c4420ef94d6365ac72044682e4fe70ce4df440daa33afbc789bb025f`

## 實驗結果

Quartus 17.0 SignalTap/Tcl 執行成功：

```text
Info (23030): Evaluation of Tcl script ... was successful
Info: Quartus Prime SignalTap II was successful. 0 errors, 0 warnings
```

兩片 FPGA 均為 50/50 valid samples、0 timeout、0 invalid。關鍵結果如下：

```text
DE5 [1-11.1]
  DMTD native sampled/transition counters: delta > 0
  DMTD_REF_WAIT_EDGE_ENTRY: delta=0
  DMTD_FB_WAIT_EDGE_ENTRY:  delta=0
  DMTD_REF_GOT_EDGE_ENTRY:  delta=0
  DMTD_FB_GOT_EDGE_ENTRY:   delta=0
  DMTD_REF_ACCEPT:          delta=0
  DMTD_FB_ACCEPT:           delta=0
  STEP4_PRE_ACCEPT:         ref=0 fb=0
  TAG/TRR/IRQ/helper/state-transition: delta=0

DE5 [1-11.2]
  DMTD native sampled/transition counters: delta > 0
  DMTD_REF_WAIT_EDGE_ENTRY: delta=0
  DMTD_FB_WAIT_EDGE_ENTRY:  delta=0
  DMTD_REF_GOT_EDGE_ENTRY:  delta=0
  DMTD_FB_GOT_EDGE_ENTRY:   delta=0
  DMTD_REF_ACCEPT:           delta=0
  DMTD_FB_ACCEPT:            delta=0
  STEP4_PRE_ACCEPT:          ref=0 fb=0
  TAG/TRR/IRQ/helper/state-transition: delta=0
```

## 如何看待結果

1. `native sampled/transition` 持續增加，表示兩板的 DMTD 輸入與取樣活動不是完全停止。
2. `WAIT_EDGE_ENTRY`、`GOT_EDGE_ENTRY`、`ACCEPT` 及其後的 TAG/TRR/IRQ/helper counter 在 5 秒觀察窗內都沒有增加，表示本次觀察沒有取得 qualification completion 或 accept event。
3. 這支持「目前停在 DMTD qualification boundary 之前或尚未通過 qualification」的觀察。
4. 這不能單獨證明是 DMTD polarity、deglitch threshold、時鐘品質或 SoftPLL 演算法的根因；目前仍應標示 `STATE_EVIDENCE=READ_INCONSISTENT`、`ROOT_CAUSE=NOT_PROVEN`。
5. 因為本次只修改 Tcl 顯示並且沒有重新燒錄，所以不會用這份結果宣稱新的 functional image 成功或失敗。

## 回歸狀態

- `STEP1_REGRESSION = PASS`：沿用同一 fresh HEAD image 的前一輪 accepted evidence。
- `STEP2_REGRESSION = PASS`：沿用 focused repeated sampling；Master/Slave PTP traffic、MiniNIC traffic 與 identity 均通過。
- `STEP3_REGRESSION = PASS`：沿用 focused repeated sampling；Slave foreign master、parent metadata、`SLAVE_PRESENT`、`LOCK` 與 `LOCK_ENABLE=4` 均通過；單一 current-state 讀值仍標為 inconsistent。
- `STEP4_REGRESSION = NOT_PASS`：本次 50 samples 未觀察到 pre-accept/accept 或 downstream activity。
- `STEP4_ALLOWED = YES`：Step 2/3 regression barrier 已通過，因此仍允許進行下一個 Step 4 read-only source/runtime audit；這不等於 Step 4 已通過。

## 下一步

先維持「一次一個變因、read-only 優先」原則。下一輪應由 reviewer 針對既有 `WAIT_STABLE_0 -> WAIT_EDGE` predicate、`clk_sampled`/deglitch input 與 qualification counter 的 source/runtime 對照提出下一個最小診斷；在取得明確證據前，不修改 SoftPLL、DDMTD polarity、PI gain、lock threshold、DCO 或 SI5340。
