# EXP-WRPC-STEP4-FRESH-3F02966-20260825

## 實驗基本資料

- Experiment ID：`EXP-WRPC-STEP4-FRESH-3F02966-20260825`
- 日期：2026-08-25
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- FPGA source/build commit：`3f0296619acea825adb7de4945104b0a75f74843`
- 後續 read-only dashboard validator commit：`3050cba9a7abdb1e71207e3a8fffb589fb11ef2c`
- 實驗類型：exact fresh SOF provenance + Step 2/3 regression + Step 4 read-only observation

## 實驗目的

上一輪在未知或舊 FPGA image 上讀到 `WAIT_STABLE0_MAX_STAB >= threshold`，但不能證明那是最新 candidate image。本輪唯一變因是把兩片 FPGA 燒錄成 exact `3f02966` clean build 產生的 Master/Slave SOF，然後沿用相同的 Step 2、Step 3、Step 4 read-only scripts。

本輪沒有修改 Master/Slave role、PTP、WR signaling、SoftPLL algorithm、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。

## Fresh build provenance

Quartus：`Version 17.0.0 Build 595 04/25/2017 SJ Standard Edition`

| 項目 | Master | Slave |
|---|---|---|
| Project | `DE5a_wr_master_jtag` | `DE5a_wr_slave_jtag` |
| MIF SHA256 | `f6ffe5f7a1189dbb3c12ecd087aab78eb904468cbe4e37b1ee6cf2328dd17347` | `beb96f8ac9a77dae1b4919101efe6713e795e639ce7c6b64d551b16011971d96` |
| QSF SHA256 | `cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f` | `c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437` |
| SDC SHA256 | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` | `b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8` |
| SOF SHA256 | `1698557faf930bf476ed7cd8390859e868234de64fbb7857a7a8afe853bf034e` | `f303b92134af2f672128013a846ed910b5b8f9858fca6db537af0fab2acfc8b5` |
| Programmer checksum | `0x30B09137` | `0x30B3D6F4` |

兩邊 clean Quartus compile 均顯示 `Full Compilation was successful`。此 build 的 timing summary 為 `TIMING_CLOSED=NO`；本輪不把 timing status 與 Step 4 runtime gate 混為一談，但保留作 provenance。

## 燒錄結果

Master 使用 cable `DE5 [1-11.1]`，Slave 使用 cable `DE5 [1-11.2]`。

兩次 programmer output 均包含：

```text
Configuration succeeded -- 1 device(s) configured
Successfully performed operation(s)
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

因此本輪確實是 fresh exact SOF 的硬體實驗，不是 historical SOF 或未知 image 的推論。

## Step 2 / Step 3 regression

### Step 2

Master：

- MAC：`02:00:22:33:44:01`
- `MODE=2 MASTER`
- `PTP=6 MASTER`
- PTP RX/TX 與 MiniNIC TX/RX counters 有活動
- `RXERR delta=0`

Slave：

- MAC：`02:00:22:33:44:02`
- `MODE=3`
- `PTP=9`
- PTP RX/TX 與 MiniNIC TX/RX counters 有活動
- `RXERR=0`
- reliability sampling：`valid=10 invalid=0`

結果：`STEP2_REGRESSION = PASS`

### Step 3

30-sample focused sampling：

- `valid_samples=30`
- `invalid_samples=0`
- `counter_decreased=0`
- `FOREIGN=1/0`
- parent is WR：`1`
- parent calibrated：`1`
- RX WR message：`0x1001`，count `>0`
- TX WR message：`0x1000`，count `>0`
- `LOCK_ENABLE=4`
- `RCER=0x00000001`

reliability script 也得到 `STEP3_INDEPENDENT result=PASS`。但 live WR state 仍為 `local_state=0 / next_state=0`，所以保留：

```text
STATE_EVIDENCE=READ_INCONSISTENT
POST_STEP3_LOCK_STAGE=TIMEOUT
```

這不被解讀成 Step 3 functional failure，也不被解讀成 SoftPLL 已 lock。

結果：`STEP3_REGRESSION = PASS`

## Step 4 read-only 結果

### 固定狀態與通道

兩板的 focused series 都是有效讀值：

- `SPLL_MODE_SEQUENCE=0x00030009`
- `RCER=0x00000001`
- `OCER=0x0F189001`
- DMTD reference/feedback event registers 本身有固定值，但觀測窗口內 delta 為 `0`

`OCER=0x0F189001` 證明 OCER 不是 8-bit 值；因此後續 dashboard commit `3050cba` 移除不正確的 `<=0xFF` validator 限制。這是 read-only measurement validation 修正，不是 FPGA functional change。修正後 dashboard 將 OCER 正確標成有效。

### Functional WAIT_STABLE_0 max

`threshold=1000`。

```text
Master REF max_stab = 33
Master FB  max_stab = 0
Slave  REF max_stab = 196
Slave  FB  max_stab = 0
```

所有值都小於 `1000`，因此 fresh image 中沒有觀察到 functional state-gated `stab_cntr` 累積到 qualification threshold。

### Event chain

兩片板的 50-sample focused result 都顯示：

```text
WAIT_EDGE_ENTRY = 0
GOT_EDGE_ENTRY  = 0
PRE_ACCEPT      = 0
ACCEPT          = 0
TAG/TRR         = 0
IRQ             = 0
HELPER_UPDATE   = 0
STATE_TRANSITION= 0
```

同時 native/DMTD sampled counters 持續增加，代表 clock/sample 前級有 activity。source-backed boundary 因此收斂為：

```text
native sampled activity
        -> WAIT_STABLE_0
        -> functional stab_cntr qualification
        -> WAIT_EDGE_ENTRY = 0
        -> GOT_EDGE / ACCEPT / TAG / TRR / IRQ / HELPER = 0
```

腳本另有 `QUALIFICATION_ABORT_AFTER_GOT_EDGE` 的 coarse boundary 訊息；它與 functional max counter 的低值同時存在時，仍不能把其他 D0-side hit/abort counter 當成 functional `stab_cntr` 已達 threshold 的證明。

結果：`STEP4_RESULT = NOT_PASS`

## 總結

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4_ALLOWED    = YES
STEP4_RESULT     = NOT_PASS
ROOT_CAUSE       = qualification counter did not reach threshold in fresh image
```

本輪已排除「只是燒到未知舊 image」這個主要疑問。現有 evidence 支持：fresh image 的 native sampled activity 存在，但 functional `WAIT_STABLE_0` qualification 沒有累積到 `threshold=1000`，所以 Step 4 downstream event chain 沒有啟動。

本輪尚不能宣稱根因是 threshold、clock quality、polarity、FSM bug 或其他 SoftPLL functional 原因；本輪沒有修改這些行為。

## 原始證據

原始 programmer、build provenance、Step 2/3/4 與 dashboard logs 位於：

`docs/experiments/exp-step4-softpll-enable/raw/20260825-fresh-3f02966-program/`

