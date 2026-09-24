# EXP-WRPC-STEP5-MAIN-FREQ-POLARITY-PLUS1100-PLUS30-STARTUP-FAIL-20260909

## 判定

本輪 **不是有效的 Main-frequency polarity A/B**，也不是 Step5 PASS；不具備 merge 到 `main` 的條件。

```text
Source polarity A/B             = NOT EVALUATED
Step1 PHY / Link                = FAIL
Step2 Endpoint / PTP            = NOT READY
Step3 WR Handshake              = NOT READY
Step4B Slave SoftPLL startup    = BLOCKED_BY_STEP1
Step5 Closed-loop Lock          = NOT EVALUATED
```

## 本輪原本目的

本輪 source 將 `CONFIG_WR_NODE` 下 Main frequency PI 的 `kp/ki` 從 `-1100/-30` 改為 `+1100/+30`，其餘 Helper threshold=2000、lock samples=1000、HPLL physical step=64、bootstrap=3360、cooldown=0 與 SI5340 runtime path 均保持不變。原定在 fresh boot 下觀察 Main frequency error 是否由 high-rail 狀態朝 0 移動。

Source commit：

```text
b25e77d4abf0ec6448a12354a6032ad68404338d
```

## 建置與燒錄

Pain 已 pull 該 commit，正式重建 Master/Slave firmware MIF 並完成 Quartus compile；Master、Slave 也都成功燒錄，program exit code 均為 0。

SOF SHA-256：

```text
Master 116a27ea2e83ec122f6c6eefdbd60f8643b2f64a8f7f08d28fa89d867d92b911
Slave  207632d25c527c65c696373b8078c690e51b3f68946fefc9d3d8b49b7400c8af
```

## Preflight 結果

燒錄後等待 55 秒執行第一次 preflight，結果：

```text
Master core_tm_link_up       = 0/1
Master core_link_ok          = 0/1
Master WDIAGS_PTP            = 3 DISABLED
Slave  core_tm_link_up       = 0/1
Slave  WDIAGS_PTP            = 4 LISTENING
Slave  parentIsWRnode        = 0/1
STEP4B_ALLOWED               = NO
STEP4B_RESULT                = BLOCKED_BY_STEP1
STEP5_RESULT                 = UPSTREAM_NOT_READY
```

等待額外 45 秒後再做一次 read-only preflight，結果完全相同：

```text
Master WDIAGS_PTP            = 3 DISABLED
Slave  WDIAGS_PTP            = 4 LISTENING
core link                    = 0/1
parentIsWRnode               = 0/1
STEP4B_RESULT                = BLOCKED_BY_STEP1
STEP5_RESULT                 = UPSTREAM_NOT_READY
```

CPU reset counter 雖然維持可見，但沒有恢復 PHY/光纖 link；因此沒有執行 Main observer，也沒有把本輪當成 polarity 結果。

## 解讀

這是一次 warm-program 後的 physical link recovery failure，不足以判斷 Main PI polarity。若把這輪的 `MAIN_FREQ_LOCKED=0` 當成 A/B fail 會污染實驗結論，故本報告將 polarity 判定保留為 `NOT EVALUATED`。

目前 Pain 必須先完成一次經授權的 power-cycle，讓兩張 DE5 的 PHY/光纖 link 回到可用狀態；恢復後應重新從 preflight 開始，並且在 link/Step4B PASS 後才執行 Main-frequency observer。

## Raw evidence

本輪 build、program、第一次 preflight、額外等待後的第二次 preflight，以及 source/SOF checksum 已保存於同資料夾的 `raw/`；同一份 raw archive 已保存於 `artifacts/`。
