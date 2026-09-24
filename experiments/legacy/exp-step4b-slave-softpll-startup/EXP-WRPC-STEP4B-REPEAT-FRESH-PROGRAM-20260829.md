# EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829

## 實驗目的

在已修正 reader semantics 的 `266703a` 上，重新執行一次完整的
Step4B fresh-program reproducibility validation。此輪不新增功能修改，
只重新編譯、燒錄兩張 DE5a，並以 focused Step2 與完整 runtime dashboard
觀測 Slave SoftPLL startup。

## Provenance

- pain source commit：`266703a89917b5d73ef74baa3658baba46c4ac7f`
- branch：`exp/step4b-slave-softpll-startup`
- Quartus：17.0.0 Build 595 / Standard Edition
- Master/Slave full compile：successful
- timing closed：`NO`
- Master WNS：`-0.177 ns`
- Slave WNS：`-0.272 ns`
- Master MIF SHA256：`fe2398e7d1be2ff762e321a0b0cd74a62a6caf501550892b36fed47e20da5954`
- Slave MIF SHA256：`a671a1dd1bce53546421eb336203d43c0c5b31058c3b00e532c9b2bd9ab73ab1`
- Master SOF SHA256：`94244a9e713c519a73c5f42419b24f75efb5f19e706445d76baebc9ac981fefb`
- Slave SOF SHA256：`83a6ae959722194eeb2355e93215eb8d3858eaf59bcf2a64b991cf12346ec54e`
- Master programmer checksum：`0x30B00EC4`
- Slave programmer checksum：`0x30B7AD8B`
- 兩張 DE5a 的 JTAG ID：`0x02E660DD`
- Master/Slave programming：0 errors / 0 warnings

## Focused Step2 regression

`read_step23_register_reliability.tcl 20 500 step2 25 --raw`：

```text
STEP2_INDEPENDENT board=DE5 [1-11.1] result=PASS
STEP2_INDEPENDENT board=DE5 [1-11.2] result=PASS
```

兩板的 endpoint/MAC、mode、PTP state、PTP activity、MiniNIC activity 均
有效，RXERR 維持 0。

## Runtime dashboard

```text
Master Step1 = PASS
Master Step2 = PASS
Master Step4A = PASS

Slave Step1 = PASS
Slave Step2 = PASS
Slave Step3 = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

## Slave Step4B acceptance evidence

### Startup

```text
LOCK_ENABLE_COUNT = 4
SPLL_MODE = 3 (SPLL_MODE_SLAVE)
SPLL_SEQ_STATE = 4 (SEQ_WAIT_HELPER)
SPLL_ALIGN_STATE = 0
SPLL_STATE_VISIT_MASK = 0x00000618
SPLL_INIT_COUNT = 4
SPLL_STATE_TRANSITIONS = 0x00000003
SPLL_LAST_STATE = 4 (SEQ_WAIT_HELPER)
RCER = 0x00000001
OCER = 0x8F51B201 (functional OCER[7:0] = 0x01)
```

這證明 Slave 在 Step1/2/3 成立後執行了 `locking_enable()`、進入
`SPLL_MODE_SLAVE`，且 SoftPLL sequencer 已離開 disabled/reset。

### Fixed observation window event processing

```text
ΔDMTD_ACCEPT = 43559
ΔTAG_VALID = 43560
ΔTRR_WRITE = 43559
ΔTRR_POP = 40284
ΔIRQ = 39546
ΔHELPER_UPDATE = 20284
```

六個 downstream event counters 全部大於零，第一個 inactive boundary 為
`ACTIVE`。

### Reset/re-entry guard

```text
ΔBOOT_GENERATION = 0
ΔCPU_RESET_COUNT = 0
ΔWR_CORE_RESET_COUNT = 0
ΔSI_CONFIG_DROP_COUNT = 0
```

觀測窗內沒有 reset 或 re-entry。

## 判定

第二次 fresh-program 實驗再次得到：

```text
STEP4B_SLAVE_SOFTPLL_STARTUP = PASS
```

這個判定涵蓋 Step4B 的 upstream prerequisite、Slave SoftPLL startup 與
event processing；不要求 Step5 的 `PSTAT.locked`、helper/main lock 或
frequency/phase convergence。此輪 dashboard 的 Step5 `PSTAT.locked=0`
仍屬下一階段，不否定 Step4B。

## Post-sync rerun：啟動時間序列確認

為釐清 pain 端看見的 `SoftPLL Startup error`，在同步到 repo 最新
`8a8b5f5` 後重新 full compile、燒錄兩張板，並在同一組 image 上重跑
dashboard。兩張板 programming 均為 0 errors / 0 warnings。

重新燒錄後立即取樣時，Slave 的 `WDIAGS_PTP=8 UNCALIBRATED`，因此：

```text
STEP2_REGRESSION = INVALID
STEP4B_ALLOWED = NO
STEP4B_RESULT = BLOCKED_BY_STEP2
```

這是 upstream PTP 尚未完成校準時的合法 gate 結果，不是 SoftPLL startup
failure。等待 30 秒後重跑，同一張 Slave image 得到：

```text
WDIAGS_PTP = 9 SLAVE
Step 1 pass
Step 2 pass
Step 3 pass
LOCK_ENABLE_COUNT = 4
SPLL_MODE = 3 (SPLL_MODE_SLAVE)
SPLL_SEQ_STATE = 4 (SEQ_WAIT_HELPER)
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
```

這次延遲重跑再次確認原本的 Step4B PASS；畫面中的 error 是取樣時機
造成的 upstream `UNCALIBRATED`，不是最新 image 或 Step4B 程式失效。

## Raw evidence

- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/dashboard-raw.log`
- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/step23-jtag-step2-raw.log`
- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/program-jtag-master.log`
- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/program-jtag-slave.log`
- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/build-jtag-master.log`
- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/build-jtag-slave.log`
- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/build_info_jtag_master.txt`
- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/build_info_jtag_slave.txt`
- `raw/EXP-WRPC-STEP4B-REPEAT-FRESH-PROGRAM-20260829/dashboard-after-sync-wait-20260829.log`

本輪結果支持 Step4B PASS 的可重複性確認，下一步應詢問分支4是否明確
同意將本 branch merge 到 `main`。
