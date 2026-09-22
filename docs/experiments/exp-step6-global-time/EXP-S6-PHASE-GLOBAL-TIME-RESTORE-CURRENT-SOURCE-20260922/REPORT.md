# EXP-S6-PHASE-GLOBAL-TIME-RESTORE-CURRENT-SOURCE-20260922

日期：2026-09-22（Asia/Taipei）

## 結論

```text
STEP5_PHASE_LOCK_RECOVERED       = PASS
STEP5_FOUR_LOCKS_300S             = PASS
HELPER_HPLL_LOCK                  = PASS (316/316 cycles)
MAIN_FREQUENCY_LOCK               = PASS (316/316 frames)
MAIN_PHASE_LOCK                   = PASS (316/316 frames)
MAIN_LOCK                         = PASS (316/316 frames)
PSTAT_LOCK                        = PASS (316/316 cycles)
FULL_CHAIN_SECONDS                = 300.588
STEP6_GLOBAL_TIME_MASTER          = PASS
STEP6_GLOBAL_TIME_SLAVE           = PASS
TIMING_CLOSED                     = NOT REQUIRED FOR THIS FUNCTIONAL GATE
```

這輪沒有修改 PI、gain、threshold、timeout、bootstrap、arbiter、mailbox、
PHY、reset 或 production SoftPLL 控制，也沒有實體斷電。真正恢復 phase
lock 的關鍵是讓 Pain 使用目前 Step6 branch 的完整 fitted source；先前
Pain 使用的 detached 舊 source 缺少 Global-Time snapshot/SDC block。

## 精確來源與映像

```text
branch                              = exp/step6-Global-Time-Testing
source commit                       = 38dc612fe028e4b01c2f8209de974c6692c85e7d
source guard                        = PASS
Quartus                             = 17.0.0 Build 595
Slave SOF SHA256                    = e9cd76852c4fa01534dd66b35b28befb329acab2bc68f254ac6023aee377430e
Master SOF SHA256                   = 73149c537e66038c01a7c7c0af4b8e3d8205cd35ec268e20108f0fd30f194164
```

Laptop source audit also showed that the current functional source paths
(`firmware`, `rtl`, `vendor`, and `quartus/jtag_runtime_diag`) match the
known-good fitted Step6 source at `c24568e3`; this experiment added only the
source guard and its record.

## 實驗流程

1. Laptop pushed the source guard and experiment plan to the Step6 branch.
2. Pain pulled commit `38dc612f` into a fresh current-source worktree.
3. `scripts/pain/pain_build_jtag_f4l_step5.sh` compiled both boards with zero
   Quartus errors.
4. `scripts/pain/pain_program_jtag_f4l_step5.sh` programmed Slave first and
   Master second; both devices configured successfully with zero errors.
5. A read-only 90-second phase observer immediately saw the recovered Slave
   state:

   ```text
   HELPER_LOCKED=1
   MAIN_ENABLED=1
   MAIN_FREQ_LOCKED=1
   MAIN_PHASE_LOCKED=1
   MAIN_LOCKED=1
   PSTAT_LOCKED=1
   STATUS_TIME_VALID=1
   STATUS_PPS_VALID=1
   ```

6. The formal read-only 300-second F4L capture reached its target without
   terminal, reset, link, or transport failure.
7. A final read-only dashboard confirmed valid Global Time on both boards.

## 300 秒 phase / four-lock 證據

詳細逐週期計數在
[`analysis/lock-audit.md`](analysis/lock-audit.md)。

| 條件 | 觀測證據 | 結果 |
|---|---:|---|
| Helper/HPLL lock | `HELPER_LOCKED=1` | PASS，316/316 |
| Main frequency lock | `BRANCH_ID=2`, `FLAGS=383` | PASS，316/316 |
| Main phase lock | `FLAGS=383` 的 phase before/after、called、in-band bits | PASS，316/316 |
| Main lock | `MAIN_LOCKED=1` in recovery/direct state; F4L phase frames valid | PASS |
| PSTAT lock | `PSTAT_LOCKED=1` | PASS，316/316 |

健康條件同樣全程成立：`PHY_LINK_USABLE=1`、`TERMINAL=0`、
`RESET_CHANGED=0`、`SPLL_DELOCK_COUNT=0`、`SI_CONFIG_DROP_COUNT=0`、
`WR_FAILURE_REASON=0`。

## Global Time 結果

最終 read-only dashboard（300 秒觀測後）得到：

```text
MASTER  DE5 [1-11.1]
  TIME_VALID=1  PPS_VALID=1  SNAPSHOT_VALID=1  SNAPSHOT_STABLE=1
  TAI=827       CYCLES=124999999

SLAVE   DE5 [1-11.2]
  TIME_VALID=1  PPS_VALID=1  SNAPSHOT_VALID=1  SNAPSHOT_STABLE=1
  TAI=831       CYCLES=124999999
```

兩板是以分開的 JTAG read 取得，因此 TAI 不應直接做單 cycle 差值判定；
重要結果是兩板都已取得有效、穩定發布的 Global-Time tuple，且每秒 cycle
counter 正常到達 125 MHz reference 的 boundary。

## 面板訊息的解讀

最後 dashboard 的直接 lock fields 已經是：

```text
HelperLock=1 MainFreq=1 MainPhase=1 MainLock=1 PSTAT=1
```

但面板的 `Step5Result=UPSTREAM_NOT_READY` 仍受舊 Step3 sideband
`WR_RX_SIGNAL_DEBUG` / `WR_TX_SIGNAL_DEBUG` read-inconsistent 規則影響。
這是 dashboard gate classification 與直接 four-lock evidence 不一致，
不是 phase lock 遺失；本輪 raw WR core 與 F4L records 都顯示 link、PSTAT、
phase lock 及 reset health 全程有效。

同理，300 秒 observer 的 `schedule_valid=0` / `step5_pass=NO` 是它沒有
執行 optional producer-schedule page contract 的結果，並不否定本報告已
由 direct F4L fields 完成的四鎖 audit。

## Raw evidence checksums

```text
raw/observe/dashboard-2000ms.log
  B3E31A7768E1C0CB91973F62E69E36531CA9B32679403506D75925BBB09865DA
raw/observe/dashboard-after-300s.log
  51811FDE3EEE82F3CCD8BA6CABD90066B732DCFDAD6E069191E26BBA2FDF38AC
raw/observe/phase-rearm-observe-90s.log
  DB28C4533DB7B7DDF849523AD9D11B3913D24982946E087FB5CF1A1102B60794
raw/observe/step5-four-locks-300s.log
  26CA4317D576855EC7403C7600F68C02A4F7B8632E532AF25E0F6B2D3ACD5617
```

## 最終判定

本輪已實際完成「phase 問題」的功能性驗證：同一個已恢復 link 的
session，在不調參、不斷電的條件下，連續超過 300 秒維持 Helper lock、
Main frequency lock、Main phase lock、Main lock 與 PSTAT lock。這一版可作為
目前 Step5 functional pass 的復現證據；timing closure 仍獨立追蹤，不阻擋
此功能性判定。
