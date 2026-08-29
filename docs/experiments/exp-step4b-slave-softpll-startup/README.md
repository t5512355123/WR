# Step4B：Slave SoftPLL Startup

本資料夾記錄 `exp/step4b-slave-softpll-startup` 的實驗。此實驗線從
`main@5578d3c` 建立，目標是把 Step4 從「Master-owned/passive control」
改成可驗證的 Slave SoftPLL Startup gate；本輪只增加唯讀 dashboard 語義與
實驗紀錄，不修改 SoftPLL、DMTD、PI、DCO、SI5340、WR signaling、PTP、PHY
或既有 static-FSM fix。

## Step4B source path audit

實際 source path 為：

```text
Slave receives LOCK signaling
  -> vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-present.c
       wrMsgId == LOCK -> next_state = WRS_S_LOCK
  -> vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-s-lock.c
       entering WRS_S_LOCK -> WRH_OPER()->locking_enable(ppi)
  -> vendor/wrpc-sw/ppsi/arch-wrpc/wrpc-spll.c
       wrpc_spll_locking_enable()
       -> spll_init(SPLL_MODE_SLAVE, 0, SPLL_FLAG_ALIGN_PPS)
       -> spll_enable_ptracker(0, 1)
       -> calib_t24p_init()
  -> vendor/wrpc-sw/softpll/softpll_ng.c
       spll_init() -> mode/state/register initialization
       -> non-disabled sequencer / IRQ / OCER
  -> RCER/tag channel enabled
  -> sequencer leaves DISABLED
  -> DMTD accepted event -> TAG -> TRR write/pop -> IRQ -> helper update
```

主要 source evidence：

- `state-wr-present.c`：收到 `LOCK` 後進入 `WRS_S_LOCK`。
- `state-wr-s-lock.c`：進入或重試時呼叫 `locking_enable()`。
- `wrpc-spll.c`：非 GM 路徑呼叫 `spll_init(SPLL_MODE_SLAVE, ...)`。
- `softpll_ng.c`：`spll_init_count`、sequencer state visit/transition、RCER、
  OCER 與 IRQ 初始化均有 source-backed shadow。

## Dashboard semantics

`scripts/jtag/read_wb_runtime.tcl` 現在分開輸出：

```text
STEP4A_MASTER_EVENT_CHAIN
STEP4B_ALLOWED
STEP4B_RESULT
STEP4B_FIRST_INACTIVE_BOUNDARY
```

Slave Step4B 只有在同一輪 Step1、Step2、Step3 都是 `PASS` 時才會評估。若
上游不成立，結果是 `BLOCKED_BY_STEP1`、`BLOCKED_BY_STEP2` 或
`BLOCKED_BY_STEP3`，不是 SoftPLL `FAIL`。

允許評估後，Step4B startup evidence 包含：

```text
LOCK_ENABLE_COUNT
SPLL_INIT_COUNT
SPLL_MODE
SPLL_SEQ_STATE
SPLL_ALIGN_STATE
SPLL_STATE_VISIT_MASK
SPLL_STATE_TRANSITIONS
SPLL_LAST_STATE
RCER / OCER / OCCR
```

完整 Step4B PASS 還需要固定觀測窗內的：

```text
DMTD accepted / TAG / TRR write / TRR pop / IRQ / helper update > 0
BOOT_GENERATION / CPU_RESET_COUNT / WR_CORE_RESET_COUNT /
SI_CONFIG_DROP_COUNT 的 delta 全部為 0
```

`PSTAT.locked`、helper/main lock、convergence 與 300 秒穩定性屬於 Step5，
不列入 Step4B startup PASS gate。

## 實驗執行

正式實驗名稱：

```text
EXP-WRPC-STEP4B-SLAVE-SOFTPLL-STARTUP-BASELINE-20260829
```

執行順序：

1. laptop push 本 branch。
2. pain pull branch，fresh build Master/Slave，Quartus full compile。
3. pain fresh-program 兩張 DE5a，先以重複 Step1/2/3 觀測確認 upstream。
4. 執行 `read_wb_runtime.tcl --raw` 與 Step4B focused read-only capture。
5. 將 build/program/JTAG raw evidence 回存本資料夾，更新實驗報告並 push。

若 Step1–3 未建立，停止 Step4B functional interpretation，記錄 upstream
blocker，下一輪由分支4決定是否修正或改做上游實驗。

