# EXP-WRPC-SLAVE-DIVIDE-ONLY-FRESH-20260824

## 實驗基本資料

- 實驗名稱：Slave-only SoftPLL input divide A/B
- 日期：2026-08-24
- Git branch：`exp/step4-slave-divide-only-fresh`
- Git commit：`5d5603b761c805636561257dfed80655cf2aa7aa`
- control reference：`48ba8b1889ad1f0f69ade899fe241f0205f667d0`
- 實驗目的：在不改變 Master role、PTP、WR signaling、reverse DMTD 或其他 SoftPLL 演算法的情況下，只將 Slave 的 `g_softpll_divide_input_by_2` 設為 false，確認是否能改善 Step 4 deglitch acceptance。

## 唯一 functional 變因

```text
Master: g_softpll_divide_input_by_2 = true  (default/control)
Slave : g_softpll_divide_input_by_2 = false (本次唯一變更)
兩片  : g_softpll_reverse_dmtds = false
```

Generic plumbing 的 default 保持 true；Master top 沒有加入 explicit override。除了上述 Slave-only divider 外，本次沒有修改 PTP、WR signaling、SoftPLL 演算法、DDMTD polarity、PI gain、lock threshold、DCO、SI5340 或 PHY functional behavior。

## Fresh build provenance

- Quartus：17.0.0 Build 595 / Standard Edition
- Master MIF SHA256：`8474a975cfb42733eeac09e72789f7d9a4b30caf70cc9af93a4bec9f1ec259fd`
- Slave MIF SHA256：`7bd04c5208d24076e5c0f4459edcd4fd4d5182be6bada431c43af2a49ab1cccf`
- Master QSF SHA256：`cc01fa4279bea7f1daf02f1b573410978240aca1bf83abcb686af0be41f1073f`
- Slave QSF SHA256：`c46689ce5573bea68af569fe3062d07043b306c7258e443f962a5ed496442437`
- Master / Slave SDC SHA256：`b6a17ee37da9242677c038f3e18ec4251c38727515002a1bf2a83f39ee88d9b8`
- Master SOF SHA256：`fa1e89533accc1508b671eb8c4681e96e09849d8221f7df60d5522f425d09a75`
- Slave SOF SHA256：`fca68f17e3017446be5407033b48d8ddf300594931af44fec6cbf0f3436012d0`
- Master programmer checksum：`0x30AA3EE5`
- Slave programmer checksum：`0x30AE0D80`
- Master / Slave Quartus build：Fitter 成功，`timing_closed=NO`

## 燒錄結果

Master 使用 `DE5 [1-11.1]`，Slave 使用 `DE5 [1-11.2]`。兩片均回報：

```text
Configuration succeeded -- 1 device(s) configured
Quartus Prime Programmer was successful. 0 errors, 0 warnings
```

因此後續結果確實來自本 commit 的 fresh SOF，而不是上一輪 control SOF。

## Step 2 / Step 3 focused regression

### 第一次：燒錄後等待 30 秒，30 samples / 500 ms

Master：

- accepted：16/30，invalid：14
- valid sample 中 MAC=`02:00:22:33:44:01`、MODE=`2`
- PTP 在 `1/4` 間變動，未到穩態 `6`
- PTP_TX delta=`27`，但 valid window 不完整
- 結果：`STEP2_REGRESSION=FAIL`

Slave：

- accepted：20/30，invalid：10
- valid sample 中 MAC=`02:00:22:33:44:02`、MODE=`3`
- PTP 在 `1/4/6` 間變動，PTP RX 幾乎沒有活動
- FOREIGN、parent flags、WR RX/TX、LOCK、LOCK_ENABLE、RCER 都未建立
- 結果：`STEP2_REGRESSION=INVALID`、`STEP3_REGRESSION=FAIL`

### 第二次：再等待 60 秒，20 samples / 500 ms

Master：

- accepted：9/20，invalid：11
- MAC / MODE 仍可在 valid sample 讀到正確值
- PTP=`1/4`，PTP_TX delta=`0`
- 結果：`STEP2_REGRESSION=FAIL`

Slave：

- accepted：14/20，invalid：6
- PTP=`1/4/6`，PTP_RX=`0`
- FOREIGN、parent flags、WR RX/TX、LOCK、LOCK_ENABLE、RCER 都未建立
- 結果：`STEP2_REGRESSION=INVALID`、`STEP3_REGRESSION=FAIL`

## 判定

```text
STEP1_REGRESSION = OBSERVED_HEALTHY_ON_ACCEPTED_STATUS
STEP2_REGRESSION = FAIL/INVALID
STEP3_REGRESSION = FAIL
STEP4_ALLOWED     = NO
STEP4_RESULT      = NOT_MEASURED
```

## Observation

這個 Slave-only divider build 沒有通過 Step 2/3 regression barrier，因此沒有執行 Step 4 T0/T1；這是有意識的停止，不是漏測。

與 control recovery 的 30/30 valid、Master PTP=6、Slave PTP=9、Foreign/parent/LOCK/LOCK_ENABLE=4 相比，本次在等待 30 秒與 90 秒後仍反覆出現 invalid mailbox status、PTP 不穩定、Slave 沒有 Foreign Master 與 signaling evidence。Tcl 腳本本身兩次都正常結束且回報 0 errors/0 warnings，所以「腳本無限卡住」不是本輪的主要問題；但 invalid read 仍表示部分 sample 不能作硬體結論。

## Conclusion

目前證據支持：

1. `Slave divide=false` 這個 build 破壞了原本 fresh control image 的 Step 2/3 runtime regression。
2. 因為 Step 2/3 barrier 失敗，不能宣稱 divider 改善 Step 4，也不能把 Step 4 counter 解讀成成功或失敗。
3. 這輪同時存在 JTAG invalid measurement evidence 與 accepted sample 中的真實 PTP/parent 缺失；因此不能只把現象歸因於 JTAG，也不能只憑 invalid raw value 宣稱 FPGA 根因已確定。

```text
HARDWARE_FIRMWARE_FAILURE = NOT_FULLY_ISOLATED
JTAG_MEASUREMENT_FAILURE  = PRESENT
ROOT_CAUSE                = NOT_PROVEN
```

## 原始證據

- Programmer：`raw/EXP-WRPC-SLAVE-DIVIDE-ONLY-20260824/master-program.log`
- Programmer：`raw/EXP-WRPC-SLAVE-DIVIDE-ONLY-20260824/slave-program.log`
- Firmware build：`raw/EXP-WRPC-SLAVE-DIVIDE-ONLY-20260824/master-firmware-build.log`
- Firmware build：`raw/EXP-WRPC-SLAVE-DIVIDE-ONLY-20260824/slave-firmware-build.log`
- Master Quartus build：`raw/EXP-WRPC-SLAVE-DIVIDE-ONLY-20260824/master-quartus-build.log`
- Slave Quartus build：`raw/EXP-WRPC-SLAVE-DIVIDE-ONLY-20260824/slave-quartus-build.log`
- 第一次 Step 2/3 barrier：`raw/EXP-WRPC-SLAVE-DIVIDE-ONLY-20260824/step23-30x500.log`
- 第二次 Step 2/3 retest：`raw/EXP-WRPC-SLAVE-DIVIDE-ONLY-20260824/step23-retest-20x500.log`

## Next Step

停止 Step 4 functional experiment，回到 fresh control source，重新燒錄 control SOF 並確認 Step 2/3 恢復。之後先做 source audit，釐清 Slave divider 影響 PTP/WR parent startup 的路徑；下一個功能變因必須在恢復 control regression 後重新定義，不能直接再疊加第二個變因。
