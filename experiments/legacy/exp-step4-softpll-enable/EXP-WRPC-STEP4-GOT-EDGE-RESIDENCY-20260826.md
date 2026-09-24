# EXP-WRPC-STEP4-GOT-EDGE-RESIDENCY-20260826

## 實驗基本資料

- 日期：2026-08-26（Asia/Taipei）
- Experiment ID：`EXP-WRPC-STEP4-GOT-EDGE-RESIDENCY-20260826`
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- Source HEAD at observation：`e7e5a50`
- Functional programmed image：前一輪由 `32feb04` 建置並燒錄的 image；`e7e5a50` 只新增文件，沒有 RTL/functional 變更
- Quartus Signal Tap：21.3.0 Build 170
- 本輪目的：在不重新編譯、不重新燒錄的 current image 上，驗證 REF/FB 是否持續 residency 於 `GOT_EDGE`，並同時觀察 high-qualification depth。

本輪沒有寫入 WR 控制或 SoftPLL 設定；只使用既有 JTAG mailbox read protocol 和唯讀 diagnostic readback。完整 raw log 的 SHA256 為：

```text
A28E3A3BCA073FD9BDDE4BDE6BDC5E8AF920992B6D1854D08A6AD5013B95E579
```

## 執行方式

```text
quartus_stp -t scripts/jtag/read_step4_startup_focused.tcl 100 100 events --raw
```

腳本對兩片板各取 100 個、間隔 100 ms 的 event-boundary snapshots，並讀取：

```text
DMTD_STATE
DEGLITCH_THRESHOLD
DMTD_HIGH_QUAL_MAX_STAB
DMTD_REF/FB_HIGH_QUAL_ABORT_COUNT
DMTD_REF/FB_ATOMIC_GOT_EDGE_ENTRY
DMTD_REF/FB_ACCEPT
```

`DMTD_STATE` 是 system-domain 的同步、粗粒度 state proxy；source encoding 為 `0=WAIT_STABLE_0`、`1=WAIT_EDGE`、`2=GOT_EDGE`。它不是完整 functional `stab_cntr` 的替代品。

## 100×100 ms residency 結果

| Board | DMTD state snapshots | GOT_EDGE residency | `HIGH_QUAL_MAX_STAB` REF/FB | Threshold | High-abort delta REF/FB | Atomic entry delta REF/FB | ACCEPT delta REF/FB |
|---|---:|---:|---:|---:|---:|---:|---:|
| Master `DE5 [1-11.1]` | 100/100 valid | REF 100/100、FB 100/100 | 9 / 7 | 1000 | 1,662,242,830 / 1,658,980,938 | 0 / 0 | 0 / 0 |
| Slave `DE5 [1-11.2]` | 100/100 valid | REF 99/100 state2；1 transient state0、FB state1 | 2 / 1 | 1000 | 1,663,743,048 / 1,652,967,492 | 0 / 0 | 0 / 0 |

Raw `SPLL_DMTD_STATE` values：

```text
Master: FC00000A × 100
Slave : FC00000A × 99, 00000014 × 1
```

`FC00000A` 解碼為 REF/FB state=`2/2`，亦即兩者均為 `GOT_EDGE`。`00000014` 解碼為 REF/FB state=`0/1`，是 Slave 在觀測窗口中的一次短暫 snapshot transition，不改變其 99/100 的 GOT_EDGE residency 結果。兩板的 sticky state snapshot 也都顯示 `got_edge_seen=1` 與 `high_abort_seen=1`。

所有核心 100-sample series 都完成讀取；沒有 mailbox timeout。Slave 的部分 series 有 `decrease=1` 記錄，原因是 state/counter snapshot 在 read window 中出現 transient/reset-like 變化；本表只採用各核心 counter 的完整 final-100 series 與腳本的 modulo delta，並保留原始 log。

## 判讀

1. Master 在整個 100-sample window 都維持 state2=`GOT_EDGE`；Slave 99% 的 snapshots 也維持 state2。
2. Threshold 固定為 1000，但 high qualification 最大深度只有 REF/FB=`9/7`（Master）及 `2/1`（Slave），遠未接近 ACCEPT 條件。
3. 在沒有新的 atomic `WAIT_EDGE -> GOT_EDGE` entry、且 ACCEPT 仍為 0 的同一窗口內，high-abort counter 持續大量增加。這與 source FSM 相容：high-abort 發生在 `GOT_EDGE` 內，清除 `stab_cntr`，但不離開 `GOT_EDGE`；因此後續可以在同一次 residency 內反覆 abort，不需要新增 entry。
4. Downstream TAG/TRR/CPU 仍不是本輪可靠 failure boundary，因為 upstream ACCEPT 沒有活動。

因此本輪支持以下較窄的 functional boundary：

```text
already in GOT_EDGE
        ↓
HIGH qualification repeatedly interrupted before threshold
        ↓
stab_cntr depth remains far below 1000
        ↓
ACCEPT = 0
        ↓
TAG / TRR / CPU not reached
```

這是 residency/depth evidence，不是對 polarity、threshold、clock frequency 或 root cause 的最終宣判；目前仍不修改 functional algorithm。

## 正式判定

```text
READ_ONLY_GOT_EDGE_RESIDENCY = SUPPORTED
HIGH_QUAL_DEPTH               = FAR_BELOW_THRESHOLD
STEP4_RESULT                  = NOT_PASS
ROOT_CAUSE                    = NOT_PROVEN
RTL_CHANGE                    = NONE
COMPILE_PROGRAM               = SKIPPED（遵循分支2建議）
```

## 原始證據

```text
docs/experiments/exp-step4-softpll-enable/raw/EXP-WRPC-STEP4-GOT-EDGE-RESIDENCY-20260826/got_edge_residency_100x100.log
```

