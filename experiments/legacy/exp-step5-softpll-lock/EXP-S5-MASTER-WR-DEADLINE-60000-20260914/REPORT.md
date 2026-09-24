# EXP-S5-MASTER-WR-DEADLINE-60000-20260914

## 結論

本輪「Master WR lock deadline 由 15000 ms 延長至 60000 ms」的功能修改：**未解決 Step5，Step5 = NOT COMPLETE**。

這一輪的重要結果是：Master 的 timeout 確實被延後，但 Slave 在本次 fresh power-cycle/program run 中沒有達到 PLL phase lock，因此沒有形成可用的 WR closed-loop session。不能把 deadline 延長視為 pass，也不能把本輪失敗解讀成 Master deadline 已被證明為唯一根因。

## 實驗身分與範圍

- experiment ID: `EXP-S5-MASTER-WR-DEADLINE-60000-20260914`
- branch: `exp/step5-softpll-lock`
- source commit: `8636158e8fd35fdcd504b559774ca5791c29fa4a`
- commit subject: `fix: extend master WR lock deadline for slow slave PLL`
- physical power-cycle: completed by user before this run
- Pain checkout: exact commit above, detached HEAD
- only functional change:

```c
#define WR_M_LOCK_TIMEOUT_MS        60000
```

`WR_STATE_RETRY`、SoftPLL thresholds、PI、DCO、reset tree、VUART 與 observer 均未修改。

## Build、燒錄與 transport

Master/Slave 完整 Quartus 編譯均成功，兩張 DE5a 均以本輪新影像燒錄成功；timing closure 仍為 `NO`。

| role | SOF SHA-256 | full compile | programming | timing closed |
| --- | --- | --- | --- | --- |
| Master | `db9a92025cb655da1e91566427ab788f91d20ada9255b753f761d7fad81f3623` | PASS | PASS | NO |
| Slave | `ce30ab60754666badaf5e82d3f117bc18fe0439e9f397abcf860b28198c7c9bd` | PASS | PASS | NO |

WB preflight：

```text
WB_REQUEST_COUNT = 353
PROBE_3WAY_MATCH_COUNT = 353
TIMEOUT_COUNT = 0
INVALID_COUNT = 0
ADDRESS_CROSS_CONTAMINATION_COUNT = 0
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

## Observer 結果

observer deadline 為 `240000 ms`，實際 elapsed 為 `241043 ms`；兩張板各 85 samples，`sample_errors=0`。

| role | first main enabled | first main freq locked | first phase locked | first SPLL ready | first tracking | first WR failure | first disable | final state |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| Master | NEVER | NEVER | NEVER | NEVER | NEVER | 178274 ms, `WR_M_LOCK_TIMEOUT` | 178274 ms | `WRS_IDLE`, PPSI failure |
| Slave | 9409 ms | 15404 ms | NEVER | NEVER | NEVER | 175778 ms, `WR_S_LOCK_TIMEOUT` | 175778 ms | `WRS_IDLE`, PPSI failure |

Slave 的觀測順序為：

```text
1220 ms       DMTD/TAG/TRR/IRQ/Helper activity and SPLL init
9409 ms       Main enabled
15404 ms      Main frequency locked
175778 ms     WR_S_LOCK_TIMEOUT / HANDSHAKE_FAILURE
```

Master 雖已改為較長 deadline，仍在 Slave 進入 `WRS_LOCKED` 之前收到 timeout；Master 的實際 failure 是在 178274 ms。Slave 的內部狀態在最後樣本為 `freq_locked=1, phase_locked=0, locked=0`，所以本輪不是「等久一點就自然完成」的證據。

兩張板的 `BOOT_GENERATION` 都維持 `1 → 1`，沒有新增 boot generation change；WB transport 也沒有 timeout、invalid 或 cross-contamination。這排除了本輪的 JTAG 觀測通道與重新 reset 作為主要解釋，但不能排除 Slave SoftPLL acquisition/phase convergence 的 run-to-run 不穩定性。

## 與上一輪的差異

上一輪 `EXP-S5-SLOCK-POLL-CALIB-CAUSE-AUDIT-20260914` 曾觀測到 Slave 在 `136886 ms` 進入 `SPLL_READY + Main phase lock + PSTAT_LOCKED + tracking`，但本輪同一類 fresh run 在 `15404 ms` 只到 frequency lock，直到 `175778 ms` 都沒有 phase lock。

因此目前真正的問題已收斂為兩層：

1. WR Master deadline 可能會截斷「慢但最後能 lock」的 Slave；延長 deadline 是合理假設，但本輪未能單獨驗證它。
2. 更根本的是 Slave PLL acquisition/phase convergence 在 fresh run 間不重現：一次可到 tracking，下一次只到 frequency lock 後 timeout。沒有先解決或定位這個變異，繼續調 WR timeout、PI 或 calibration 都缺乏因果依據。

## Step5 判定

```text
STEP5_RESULT = NOT_COMPLETE
STEP5_PASS = false
FIRST_INACTIVE_BOUNDARY = SLAVE_PLL_PHASE_LOCK / WR_EXTENSION_FAILURE
```

不能 pass 的原因：

1. `FIRST_MAIN_PHASE_LOCKED_MS=NEVER`、`FIRST_SPLL_READY_MS=NEVER`、`FIRST_PSTAT_LOCKED_MS=NEVER`。
2. Slave 先以 `WR_S_LOCK_TIMEOUT` 失敗，Master 後以 `WR_M_LOCK_TIMEOUT` 失敗。
3. 沒有有效 WR session 內連續 `PSTAT_LOCKED`/tracking。
4. 尚未取得三次 fresh-program 且皆達成 Step5 的可重現性證據。

## 下一步建議

下一輪不再增加 timeout，也不先改 PI/DCO。應以目前 `60000 ms` deadline 固定不變，做一次「Slave phase-lock run-to-run divergence」的最小觀測實驗：保留目前 telemetry，補齊或確認 phase-lock failure 的最後原因與 HPLL/DCO output 變化，並與上一輪 136.886 秒成功 tracking 的 raw samples 對齊。唯一目標是回答：

```text
同一 source/image、同一實體斷電流程下，
Slave 為何有時能由 frequency lock 進入 phase lock，
有時卻永遠停在 phase-unlocked？
```

只有在這個邊界可重現、且找到直接因果證據後，才選下一個 production fix。這個 commit 不 merge 到 `main`。

## Raw evidence

- raw directory: `raw/`
- raw transfer SHA-256: `af5fa1b2ef39e2912790e9a87218b206b3cb57c2c4f4504505d65cce000fd034`
- source constants SHA-256: `44501954dc87ea20ad3406a9f99aaa6640322f0ea21b4625d16cabf72b243a40`
- build, programming, preflight and observer logs are preserved under `raw/`.
