# EXP-WRPC-STEP4B-SLAVE-SOFTPLL-STARTUP-BASELINE-20260829

## 實驗設定

- 實驗名稱：Step4B Slave SoftPLL Startup baseline
- 日期：2026-08-29
- 工作 branch：`exp/step4b-slave-softpll-startup`
- 基準 source：`main@5578d3ce06461cc9c598e6bf97b890bf440a70b8`
- 實驗類型：`READ-ONLY BASELINE / SEMANTIC CORRECTION`
- 目的：驗證 Slave 是否由 WR `LOCK` 路徑進入 `spll_init(SPLL_MODE_SLAVE)`，
  並在無 reset/re-entry 的固定窗口內完成 Step4B event processing。

## 本輪範圍與禁止事項

本輪唯一程式變更是 `scripts/jtag/read_wb_runtime.tcl` 的唯讀觀測與
Step4A/Step4B machine-readable gate。不得修改：

- SoftPLL、DMTD /2、polarity、PI、lock threshold、DCO、SI5340
- static FSM one-line fix
- WR signaling、PTP、PHY、shell/task scheduling、reset tree

## Acceptance gate

### Upstream prerequisite

只有 Slave 的 Step1、Step2、Step3 都建立後，才可令：

```text
STEP4B_ALLOWED = YES
```

否則必須輸出 upstream blocker，例如：

```text
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP3
STEP4B_FIRST_INACTIVE_BOUNDARY = UPSTREAM_PREREQUISITE
```

### Startup

```text
LOCK_ENABLE_COUNT > 0
SPLL_INIT_COUNT > 0
SPLL_MODE = 3 (SPLL_MODE_SLAVE)
SPLL_SEQ_STATE != 0 and != 7
SPLL_STATE_VISIT_MASK > 0
RCER > 0
OCER > 0
```

### Downstream event processing

同一 before/after window 必須全部 `delta > 0`：

```text
DMTD_ACCEPT
TAG_VALID
TRR_WRITE
TRR_POP
IRQ
HELPER_UPDATE
```

並且以下 reset/re-entry delta 必須全部為 0：

```text
BOOT_GENERATION
CPU_RESET_COUNT
WR_CORE_RESET_COUNT
SI_CONFIG_DROP_COUNT
```

### Classification

完整通過才可寫：

```text
STEP4B_RESULT = PASS
```

若 startup 已證明但下游未證明，寫：

```text
STEP4B_RESULT = STARTUP_PROVEN_EVENT_PROCESSING_NOT_PROVEN
```

若 upstream 未建立，寫 `BLOCKED_BY_STEP1/2/3`，不稱為 Step4B FAIL。

## Source audit

```text
state-wr-present.c:
  LOCK -> WRS_S_LOCK

state-wr-s-lock.c:
  WRS_S_LOCK entry/retry -> WRH_OPER()->locking_enable(ppi)

wrpc-spll.c:
  wrpc_spll_locking_enable()
  -> spll_init(SPLL_MODE_SLAVE, 0, SPLL_FLAG_ALIGN_PPS)
  -> spll_enable_ptracker(0, 1)
  -> calib_t24p_init()

softpll_ng.c:
  spll_init_count++
  mode = SLAVE
  non-disabled sequencer initialization
  RCER/OCER and IRQ enable path
```

## Build / program / observation evidence

本節在 pain 完成 fresh build、fresh-program 與 JTAG 觀測後補寫。所有
checksum、Quartus timing 摘要、program log、Step1/2/3 focused log、
`read_wb_runtime.tcl --raw` 與 focused Step4B raw output 必須綁定同一 source
commit、同一 branch、同一批 Master/Slave SOF。

### Build provenance

- pain checkout commit：`8c3297916db8bd8250afb047f71f40e2fa38f56a`
- Quartus：17.0.0 Build 595 / Standard Edition
- Master MIF SHA256：`72eba5273720b26ab81590d254c074906b085416aadf3bbffd0ab3f82d9c3e9b`
- Master SOF SHA256：`1e62e29121ab4b91eca8f98354ec54abb71d4d2aefb30b8485750d8f3851cbed`
- Slave MIF SHA256：`40a9e9fa628cfaec222238f3a34b04d2570246ccaa62a2fa1b71fb534c2f82d6`
- Slave SOF SHA256：`562a6273adc54df4f0af83414762bf9306854c740a86e4cb301a9af211c9935f`
- Master / Slave full compile：成功；timing closed：`NO`
- Worst setup slack：Master `-0.177 ns`；Slave `-0.272 ns`
- unconstrained clocks / input / output：Master `6/971/83`；Slave `6/969/82`

完整 build provenance：`build/build_info_jtag_master.txt`、
`build/build_info_jtag_slave.txt`。

### Program result

兩張 DE5a 均以正確的 `quartus/jtag_runtime_diag` mailbox 映像 fresh-program
成功，JTAG ID 均為 `0x02E660DD`，0 errors / 0 warnings：

- Master cable `DE5 [1-11.1]`：checksum `0x30B00EC4`
- Slave cable `DE5 [1-11.2]`：checksum `0x30B7AD8B`

先前曾誤燒 `quartus/rs422_uart_diag`；該 top-level 沒有 JTAG Wishbone mailbox，
所以當時的 Step2/3 timeout/invalid 只記為
`WRONG_IMAGE_MEASUREMENT_INVALID`，不納入本輪判定。

### Step1 / Step2 / Step3

正確 mailbox 映像的最終 `read_wb_runtime.tcl --raw`：

- Master `DE5 [1-11.1]`：Step1 PASS；MAC `...:01`；`WDIAGS_MODE=3`、
  PTP raw `0x00002104`（state 4, LISTENING），不符合 Master 預期 `2/6`。
- Slave `DE5 [1-11.2]`：Step1 PASS；MAC `...:02`；`WDIAGS_MODE=3`、
  PTP raw `0x00004104`（state 4, LISTENING），不符合 Slave 預期 state `9`。

focused Step2 regression 使用 20 samples、500 ms gap，所有 endpoint/PTP/
packet counters 均 valid 20/20：

- Master：`STEP2_INDEPENDENT = FAIL`；MODE `03020404`、PTP `00002104` 維持不變。
- Slave：`STEP2_INDEPENDENT = FAIL`；MODE `03020404`、PTP `00004104` 維持不變。

因此這不是單一 snapshot 抖動；Slave 尚未建立 Step2/3 upstream。沒有再做
SoftPLL、WR signaling 或 PTP functional 修改。

### Step4A / Step4B raw result

```text
STEP4A_RESULT = FAIL
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP2
STEP4B_FIRST_INACTIVE_BOUNDARY = UPSTREAM_PREREQUISITE
```

Master 的 DMTD REF/FB accepted counters 在窗口內增加，但 TAG、TRR write/pop、
IRQ、helper 都是 `delta=0`，因此 Step4A 也未形成完整 event chain。

Slave 的 startup counters 為：

```text
LOCK_ENABLE_COUNT = 0
SPLL_INIT_COUNT = 0
SPLL_MODE = 0
SPLL_SEQ_STATE = 0
SPLL_STATE_VISIT_MASK = 0
SPLL_STATE_TRANSITIONS = 0
SPLL_LAST_STATE = 7 (WRS_RESP_CALIB_REQ shadow)
RCER = 0
TAG/TRR/IRQ/HELPER = 0
```

由於 Step1/2/3 gate 未全數成立，這些數值只作 upstream-blocked context，
不宣告為 Step4B startup FAIL。

Raw evidence：

- `raw/read-wb-runtime-jtag-final-raw.log`
- `raw/step23-jtag-final-step2-raw.log`
- `raw/read-wb-runtime-jtag-ptpfield-raw.log`
- `raw/read-wb-runtime-jtag-routed-raw.log`

## 結果

`BLOCKED_UPSTREAM / NOT_PASS`。

本輪已完成 fresh build、fresh-program 與正確 mailbox 的重複觀測，但未達成
Step4B acceptance gate，因此 Step4B 不是 PASS，也沒有 merge 到 main。

## 結論

Step4B 尚未通過。依分支4規則，必須先解決 Slave 的 Step2/3 upstream，重新
建立 `LOCK -> WRS_S_LOCK -> locking_enable() -> spll_init(SLAVE)`，再談
Step4B startup/event processing；本輪不得詢問 merge 或合併到 main。

## 下一步

已依使用者指定流程完成 pain pull、compile、燒錄、觀測與本地紀錄；下一步
交由分支4審核上游 blocker。
