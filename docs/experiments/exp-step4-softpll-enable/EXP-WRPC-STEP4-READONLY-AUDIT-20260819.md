# EXP-WRPC-STEP4-READONLY-AUDIT-20260819

## 實驗基本資料

- 實驗名稱：Step 4 SoftPLL Enable 唯讀稽核與第一個 blocker 定位
- 日期：2026-08-19
- Git branch：`exp/step4-softpll-enable`
- branch HEAD：`b7d262b5321d0d273c36b6aeb6a8fc57d76ea82e`
- 目的：確認 Slave 進入 `WRS_S_LOCK` 後，SoftPLL 是否真的被啟用並開始工作；本輪不以 `PSTAT.locked=1` 作為 Step 4 gate
- 變因：無。沒有修改任何 functional source、韌體、RTL、PTP algorithm、SoftPLL algorithm、PHY 或 SI5340 DCO control
- 實驗類型：read-only source/runtime audit；沒有重新 compile、沒有燒錄 FPGA

## Step 4 與 Step 5 的界線

本輪只回答「SoftPLL 有沒有開始工作」：

```text
Step 4：channel enable、sequence 活動、DDMTD/tag/TRR、servo、correction/DCO request 開始工作
Step 5：上述閉迴路是否收斂，並得到 PSTAT.locked=1 / spll_locked=1
```

因此本輪不修改 PI gain、lock threshold、DDMTD polarity、DCO gain 或 SI5340 演算法，也不把 `spll_locked=0` 直接解讀成「SoftPLL 沒有 enable」。

## Source audit

目前 branch 的 source chain 如下：

1. `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/state-wr-s-lock.c:19-29,46-48`
   - 新進入 `WRS_S_LOCK` 時設 `enable=1`。
   - `enable` 時呼叫 `WRH_OPER()->locking_enable(ppi)`。
2. `vendor/wrpc-sw/ppsi/arch-wrpc/wrpc-spll.c:19-30`
   - `wrpc_spll_locking_enable()` 增加 enable counter。
   - Slave 執行 `spll_init(SPLL_MODE_SLAVE, 0, SPLL_FLAG_ALIGN_PPS)`。
   - 啟用 `spll_enable_ptracker(0, 1)`。
3. `vendor/wrpc-sw/softpll/softpll_ng.c:324-430`
   - 非 disabled mode 從 `SEQ_CLEAR_DACS` 開始。
   - Slave helper reference 使用 channel 0。
   - 清空 tag buffer 後啟用 SoftPLL interrupt 與 output channel。
4. `vendor/wrpc-sw/softpll/softpll_ng.c:181-224`
   - `SEQ_START_HELPER` 呼叫 `helper_start()`，接著進入 `SEQ_WAIT_HELPER`。
   - 只有 `helper.ld.locked && helper.ld.lock_changed` 成立時，Slave 才會進 `SEQ_START_MAIN`。
5. `vendor/wrpc-sw/softpll/softpll_ng.c:250-269`
   - `helper_update()` 每次 tag 先執行。
   - 只有 helper locked 後，才執行 `mpll_update()` 與後續 main/aux loop。
6. `vendor/wrpc-sw/softpll/softpll_export.h:33-42`
   - `SEQ_WAIT_HELPER=4`、`SEQ_START_MAIN=5`、`SEQ_WAIT_MAIN=6`、`SEQ_READY=8`。
7. `vendor/wrpc-sw/lib/task-diags.c:151-198`
   - JTAG diagnostics 提供 WR lock、SoftPLL hardware shadow、helper/main lock bits、activity counters、state transition、IRQ、tag-valid 與 TRR-write counters。

## Runtime provenance

本輪為唯讀觀察，沒有產生新的 MIF/SOF，也沒有 programmer log。遠端觀察使用既有 Step 3 fresh image：

- 遠端 checkout：`/home/b10504072/04_WR_step3_head`
- 遠端 branch：`exp/step3-wr-handshake`
- runtime source checkout HEAD：`fb8c926cfe37b82e86300117181a6ac01e1889e2`
- 功能性目錄 `firmware`、`quartus/jtag_runtime_diag`、`vendor/wrpc-sw`、`vendor/wr-cores`、`scripts/build`、`scripts/jtag`：`fb8c926..b7d262b` 無差異
- Quartus：17.0 Build 595（SignalTap script evaluation successful，0 errors，0 warnings）

這些 runtime 證據可以支持 source-compatible Step 4 blocker 定位，但不能取代「最新 Step 4 HEAD → fresh firmware → clean Quartus → fresh SOF → programming」的正式驗證。

## JTAG 原始證據

遠端 artifact 目錄：
`/home/b10504072/04_WR_step3_head/build/artifacts/EXP-WRPC-STEP4-READONLY-20260819/`

| 原始資料 | SHA256 |
|---|---|
| `runtime_snapshot.log` | `4f58e07954ff224eed0c233dec17f7cdf0addd849afe3f9adccda69d0fb8acaa` |
| `runtime_timeseries_30s.log` | `28a8f753a365bf7c8389a63ad29faab2d18b591a4f02c550398ffc60ecc2deff` |
| `runtime_spll_raw_1s.log` | `4735022d73aa0db6c2bd702158c95fe0090f4f2a169b9026ea143e2cf85d012b` |
| `runtime_dco_activity_1s.log` | `161f003f7ae0234f8416328c68ae0f865561fecd1fe2cc067ab256bc8aace298` |

### 1 秒 SoftPLL raw observation

Slave `DE5 [1-11.2]`：

```text
RAW_CORE: SSTAT=00000001 PSTAT=00000001
RAW_LOCK: RESULT=00000001 UNLOCKED=000D7C7C HELPER=00010000 MAIN=00000000
RAW_HW: RCER=00000001 OCER=02385801 TRR_CSR=023A58DE
RAW_COUNTER: TAG_VALID=027A5A39 TRR_WRITE=027A5A94 TAG_SOURCE=08F241AF REF=0479741A FEEDBACK=04B7F11A
SHADOW_COUNTER: REF=013B645B TAG=0133B9C4 TAG_VALID=027A3AFD TRR_WRITE=027A3AFD
RAW_STATE: VISIT=00000618 TRANSITIONS=00000003 LAST_STATE=00000004
```

一秒後：

```text
RAW_CORE: SSTAT=00000001 PSTAT=00000001
RAW_LOCK: RESULT=00000001 UNLOCKED=000D7C7C HELPER=00010000 MAIN=00000000
RAW_HW: RCER=00000001 OCER=0238A001 TRR_CSR=023AA0CC
RAW_COUNTER: TAG_VALID=027AA228 TRR_WRITE=027AA284 TAG_SOURCE=08F2899F REF=04799884 FEEDBACK=04B814A3
SHADOW_COUNTER: REF=013B8462 TAG=0133D904 TAG_VALID=027A7A44 TRR_WRITE=027A7A44
RAW_STATE: VISIT=00000618 TRANSITIONS=00000003 LAST_STATE=00000004
```

判讀：`RCER=1` 且 tag/TRR/ref/feedback counters 增加，證明 reference tag 與 SoftPLL interrupt path 有活動；`LAST_STATE=4` 對應 `SEQ_WAIT_HELPER`。`HELPER=00010000` 表示 helper `locked=0`、`lock_changed=0`、`ref_src=0`、lock count 為 1；`MAIN=00000000` 表示 main MPLL 尚未 enabled。

### 30 秒同一 JTAG session

30 秒 time-series 中，Slave 維持：

- `PTP=9`、`FOREIGN_META=03000001`、`WRS_S_LOCK`
- `WR_LOCK enable=4`、polls 持續增加
- `RCER=1`
- `REF_COUNT`、`TAG_COUNT`、`IRQ_COUNT` 持續增加
- `TAG_VALID_COUNT`、`TRR_WRITE_COUNT` 持續增加
- `VISIT_MASK=00000618`、`TRANSITIONS=3`、`LAST_STATE=4`
- helper error 多次為 `0x249F0 = 150000` clamp，helper output 有活動但不收斂
- helper locked 仍為 0，main shadow 仍為 0

### DCO probe

Slave：

```text
DCO_ACTIVITY A=FF6800000008ABA2 B=FF6800000008ABA2
```

一秒內 A 與 B 相同，這只能證明本次觀察窗口沒有看到 direct DCO activity 變化；尚不能單獨證明 SI5340 或 I2C 的根因。Master 沒有對應的 In-System Sources and Probes instance。

## Acceptance table

| Step 4 檢查點 | 結果 | 證據 |
|---|---|---|
| `WRS_S_LOCK` 呼叫 `locking_enable()` | PASS | `WR_LOCK enable=4`；source `state-wr-s-lock.c:46-48` |
| Slave SoftPLL mode/channel enable | PASS | `mode=3`、`RCER=1`、output/tagger/ptracker activity |
| sequence 離開 disabled/idle | PASS | `LAST_STATE=4 = SEQ_WAIT_HELPER` |
| DDMTD/tag/TRR/IRQ activity | PASS | counters 在 1 秒與 30 秒 window 持續增加 |
| helper update activity | PASS（未 lock） | REF/TAG/IRQ、helper output 有活動；error 長期 clamp |
| helper lock detector | FAIL | `locked=0`、`lock_changed=0`、lock count=1 |
| main MPLL / main correction | BLOCKED | `MAIN=00000000`；source 只有 helper locked 才進 `mpll_update()` |
| external DCO request activity | NOT OBSERVED | DCO A/B 一秒相同 |
| Step 4 overall | **NOT PASS；已定位第一 blocker** | helper reference tracking / lock detector 未成立 |

## 結論

本輪可以明確排除「SoftPLL channel 根本沒有 enable」：`locking_enable()` 已被呼叫、Slave mode 已建立、channel 0 的 tag/TRR/IRQ/ref path 持續活動，sequence 也已進入 `SEQ_WAIT_HELPER`。

Step 4 的第一個 blocker 是：

> **helper tracking loop 已啟動，但 helper lock detector 沒有成立；helper error 長期飽和在 `+150000`，所以 sequence 無法從 `SEQ_WAIT_HELPER` 前進到 `SEQ_START_MAIN`。**

因此：

- `SoftPLL_ENABLE = PASS`
- `helper lock / main correction = NOT PASS`
- `Step 4 overall = NOT PASS，第一 blocker 已定位`
- `PSTAT.locked=1`、`spll_locked=1` 與閉迴路收斂仍屬 Step 5，本輪沒有用它們作為 Step 4 的 enable 判準

目前證據尚不足以判斷根因是在 raw tag step、helper reference tracking，或 actuator/DCO handshake。下一輪應先做同一時間軸的 read-only correlation：`ref_src=0 raw tag delta → expected delta → pre-clamp error → PI/DAC_HPLL output → DCO request/state/step`，再決定唯一的 functional variable；不要直接調 lock threshold 或 PI 參數。

## 下一步

1. 保留本輪 branch 與 artifact，不修改 Step 3 baseline。
2. 先補足 raw tag delta、pre-clamp helper error、PI/DAC_HPLL 與 DCO request 的同時序觀測。
3. 只有在證據指出單一節點後，才建立單一 functional variable 的實驗；若要燒錄，必須先 commit，執行 clean firmware build、`quartus_sh --clean`、fresh compile，保存 MIF/SOF hash、programmer log 與 JTAG raw log，並立即建立新的繁體中文實驗紀錄。
