# Fable 建議：Step 5 卡在哪裡、接下來按什麼順序做

日期：2026-09-14（Asia/Taipei）
核對基準：本機與 GitHub `exp/step5-softpll-lock` HEAD `7fc1a2d`（`Add ai_advice folder`）；最新硬體 capture 的 source 為 `eb3d1a5`（demand correlation）、`88596aa`（S_LOCK cause audit）、`8636158`（Master deadline 60000）。工作樹另有 2 個未提交的 REPORT 修改與 7 個未追蹤 artifacts，本文不動它們。
本文只讀取 repo、重算 raw；沒有燒錄、沒有改控制程式、沒有 merge。

與 Astra 01–03 的關係：我接受 Astra 的量測可信度框架（seqlock、generation、READINESS=UNKNOWN 就不動作）與 §7.2 的 closure 規格；不同的是，我認為 **9/9–9/14 的資料已經足夠決定下一個唯一功能修正**，不需要再做一輪 position-read consistency audit 才能動手。理由與數字都在 §2；每個工作包都附「若模型對，你會看到什麼」的預期值，讓你可以在第一輪就判斷我有沒有算錯。

---

## 0. 一頁結論

**Step 5 = NOT COMPLETE**，但性質已經變了：9/12 的 bootstrap 3388 run 已經看到完整鏈 Helper lock → Main freq lock → Main phase lock → PSTAT.locked（最長 36.0 s，`EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3388-CALCULATED-ZERO-CROSSING-20260912`），9/14 的 audit 又看到 136.9 s 起 34 筆 SEQ_READY + PSTAT + TRACKING。所以問題不再是「鎖不上」，而是 **鎖不住、而且鎖太慢**。

我把根因收斂成三件互相耦合、都有 raw 佐證的事：

| # | 根因 | 直接證據 | 後果 |
| --- | --- | --- | --- |
| R1 | **Helper PI 增益沒有為這顆 actuator 重新標定。** 一個 FINC/FDEC 只改 0.216 tics/beat，64 code 一步，等於每 code 只有 upstream VCXO 的 ~1/200。用同一組 `kp=-150, ki=-1` 得到 ζ≈0.07 的欠阻尼迴路，再加上 32 code 的 P 死區（=874 tics），就是純積分＋量化極限環。 | 9/11、9/12 兩個 3600-sample raw 的 helper error 頻譜都在 **0.63–0.67 Hz** 有單一尖峰（週期 1.45–1.59 s）；線性模型算出 0.55–0.65 Hz。振幅 p99 1543、max 1986，剛好貼在 lock threshold 2000 之下。 | 22 次 helper unlock → `SEQ_READY → SEQ_CLEAR_DACS` → 整條鏈重來（`SPLL_DELOCK_COUNT_MAX=250`）。Kp −75/−125/−175、cooldown、Ki/4 都不可能改善，因為 ζ 與 kp/√ki 成正比，要到 ζ≈0.7 需要 kp≈−1500 以上。 |
| R2 | **工作點貼著 Helper 上 rail。** 3388 run 的 `HELPER_OUTPUT` 平均 63,693 / 65,531，只剩 1838 code = **29 步**的向上餘裕。 | 3388 run 平均 63,693（p95 64,734）；3372 run 平均 63,081；Kp −75、cooldown 64、PI trace sample 702 都看到 65,531 rail。 | 任何正向擾動或啟動暫態就撞 rail，並在 rail 上被 anti-windup 卡住。 |
| R3 | **時間預算互相打架。** Slave 有 60 s 的 `STEP5_HELPER_PHASE_GUARD_TICS`（這段 `update_loops()` 直接 return，Helper 完全不更新），加上 R1 造成的分鐘級 acquisition，對上 WR 協定的 S_LOCK/M_LOCK deadline（原 15 s，現 60 s×4 段）。 | 9/13–9/14 各 timeline：`FIRST_HELPER_LOCKED ≈ 63 s`、Main enabled 63–70 s、phase lock 72–137 s；Master `WR_M_LOCK_TIMEOUT` 50–58 s；Slave `WR_S_LOCK_TIMEOUT` 175 s。 | 9/13 以後看到的 Step 2/3「上游退化」（PTP fallback、`parentCalibrated=0`）大多是 Step 5 太慢的投影，不是新的 PHY/PTP 問題。 |

另外一個沒人標出來、但 9/14 raw 裡很清楚的事：**Master 的 Helper 從頭到尾沒有鎖**。`EXP-S5-SLOCK-POLL-CALIB-CAUSE-AUDIT-20260914/raw/startup-timeline.log` 的 85 筆 Master 樣本中 81 筆 `locked=0, lock_count=6`，`DCO_HELPER_OUTPUT=0xFFFB`（65531，上 rail）、`DCO_HELPER_ERROR=−150000`（clamp）整整 236 s 不變，`L2_HELPER_COMPLETED` 停在 1927。Master 的 generic map 是 `ENABLE_STEP5_BOOTSTRAP => 0`，它的 1024 步 fine range 根本到不了零交越。這不擋 Step 5 的 Slave PSTAT gate，但 Master 的 ptracker 永遠不會啟動、fine timestamp 無效，Step 6 一定會撞到。

**一句話的建議：停止加 observer、停止掃 cooldown/threshold/timeout；照 §3 的順序做四個單變因功能修正（F1 Helper 增益重標定 → F2 bootstrap 置中 → F3 guard/reseed → F4 Main 增益＋仲裁優先權），Master bootstrap（F5）可平行，然後做三次 fresh-program 的 closure（F6）。** 每一步都有可計算的預期值；第一步 F0 甚至不用碰板子。

---

## 1. 9/9 → 9/14 到底發生了什麼（只列會改變決策的事）

| 日期 | 實驗 | 對決策有用的事實 |
| --- | --- | --- |
| 9/9 | `HPLL-PLANT-ID-5632`：隔離 plant test，4096 步 | **FINC 使 FREQ_ERROR +886，FDEC −890** → 每步 0.216 tics/beat；4096 步耗時 5146 ms → **796 步/s**。normal tracker 方向映射錯誤已修（`DIRECTION-CORRECTED`）。 |
| 9/9 | `HPLL-NEAREST-QUANTIZED-STEP` | half-step admission（32 code）修正確認進了 bitstream。 |
| 9/9 | `ZERO-CROSSING-3360-*` 系列（Kp −75/−150、cooldown 16/32/64/256、STEP32、decimate64、Ki 0） | 全部在錯的工作點（rail），不能作為 PI 結論。 |
| 9/11 | `BOOTSTRAP-3372-CALCULATED-ZERO-CROSSING` | Helper 離開 rail，RMS 1430，152 次 unlock，Main freq lock 有、phase 無。 |
| 9/12 | `BOOTSTRAP-3388-CALCULATED-ZERO-CROSSING` | 用 0.216/步算出 +16 步，**整條鏈首次成立**，full chain 最長 36.0 s，Helper RMS 596、22 次 unlock、`ERROR_BAND_EXIT=463`。 |
| 9/12 | Kp −75 / −125 / −175、cooldown 8/16/64、Ki/4、Main Kp 300、reseed bias 63252 | 沒有一個把 full chain 拉過 36 s；Kp −75 直接回 rail。**這是 R1 的預測結果**（見 §2.5）。 |
| 9/12 | `HELPER-PI-TRACE`、`MAIN-PI-TRACE` | PI trace 可讀；Helper 啟動後有高側 clamp；Main freq lock 後 phase error 仍 7838 tics（threshold 1200）。 |
| 9/13 | calibration timeline、failure reason audit、S_LOCK trace、TIMEOUT60 | 失效邊界定位到 `WR_S_LOCK_TIMEOUT`（reason=3）；把 S_LOCK 15 s → 60 s 沒有解決。 |
| 9/14 | `SLOCK-POLL-CALIB-CAUSE-AUDIT` | Slave 70.5 s enable、79.5 s freq、**136.9 s phase/PSTAT/tracking**；Master 57.8 s 已 M_LOCK timeout；Slave 142.9 s `WR_LOCKED_TIMEOUT`。`calib_t24p` 失敗 0x224 次後才有一次成功。 |
| 9/14 | `MASTER-WR-DEADLINE-60000` | Master deadline 拉到 60 s：Slave 9.4 s enable、15.4 s freq lock，phase lock 到 175.8 s 都沒出現。 |
| 9/14 | `HPLL-DEMAND-MAIN-PROGRESS-CORRELATION`、`STARTUP-CONTRACT-V3`、`L2-TELEMETRY` | observer 修正，INCONCLUSIVE；沒有新的控制事實。 |

結論：**從 9/12 中午到 9/14，控制迴路本身一個功能變因都沒改**，全部時間用在 timeout 與 observer 上。9/12 的資料其實已經把答案寫在頻譜裡了。

---

## 2. 把 actuator 當受控體算一遍：為什麼會振盪、為什麼掃 Kp 沒用

### 2.1 已經量到的 plant 參數（全部來自你自己的 raw）

| 量 | 值 | 來源 |
| --- | --- | --- |
| 一個物理步對 helper 頻率誤差的影響 `g_step` | 0.216 tics/beat/步（9/9 immediate response）；由振盪頻率反推約 0.30 | `HPLL-PLANT-ID-5632` bidir-4096；§2.3 |
| 每個物理步的 virtual code | 64（`HPLL_TRACKER_CODE_PER_PHYSICAL_STEP => 64`） | `DE5a_wr_slave_jtag.vhd:1919` |
| 每 code 的頻率增益 `g_code = g_step/64` | 3.4e-3（~4.7e-3）tics/beat/code | 推導 |
| Helper 更新週期 `T`（=DMTD beat） | 16384 / 62.496 MHz = 262 µs；9/14 raw 量到 Slave 3803 updates/s ≈ 263 µs | `HELPER_UPDATE_COUNT` 差分 |
| actuator 速率上限 | 796 步/s（4096 步 / 5146 ms），每步 4 筆 I2C write（page3 → mask → page0 → FINC/FDEC） | 9/9 raw；`si5340a_controller_dco.v` rt_state 1–6 |
| 相位加速度上限 | 796 × 0.216 × 3814 ≈ 6.6e5 tics/s² | 推導 |
| PI 定點 | `y = ((I + ki·x) + x·kp + 2^(shift−1)) >> 12 + bias`，int64，`bias = y_min = 5`，`y ∈ [5, 65531]`，anti-windup | `spll_common.c::pi_update`、`spll_helper.c` |
| tracker admission | `|target − applied| ≥ 32 code` 才排一步 | `si5340a_controller_dco.v:915-918` |
| lock detector | threshold 2000、lock_samples 1000、delock_samples 100（upstream 為 200 / 10000 / 100） | `spll_helper.c:37-46` |

### 2.2 迴路模型與現況數字

Helper 是「PI → 頻率 actuator → 相位積分」的標準二階迴路。以每 beat 為單位：

```text
K_p = g_code · kp / 4096          (每 beat 的比例迴路增益)
K_i = g_code · ki / 4096          (每 beat² 的積分迴路增益)
ω_n = sqrt(K_i) / T               自然頻率
ζ   = K_p / (2 · sqrt(K_i))        阻尼比
```

代入現況 `kp=−150, ki=−1, g_code=3.4e-3`：

```text
K_p = 1.24e-4,  K_i = 8.2e-7
ω_n = 9.1e-4 / 262 µs = 3.5 rad/s = 0.55 Hz   (用 g_step=0.30 則 0.65 Hz)
ζ   = 0.068
```

ζ 0.07 表示任何擾動要 ~1/(ζ·ω_n) ≈ 4 s 才衰減到 1/e，而每一次 64-code 的物理步本身就是一個擾動。

### 2.3 用 raw 驗證：0.63–0.67 Hz 的振盪峰

我對 `FRAME_VALID=1` 的 `HELPER_ERROR` 做 0.1 s 重取樣＋Hann 窗 FFT（腳本在附錄 C）：

| run | 樣本 | FFT 主峰 | 過零週期（中位數 / IQR） | in-band \|e\| p50 / p90 / p99 / max | unlock 次數 | HELPER_OUTPUT 平均 |
| --- | --- | --- | --- | --- | --- | --- |
| 9/12 3388, kp −150 | 3374 | **0.672 Hz（1.49 s）** | 1.45 s（1.20–1.75） | 408 / 968 / 1543 / 1986 | 22 | 63,693（距 rail 29 步） |
| 9/11 3372, kp −150 | 3206 | **0.627 Hz（1.59 s）** | 1.59 s（1.40–1.72） | 770 / 2135 / 3863 / 4902 | 188 | 63,081（距 rail 38 步） |

兩個獨立 run、不同 bootstrap，主峰都在 0.63–0.67 Hz，而且是單峰，不是寬頻雜訊。這和 §2.2 的 ω_n 一致到 20% 以內（差異來自 g_step 0.216 vs 0.30 的不確定度）。**這是「迴路太慢、太欠阻尼」的直接指紋**；如果是 I2C 延遲或速率限制主導，峰會在 >2 Hz。

### 2.4 量化死區與 lock detector 的關係

P 項要推動一步，需要 `kp·e/4096 ≥ 32 code`：

```text
P 死區 = 32 · 4096 / |kp| = 874 tics   (kp=−150)
```

|e| < 874 時 P 完全不動，只有積分器慢慢累積到 32 code 才跨一步；跨了一步頻率就變 0.216 tics/beat（=824 tics/s 的相位斜率），相位走回來又跨回去。純積分 + 量化 actuator 的極限環振幅就是死區量級（幾百到一千多 tics），實測 p90 968、max 1986 —— **恰好卡在 threshold 2000 底下**。所以 helper 一直在「鎖 1000 samples → 出界 → delock 900 samples → 重鎖」之間翻，也就是報告裡的 `LOCK_COUNT_RISE/FALL 22/22`、`ERROR_BAND_EXIT 463`。

每次 unlock 的代價（`softpll_ng.c:295-298`）：`SEQ_READY → SEQ_CLEAR_DACS`，`DAC_HPLL = y_max`、`DAC_MAIN = midscale`，Helper 從 code 5 重新爬、Main 從頭 freq→phase。這就是 full chain 永遠 < 36 s 的機制。

### 2.5 為什麼 −75 / −125 / −175 都沒用

`ζ ∝ kp / sqrt(ki)`。ki 固定 −1 時：

| kp | ζ | P 死區 |
| --- | --- | --- |
| −75 | 0.034 | 1748 tics（≈threshold，所以直接回 rail） |
| −125 | 0.057 | 1049 |
| −150 | 0.068 | 874 |
| −175 | 0.080 | 749 |
| −1500 | 0.68 | 87 |

−75 到 −175 的 ζ 全部在 0.03–0.08，本來就不可能看出差別；要到 ζ≈0.7 需要 kp 大一個數量級，而 ki 也要跟著提高才有合理的 ω_n。cooldown 只是在積分路徑上再插延遲，只會更差（cooldown 64 的結果 RMS 86,000 就是這樣）。

### 2.6 與 upstream 的對照：同一組數字、差 200 倍的 plant

upstream WR node 的 helper 用 `kp=150, ki=2` 驅動 16-bit DAC + VCXO；VCXO 靈敏度約 3 ppb/code，換成 tick 單位約 0.7–0.8 tics/beat/code。代進同一個模型：

```text
upstream: ω_n ≈ 70 rad/s (11 Hz), ζ ≈ 0.7   ← 健康的迴路
本設計:   ω_n ≈ 3.5 rad/s (0.55 Hz), ζ ≈ 0.07  ← 同樣的 kp/ki，plant 小 200 倍
```

`spll_helper.c` 的 `kp/ki` 是為 VCXO 設計的常數，從來沒有為「64 code = 0.216 tics/beat」的 FINC/FDEC virtual DAC 重新標定過。這才是 R1 的本質；bootstrap、page/mask、direction 修正都是必要條件，但它們修完之後迴路本身仍然是錯的比例。

### 2.7 速率限制與延遲決定「該調到多快」

不能無限提高增益，上限來自 actuator：

- 相位加速度上限 6.6e5 tics/s²。迴路要在誤差振幅 A 下不進入 slew-limit，需 `A·ω_n² ≲ 6.6e5`。A=2000（threshold）→ ω_n ≲ 18 rad/s；A=500 → ω_n ≲ 36 rad/s。
- 每步 1.26 ms；P 項一次要求 n 步就要 n×1.26 ms 才做完。ω_n=10 rad/s、e=2000 tics 時 P 要 34 步 = 43 ms，遠小於 1/ω_n = 100 ms，可接受；ω_n=20 時是 87 ms vs 50 ms，開始吃緊。

所以設計目標是 **ω_n ≈ 10 rad/s（1.6 Hz）、ζ ≈ 0.7–0.8**，比 upstream 慢 7 倍，但比現在快 3 倍、阻尼好 10 倍。這是 F1 候選 A 的來源。

### 2.8 工作點：貼著 rail 29 步

Helper 上 rail 65531，3388 run 的輸出平均 63,693，p95 64,734。往上只剩 29 個物理步，往下有 995 步。啟動暫態、每次 reseed（`pi_init` 把 y 打回 5 再爬上來）、任何正向擾動都會撞 rail，撞上去之後 anti-windup 讓積分器停住，rail 期間 helper error clamp 在 ±150000，看起來就像「actuator 沒有 authority」。

置中公式（tracker 的 applied 和 target 都在 code 座標，1 步 = 64 code）：

```text
B_new = B_old + (mean(HELPER_OUTPUT) − 32768) / 64
      = 3388 + (63693 − 32768) / 64 = 3388 + 483 = 3871      (9/12 run)
      = 3372 + (63081 − 32768) / 64 = 3372 + 474 = 3846      (9/11 run)
```

兩個 run 相差 25 步（~0.02 ppm 等級），取 **3860**。注意 Slave 的 `ENABLE_STEP5_ACTUATOR_IDENTIFICATION => 1`，所以 `STEP5_BOOTSTRAP_REVERSE => 1` 在 RTL 裡是 `rt_dir = 1 = FINC`（`si5340a_controller_dco.v:867-870`），與 3372→3388 「+16 步 FREQ_ERROR +3.5」一致；置中就是再多 ~480 步 FINC。

### 2.9 Main 迴路：同樣的病，再加 ±8192 wrap

Main 用 `DPLL_TRACKER_CODE_PER_PHYSICAL_STEP => 16`，N0 的 FSTEPW 與 N1 相同（128），只是 N0 ≈ 33.75 vs N1 ≈ 30，所以每步約 0.19 tics/beat（未直接量測，標為待驗），每 code 約 0.012。現況 `kp=+300, ki=+1`：

```text
ω_n ≈ 6.5 rad/s (1.0 Hz), ζ ≈ 0.26；upstream 1100/30 在 VCXO 上是 ω_n ≈ 270 rad/s, ζ ≈ 1.3
```

Main 的 acquisition 還有兩個放大器：

1. freq 模式用 `err = −MPLL_FREQ_PRELOCK_GAIN_BOOST(20) × freq_error`，phase 模式改吃相位差並 mask 到 ±8192（`spll_main.c:365-379`）。切換瞬間相位誤差是任意值（PI trace 看到 7838），距 wrap 邊界 8192 只有 354 tics；ζ 0.26 的過衝很容易跨過 wrap 變成 cycle slip，這是「freq lock 有、phase lock 60 s 才來或永遠不來」最合理的機制。
2. **仲裁順序是 Main 先、Helper 後**（`si5340a_controller_dco.v:842-856` 的 `rt_state==0` 先看 `dpll_target != applied`，才看 `hpll_pending`）。Main 只要有 ≥16 code 的殘差就一直佔 I2C，Helper 排不到步 → helper unlock → 整條鏈重來。Astra 的 `EXP-S5-DCO-LIVENESS-20260912` 在模擬裡已重現（Main completed 208、Helper 0）。WR 的正確優先權是 Helper 先，因為 Helper 掉了 Main 一定跟著掉。

### 2.10 Master 的 Helper 從來沒鎖

9/14 `startup-timeline.log` Master 端：

```text
t=0.7 s   HELPER_UPDATE_COUNT=0x27DEF  DCO_HELPER_ERROR=-150000  DCO_HELPER_OUTPUT=65531  L2_HELPER_COMPLETED=1927
t=236 s   HELPER_UPDATE_COUNT=0x10663D DCO_HELPER_ERROR=-150000  DCO_HELPER_OUTPUT=65531  L2_HELPER_COMPLETED=1927
SPLL_SEQ_STATE=4(SEQ_WAIT_HELPER) 全程；SPLL_HELPER_STATE locked=0, lock_count=6 共 81/85 筆
```

（另外 4 筆 `locked=1` 的 `lock_count` 是 14336/33024/34048/55552，超過 `lock_samples=1000` 的上限，應視為 bank 重疊/解碼無效樣本，不是鎖定證據。）

Master build 同樣是 `CONFIG_WR_NODE`，用同一組 −150/−1，但 `DE5a_wr_master_jtag.vhd:1545` 是 `ENABLE_STEP5_BOOTSTRAP => 0`：它只有 tracker 的 1024 步，從 code 5 爬到 65531 就停在 rail。用 update rate 粗估：Master 3865/s vs Slave（鎖定時）3803/s，比值 1.016 → Master 在 rail 上的 tag_delta ≈ 16,120，`FREQ_ERROR ≈ −260`，還差約 **+1200 步**（±800，這個方法很粗）才到零交越。

Master helper 不鎖的直接後果：Master 永遠停在 `SEQ_WAIT_HELPER`，`start_ptrackers()` 不會執行，Master 端 RX 相位（t4 的 fine part）無效。Step 5 的 Slave PSTAT gate 不看這個，但 Step 6 的 offset/delay 一定錯，而且 Master 端 `calib_t24p` 若被呼叫也會失敗。

### 2.11 時間預算：60 s guard × WR timeout

`softpll_ng.c:53` `STEP5_HELPER_PHASE_GUARD_TICS = 60 s`，guard 期間 `update_loops()` 在呼叫 `helper_update()` 之前就 return（`softpll_ng.c:315-321`）。也就是 Slave 從 `SEQ_START_HELPER` 起 **60 s 內 Helper PI 完全沒有動作**，DAC 停在 `y_max`；60 s 後 `helper_reseed()` → `pi_init()` → y=5 → tracker 從 rail 走 1024 步到 5、再由 PI 爬回 ~63,700。bootstrap 本身只要 3388/796 ≈ 4.3 s，guard 多等了 55 s。

WR 端：`WR_S_LOCK_TIMEOUT_MS = WR_M_LOCK_TIMEOUT_MS = 60000`、`WR_STATE_RETRY = 3`，`wr_s_lock()` 設 240 s 總預算、每 60 s retry 一次（`locking_disable()` 是 no-op，`locking_enable()` 有 idempotent guard，所以 retry 不會重啟 SoftPLL — 這點是好的）。但 Master 端 `wr_m_lock()` 等 Slave 的 LOCKED 也是同一預算；Slave 若在 136 s 才鎖，Master 在 57.8 s（舊 15 s×4）或 178 s（新 60 s×4 減去 observer 偏移）已放棄。**只要 F1–F3 讓 Slave 在 15–20 s 內鎖定，現在的 60 s×4 預算綽綽有餘，不必再動 timeout；F1–F3 之前再怎麼拉 timeout 都只是把失敗往後延。**

---

## 3. 工作包（每包唯一變因，附預期值與驗收）

共通規則沿用 Astra §8：laptop 改／commit／push → Pain pull 同一 commit → full firmware + Quartus build → 兩板燒錄（Master → 45 s → Slave）→ 120 s settled preflight → coherent observer。每包只改一個功能變因，保留 MIF/SOF hash。**不要把 F1–F4 塞進同一輪**；但 F5 與 F1–F4 互相獨立，可以在另一張板上平行。

### F0 — 離線驗證本文模型（不碰硬體，30 分鐘）

目的：讓接手者不用相信我，自己看到頻譜峰。

1. 跑附錄 C 的腳本於 `EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3388-CALCULATED-ZERO-CROSSING-20260912/raw/observer-step5-bootstrap3388-20260912.log` 與 9/11 3372 的 observer log。
2. 預期：FFT 主峰 0.6–0.7 Hz、單峰；`HELPER_OUTPUT` 平均 63,000–64,000。
3. 若主峰不在 0.4–1.0 Hz、或呈寬頻，本文 §2 的模型就有錯，先回報再做 F1。

### F1 — Helper PI 重標定（唯一變因：`spll_helper.c` 的 kp/ki）

```c
/* vendor/wrpc-sw/softpll/spll_helper.c, helper_very_init(), CONFIG_WR_NODE 分支 */
s->pi.kp = -4500;   /* 原 -150 */
s->pi.ki = -8;      /* 原 -1  */
```

候選 A（先做）：kp −4500、ki −8 → `K_p=3.7e-3, K_i=6.6e-6, ω_n≈9.8 rad/s (1.6 Hz), ζ≈0.72`，P 死區 29 tics。用 g_step=0.30 算則 ω_n 11.6、ζ 0.85，兩種假設都在安全區。
候選 A/2（若 A 出現 >2 Hz 振盪）：kp −2250、ki −2 → ω_n 4.9 rad/s、ζ 0.72。
候選 B（A 通過後想更快再做）：kp −9000、ki −33 → ω_n 19.9 rad/s、ζ 0.71，但 P 步數 87 ms vs 1/ω_n 50 ms，slew 風險高，不是第一選擇。

定點安全：`pi_update` 用 int64，`|x·kp| ≤ 150000 × 9000 = 1.35e9`、`ki·x ≤ 1.2e6/beat`，都遠小於 2^63；anti-windup 照常。不需要動 `shift`。

保留：bootstrap 3388、code/step 64、cooldown 0、threshold 2000 / lock_samples 1000、Main PI、guard 60 s、WR timeout。

預期（若模型對）：

```text
HELPER_ERROR_RMS            < 150   (量化極限環剩 ~1 步的相位，幾十 tics)
ERROR_BAND_EXIT_EVENTS      0 / 600 s
LOCK_COUNT_RISE/FALL        1 / 0
SPLL_DELOCK_COUNT_DELTA     0
HELPER_OUTPUT mean          仍 ≈ 63,700  (工作點與增益無關)
FFT 主峰                    消失，或移到 > 1.5 Hz 且幅度 < 100 tics
```

判讀分流：

- RMS 降到 <300 但出現 HIGH_RAIL 片段 → 是 R2，直接進 F2，**不要**把增益調回去。
- 出現 2–8 Hz 的新振盪 → 延遲/slew 主導，改候選 A/2。
- RMS 仍 >500 且主峰仍 ~0.6 Hz → 增益沒進 image，先查 firmware MIF hash 是否隨 commit 改變（9/13 的 timeout60 就發生過 MIF 沒重建）。
- 通過後把 lock detector 收回 500 / 5000，再收回 upstream 的 200 / 10000；每次只改 detector。

### F2 — bootstrap 置中（唯一變因：`STEP5_BOOTSTRAP_STEPS`）

```vhdl
-- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:1914
STEP5_BOOTSTRAP_STEPS => 3860,   -- 原 3388；= 3388 + (63693−32768)/64
```

`STEP5_BOOTSTRAP_REVERSE => 1` 不動（在本 image 語意就是 FINC）。做 F2 之前用 F1 那一輪的 `HELPER_OUTPUT` 平均重算一次，若與 63,693 差超過 ±1000 code 就用新值。

預期：`HELPER_OUTPUT` 平均 32,768 ± 3,000；`HIGH_RAIL_FRACTION = LOW_RAIL_FRACTION = 0`；helper error 統計與 F1 相同。若平均落在 32,768 ± 3,000 之外但穩定，只是 g_step 的比例誤差，記下實測值、把 bootstrap 再修一次即可，不算失敗。

### F3 — 啟動時序：guard 與 reseed

F3a（唯一變因）：

```c
/* vendor/wrpc-sw/softpll/softpll_ng.c:53 */
#define STEP5_HELPER_PHASE_GUARD_TICS (8 * TICS_PER_SECOND)   /* 原 60 s；bootstrap 3860/796 ≈ 4.9 s + 3 s margin */
```

F3b（可選，另一輪）：`helper_reseed()` 不要呼叫 `pi_init()`，只清相位累加器與 lock detector，保留 `pi.integrator / pi.y`。現在每次 reseed 都把 y 打回 5，tracker 走 1024 步下去再由 PI 爬上來，是一個沒必要的 2.6 s、±1000 步的暫態。

預期：`FIRST_HELPER_LOCKED_MS` 從 ~63 s 降到 10–15 s；Main enabled 緊接其後；整條鏈 < 30 s。此時 WR 60 s×4 預算足夠，`WR_S_LOCK_TIMEOUT`/`WR_M_LOCK_TIMEOUT` 不必再改；等 closure 量到 lock time < 10 s 後，再考慮把兩個 timeout 收回 upstream 的 15 s（單獨一輪）。

### F4 — Main PI 重標定＋仲裁優先權

F4a（firmware，唯一變因）：

```c
/* vendor/wrpc-sw/softpll/spll_main.c */
#define MPLL_FREQ_PRELOCK_GAIN_BOOST 4     /* 原 20：kp 放大 4.3 倍後，freq 模式的等效增益維持 ≈ 現況 */
...
s->pi.kp = 1300;   /* 原 300 */
s->pi.ki = 3;      /* 原 1   */
```

以 g_main_code ≈ 0.012 估：ω_n ≈ 11 rad/s（1.8 Hz）、ζ ≈ 0.64；P 死區（16 code）50 tics。phase 模式進入時最大誤差 8192 需要的加速度 8192 × 11² ≈ 1.0e6 tics/s²，與 actuator 上限同量級，所以不建議更高。可選：`freq_ld.threshold 50 → 100`，避免 phase 模式的 P kick 讓 freq detector 掉鎖來回切模式；這個標為第二變因，另一輪。

F4b（RTL，唯一變因）：`si5340a_controller_dco.v` `rt_state==3'd0` 的分支順序改成 **normal HPLL（`hpll_pending` 且非 forced）先、DPLL 殘差後**，bootstrap/forced 分支順序不動。先用既有 `scripts/experiment/tb_dco_liveness.sv` 重跑，預期「Main 有 backlog 時 Helper completed > 0」；再上板。

預期：`FIRST_MAIN_PHASE_LOCKED − FIRST_MAIN_FREQ_LOCKED < 5 s`；`MAIN_PI_X` 進 phase 模式後單調收斂、不出現 ±8192 跳變；`calib_t24p` 失敗次數（`LOCK_CALIB_FAIL_COUNT`）由 0x224 量級降到個位數，因為 t24p 校準要做的 phase-shift 掃描終於跟得上。

### F5 — Master 的 Helper 也要有 bootstrap（與 F1–F4 獨立，可平行）

1. 先量 Master 的零交越：把 9/8 的 static bracket 方法（`EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC*`）搬到 Master image；粗估鎖點在現行 rail 之上再 +500～+2000 步（§2.10）。
2. Master generic map 加 `ENABLE_STEP5_BOOTSTRAP => 1`、`STEP5_BOOTSTRAP_STEPS => <量到的值 − 512>`、`STEP5_BOOTSTRAP_REVERSE => 1`，**同時**加 `ENABLE_STEP5_ACTUATOR_IDENTIFICATION => 1`——否則 forced reverse 在 RTL 裡是 `~hpll_dir`（相對上一次 normal 方向），bootstrap 方向會變成未定義（`si5340a_controller_dco.v:867-870`）。
3. Master firmware 與 Slave 共用 `spll_helper.c`，F1 的增益會一起生效；Master 沒有 phase guard（`softpll_ng.c:241-247` 只對 SLAVE），不需要 F3。

驗收：Master `SPLL_SEQ_STATE = SEQ_READY`、`SPLL_HELPER_STATE locked=1` 連續 600 s、`DCO_HELPER_OUTPUT` 在 32,768 ± 3,000、`DCO_HELPER_ERROR` 不再是 −150000。這是 Step 6 的前提，也會讓 Master 端 `WR_M_LOCK` 之後的 calibration 有正確的相位量測。

### F6 — Closure（沿用 Astra §7.2，補三條）

在 F1–F4（含 F5 更好）之後，同一 source、三次 fresh power-cycle + program：

```text
STEP1_TO_STEP3 = PASS, STEP4B = PASS（settled preflight）
WR: PPSI_PDSTATE ≠ FAILURE, PPSI_EXTSTATE = ACTIVE, parentCalibrated = 1, WR_FAILURE = 0 全程
SoftPLL: SEQ_READY 且 PSTAT_LOCKED = 1 連續 ≥ 300 s（三次都要）
SPLL_DELOCK_COUNT_DELTA = 0；RESET_* delta = 0
HELPER_ERROR_RMS < 150；MAIN phase err RMS < 300；HELPER_OUTPUT 在 32,768 ± 5,000
FIRST_PSTAT_LOCKED_MS < 30,000（從 spll_init 起算）
lock detector 已收回 200 / 10000（或明列仍為放寬值）
timing_closed 狀態單獨列出，不混進 lock 判定
```

三次都過才寫 `STEP5_COMPLETE=YES`；merge 另外問。

---

## 4. 應該停止（或降到低優先）的事

- **再加 observer / 再修 reader。** N1/N2/L2/PI trace/coherent observer 已經夠用；Astra 03 §D 的 position-read consistency audit 結論其實已知（accounting 在活動期間會變，是 reader 的靜止窗口假設問題），它不擋 F1。
- **再拉 timeout。** 60 s×4 已經比需要的多；F1–F3 之前拉再長也只是延後失敗。
- **cooldown、threshold、lock_samples、decimation、Ki/4 的掃描。** 這些都在 ζ 0.03–0.08 的區間內移動，看不出差別。
- **±50 的 Kp 掃描。** 要動就一次動一個數量級（F1）。
- **把冷開機／PHY／Step 1 問題混進 Step 5 輪次。** 那是獨立線，用 Astra 01 §六 的方法另開。
- **在 rail 上調 PI。** 只要 `HIGH_RAIL_FRACTION > 0.05`，那一輪的 PI 統計都不算數。

---

## 5. 不確定處、風險與備案

1. **g_step 的兩個估計（0.216 vs 0.30）差 40%。** 候選 A 在兩種假設下 ζ 0.72–0.85、ω_n 9.8–11.6 rad/s，都安全；但如果 F1 後量到的振盪頻率暗示 g_step 差 3 倍以上，重算一次再選增益。若要一勞永逸，做一次 I2C readback：對 N1_NUM 讀回、打 100 個 FINC、再讀回，同時得到（a）FINC 是否為 `N_NUM += FSTEPW` 的加法模型、（b）絕對位置的 readback（解決 applied-position 記帳無法對實體驗證的老問題）。
2. **大增益的捕獲暫態。** |e| 大時 P 項會把 y 打到 rail，迴路變 bang-bang，直到 |e| < 65536×4096/4500 ≈ 60,000 tics 才線性。理論上會收斂，但若 F1 出現「大振幅、頻率 0.2–0.5 Hz、不收斂」的極限環，備案是兩段式增益：未鎖定用 A/4，`ld.locked` 之後切到 A（Main 已有 `gain_sched` 結構可以照抄）。
3. **I2C NACK 不擋 completed（Astra 01 §4.3）。** 增益提高後每秒步數變多，若有 NACK，applied 會慢慢偏離實體；配合第 1 點的 readback 做定期校正。F1 那一輪先看 `L2_ACK_EVENTS` 是否為 0。
4. **速率上限。** 若 F1/F4 都撞到 slew（>2 Hz 振盪），有兩個結構性選項：（a）同一 loop 連續步只需 1 筆 FINC/FDEC write，省掉重複的 page/mask（4→1 筆，速率 ×4）；（b）I2C 從 ~100 kHz 拉到 400 kHz（Si5340 支援）。合起來可到 ~10k 步/s。
5. **絕對 N_NUM 作 DAC。** 把 PI 輸出直接寫成 `N1_NUM = N1_NUM0 + code × K`（6 byte + N1_UPDATE，7 筆 write，以 100–200 Hz 更新），同時消掉量化、累加誤差與速率限制。Astra 也提過；這是獨立分支，只有 F1–F4 走不通才啟動。
6. **工作點溫漂。** 3372/3388 兩天的估計只差 25 步，但長期會漂；F2 之後若某天又貼 rail，做「lock 後自動把 bootstrap 修到 output≈32768」的 auto-centering，不要每次手算。
7. **Main 的 g 沒有直接量。** F4a 的增益是用 N0/N1 比例推的；若 F4a 後 Main 出現 >3 Hz 振盪，先把 kp/ki 各除以 2，同時排一次 Main 的 plant-test（把 9/9 的方法用在 DPLL 通道）。
8. **timing 沒 closed**（Master WNS −0.058 ns、Slave +0.015/−0.209 ns）。與本文無關，但 closure 報告要單列。
9. 我沒有實機，所有數字都從 raw 與 source 推算；每個工作包的「預期」就是驗證我有沒有算錯的方法。

---

## 附錄 A：數字表

Helper（`g_code = 3.4e-3 tics/beat/code`，`T = 262 µs`，admission 32 code）：

| 設定 (kp / ki) | K_p (/beat) | K_i (/beat²) | ω_n rad/s (Hz) | ζ | P 死區 tics |
| --- | --- | --- | --- | --- | --- |
| 現況 −150 / −1 | 1.24e-4 | 8.2e-7 | 3.5 (0.55)，實測 0.63–0.67 Hz | 0.07 | 874 |
| −75 / −1 | 6.2e-5 | 8.2e-7 | 3.5 | 0.03 | 1748 |
| −175 / −1 | 1.44e-4 | 8.2e-7 | 3.5 | 0.08 | 749 |
| **A −4500 / −8** | 3.7e-3 | 6.6e-6 | **9.8 (1.6)** | **0.72** | 29 |
| A/2 −2250 / −2 | 1.9e-3 | 1.6e-6 | 4.9 (0.78) | 0.72 | 58 |
| B −9000 / −33 | 7.4e-3 | 2.7e-5 | 19.9 (3.2) | 0.71 | 15 |
| upstream 150 / 2 on VCXO (g≈0.7) | 2.6e-2 | 3.4e-4 | 70 (11) | 0.7 | — |

Main（`g_main_code ≈ 0.012`，admission 16 code；freq 模式另乘 `MPLL_FREQ_PRELOCK_GAIN_BOOST`）：

| 設定 (kp / ki / boost) | ω_n rad/s (Hz) | ζ | 死區 tics |
| --- | --- | --- | --- |
| 現況 +300 / +1 / 20 | 6.5 (1.0) | 0.26 | 218 |
| **F4a +1300 / +3 / 4** | 11.3 (1.8) | 0.64 | 50 |
| upstream 1100 / 30 on VCXO | ~270 (43) | ~1.3 | — |

Actuator：796 步/s、1.26 ms/步、4 write/步；相位加速度上限 6.6e5 tics/s²；fine range 1024 步；Slave 工作點 63,693（距 rail 29 步）；置中 bootstrap 3860。

## 附錄 B：建議的程式差異（每一行各屬一個工作包）

```diff
--- vendor/wrpc-sw/softpll/spll_helper.c            (F1)
-	s->pi.kp = -150;
-	s->pi.ki = -1;
+	s->pi.kp = -4500;
+	s->pi.ki = -8;

--- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd (F2)
-      STEP5_BOOTSTRAP_STEPS => 3388,
+      STEP5_BOOTSTRAP_STEPS => 3860,

--- vendor/wrpc-sw/softpll/softpll_ng.c              (F3a)
-#define STEP5_HELPER_PHASE_GUARD_TICS (60 * TICS_PER_SECOND)
+#define STEP5_HELPER_PHASE_GUARD_TICS (8 * TICS_PER_SECOND)

--- vendor/wrpc-sw/softpll/spll_main.c               (F4a)
-#define MPLL_FREQ_PRELOCK_GAIN_BOOST 20
+#define MPLL_FREQ_PRELOCK_GAIN_BOOST 4
-	s->pi.kp = 300;
-	s->pi.ki = 1;
+	s->pi.kp = 1300;
+	s->pi.ki = 3;

--- quartus/jtag_runtime_diag/si5340a_controller_dco.v (F4b)
    rt_state==3'd0：把「static_controller_ready && hpll_pending」分支移到
    「dpll_target/applied 殘差」分支之前；bootstrap/forced/burst 分支順序不變。

--- quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd (F5)
+      ENABLE_STEP5_ACTUATOR_IDENTIFICATION => 1,
-      ENABLE_STEP5_BOOTSTRAP => 0,
+      ENABLE_STEP5_BOOTSTRAP => 1,
+      STEP5_BOOTSTRAP_STEPS => <bracket 量到的零交越 − 512>,
+      STEP5_BOOTSTRAP_REVERSE => 1,
```

## 附錄 C：離線分析腳本（F0 用；Python 3 + numpy）

```python
# -*- coding: utf-8 -*-
# 用法：python helper_spectrum.py <coherent observer log>
# 對 FRAME_VALID=1 的 HELPER_ERROR 做過零週期 + FFT，並統計 HELPER_OUTPUT 工作點。
import re, sys, math, numpy as np
PAT = re.compile(r"elapsed_ms=(\d+) FRAME_VALID=(\d).*?HELPER_ERROR=(-?\d+) HELPER_OUTPUT=(\d+)"
                 r".*?HELPER_LOCKED=(\d)")
t, e, y, lk = [], [], [], []
for line in open(sys.argv[1], encoding="utf-8", errors="ignore"):
    m = PAT.search(line)
    if m and m.group(2) == "1":
        t.append(int(m.group(1)) / 1000); e.append(int(m.group(3)))
        y.append(int(m.group(4))); lk.append(int(m.group(5)))
t, e, y, lk = map(np.array, (t, e, y, lk)); e = e.astype(float)
print("samples", len(t), "span %.0f s" % (t[-1] - t[0]))
print("helper err rms %.0f  |e| p50/p90/p99/max %.0f/%.0f/%.0f/%.0f  |e|<=2000 %.1f%%" % (
    math.sqrt((e ** 2).mean()), *np.percentile(np.abs(e), [50, 90, 99]), np.abs(e).max(),
    100 * np.mean(np.abs(e) <= 2000)))
print("helper output mean %.0f p5 %.0f p95 %.0f  headroom to 65531: %.0f steps  rail %.1f%%" % (
    y.mean(), np.percentile(y, 5), np.percentile(y, 95), (65531 - y.mean()) / 64, 100 * np.mean(y >= 65531)))
print("locked fraction %.2f  unlock events %d" % (lk.mean(), int(np.sum((lk[1:] == 0) & (lk[:-1] == 1)))))
ib = np.abs(e) < 149999; zc = np.where(np.diff(np.sign(e[ib])) != 0)[0]
if len(zc) > 2:
    per = 2 * np.diff(t[ib][zc]); print("zero-crossing period median %.2f s (IQR %.2f-%.2f)" % (
        np.median(per), *np.percentile(per, [25, 75])))
dt = 0.1; tt = np.arange(t[0], t[-1], dt); ee = np.interp(tt, t, np.clip(e, -5000, 5000)); ee -= ee.mean()
F = np.abs(np.fft.rfft(ee * np.hanning(len(ee)))) ** 2; fr = np.fft.rfftfreq(len(ee), dt)
sel = (fr > 0.05) & (fr < 4.9); i = np.argmax(F[sel])
print("FFT peak %.3f Hz -> period %.2f s" % (fr[sel][i], 1 / fr[sel][i]))
```

在 9/12 3388 log 上的輸出：`FFT peak 0.672 Hz -> period 1.49 s`、`zero-crossing period median 1.45 s`、`helper output mean 63693`、`unlock events 22`；在 9/11 3372 log（`raw/observer-closedloop-3600-bootstrap3372.log`）上：`0.627 Hz`、`1.59 s`、`63081`、`188`（此腳本不濾 `MAIN_ENABLED`，樣本數比報告多，unlock 計數因此比報告的 152 高；頻率與工作點不受影響）。

## 附錄 D：證據索引（相對 repo 根目錄）

| 代號 | 路徑 | 用途 |
| --- | --- | --- |
| E1 | `docs/experiments/exp-step5-softpll-lock/EXP-WRPC-STEP5-HPLL-PLANT-ID-5632-20260909/REPORT.md`、`raw/bidir-4096.log` | g_step 0.216、796 步/s、方向 |
| E2 | `.../EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3388-CALCULATED-ZERO-CROSSING-20260912/REPORT.md`、`raw/observer-step5-bootstrap3388-20260912.log` | 首次 full chain 36 s、0.672 Hz、工作點 63,693 |
| E3 | `.../EXP-WRPC-STEP5-HPLL-BOOTSTRAP-3372-CALCULATED-ZERO-CROSSING-20260911/` | 0.627 Hz、152 次 unlock |
| E4 | `.../EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-KP-MINUS75-20260912/REPORT.md` 及 KP −125/−175、COOLDOWN 8/16/64、FRACTIONAL-KI 各報告 | ζ 0.03–0.08 區間內的無差別結果 |
| E5 | `.../EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-HELPER-PI-TRACE-20260912/`、`.../MAIN-PI-TRACE-20260912/` | 高側 clamp；Main phase err 7838 |
| E6 | `.../EXP-S5-SLOCK-POLL-CALIB-CAUSE-AUDIT-20260914/raw/startup-timeline.log` | Master helper 全程 rail；Slave 136.9 s tracking；update rate |
| E7 | `.../EXP-S5-MASTER-WR-DEADLINE-60000-20260914/REPORT.md`、`.../EXP-S5-WR-S-LOCK-TIMEOUT60-TIMELINE-9E5B53E-20260913/REPORT.md` | 拉 timeout 無效 |
| E8 | `.../EXP-S5-DCO-LIVENESS-20260912/REPORT.md`、`scripts/experiment/tb_dco_liveness.sv` | Main 餓死 Helper 的模擬 |
| S1 | `vendor/wrpc-sw/softpll/spll_common.c::pi_update / ld_update` | 定點 PI、detector 滯後 |
| S2 | `vendor/wrpc-sw/softpll/spll_helper.c` | kp/ki、threshold 2000/1000、reseed |
| S3 | `vendor/wrpc-sw/softpll/spll_main.c` | kp/ki、boost 20、±8192 mask、freq/phase detector |
| S4 | `vendor/wrpc-sw/softpll/softpll_ng.c:53, 238-321` | 60 s guard、READY→CLEAR_DACS |
| S5 | `quartus/jtag_runtime_diag/si5340a_controller_dco.v:842-935, 1005-1028` | 仲裁順序、half-step、forced reverse 語意 |
| S6 | `quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:1905-1924`、`DE5a_wr_master_jtag.vhd:1539-1548` | 兩板實際 generic |
| S7 | `vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/wr-constants.h`、`state-wr-s-lock.c`、`arch-wrpc/wrpc-spll.c` | 60 s×4 預算、retry 不重啟 SoftPLL、t24p |
| S8 | `quartus/jtag_runtime_diag/si5340a_i2c_reg_controller_dco.v:331-334` | `N_FSTEP_MSK=11100`、N0/N1 FSTEPW=128 |

本文採「已證明 / 模型推論 / 待測」分層：§2.3、§2.8、§2.10 是 raw 直接讀出；§2.2、§2.5–2.7、§2.9 是模型推論，F0/F1 的預期值就是它們的檢驗；§2.9 的 Main g 與 §2.10 的 Master 步數是待測估計。接手者先核對 HEAD 是否仍為 `7fc1a2d`；若有新實驗，先看它們是否已經做了 F1–F4 中的任何一項。
