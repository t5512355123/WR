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

- pain checkout commit：待補
- Quartus：17.0.0 Build 595 / Standard Edition
- Master MIF / SOF SHA256：待補
- Slave MIF / SOF SHA256：待補
- Master / Slave timing closed：待補

### Program result

待 fresh-program；預期各板為 `Configuration succeeded`，但以實際 log 為準。

### Step1 / Step2 / Step3

待完成重複 read-only regression；若 upstream 未成立，本實驗在此停止
Step4B 判定並記錄 blocker。

### Step4A / Step4B raw result

```text
STEP4A_RESULT = 待補
STEP4B_ALLOWED = 待補
STEP4B_RESULT = 待補
STEP4B_FIRST_INACTIVE_BOUNDARY = 待補
```

## 結果

`INCONCLUSIVE`（尚未完成 pain fresh build/program/觀測）。

## 結論

尚未對 Step4B 作 PASS 宣告。只有 fresh program 至少重複一次、完整
Step4B evidence 成立後，才可詢問分支4是否同意 merge 到 main。

## 下一步

依使用者指定流程完成 pain pull、compile、燒錄、觀測、紀錄 push，然後把
最新實驗紀錄交給分支4審核。

