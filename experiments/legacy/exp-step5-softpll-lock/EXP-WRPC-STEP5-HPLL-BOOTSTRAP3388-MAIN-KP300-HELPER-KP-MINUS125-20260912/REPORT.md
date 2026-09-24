# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-KP300-HELPER-KP-MINUS125-20260912

## 結論

本輪 **未完成 Step5 判定**。第一次燒錄後兩張 DE5a 的 White Rabbit 光纖 Link 沒有建立；依既有 recovery procedure 重複以同一映像 programming 後，Link 與 Step4B 恢復，才取得有效的 Step5 觀測窗口。

有效窗口仍未通過 Step5：

```text
Initial cold-start preflight:
  Master: core_tm_link_up=0/1, core_link_ok=0/1
  Slave:  core_tm_link_up=0/1, core_link_ok=0/1
  Slave:  WDIAGS_PTP = LISTENING, LOCK_ENABLE=0
```

這個初次窗口是上游 PHY/Link prerequisite failure，不能用來評估 Kp；但 recovery 後已有獨立的有效 Step5 observer 結果，詳見下文。

更完整的結論是：冷啟動第一次 preflight 是 upstream blocker；recovery 後的 coherent run 是有效的 Kp=-125 結果，但 Helper hunting、Main/PSTAT 最終 lock 與 300 秒連續鏈仍未成立。

## 實驗目的

在上一輪 Main Kp=+300 已顯著改善 Main phase/full-lock 的基礎上，將 Helper proportional gain 從 `-150` 調整為 `-125`，測試是否能降低 Helper hunting/underdamped response，同時保留足夠 actuator authority。

本輪只修改：

```text
vendor/wrpc-sw/softpll/spll_helper.c
  CONFIG_WR_NODE: kp -150 -> -125
  ki 保持 -1
```

觀測器標籤與設定同步更新為 Main Kp=300、Helper Kp=-125；未修改 PHY、WR handshake、Step4 static FSM、DMTD、DCO target 或 Step5 判定語意。

## Git 與建置

```text
branch = exp/step5-softpll-lock
commit = 16b38ce495abc7d1adc03e2e5f7321c9a32c297e
```

Pain 已由 GitHub 拉取上述 commit。Master/Slave Quartus build 均成功，且 timing 仍為既有 `TIMING_CLOSED=NO` caveat。

```text
Master SOF SHA256 = 74a6ad553675ebcfd937adc38a6d6edcb4982c2996ae199d0a9084e20bd983e5
Slave  SOF SHA256 = 20fabc648a38a00fc8f484e51cfe9be2d7222f40d565898a83fa6e79912dabfc
```

## 燒錄

```text
Master DE5 [1-11.1] = success
Slave  DE5 [1-11.2] = success
```

燒錄順序為 Master，等待 45 秒，再燒錄 Slave；Quartus Programmer 回報兩張板各自 configuration succeeded、0 errors。

## Settled preflight（燒錄後等待 120 秒）

### Master DE5 [1-11.1]

上游靜態條件：

```text
si_config_done       = 1  PASS
wr_ready             = 1  PASS
wr_rx_ready          = 1  PASS
wr_tx_ready          = 1  PASS
CPU_RESET_n          = 1  PASS
wr_rx_locked_to_data = 1  PASS
```

但 Link gate：

```text
core_tm_link_up = 0/1  ERROR
core_link_ok    = 0/1  ERROR
```

Master 的本地 SoftPLL event chain 仍然運作：

```text
DMTD_REF_ACCEPT_EVENT = 22889
DMTD_FB_ACCEPT_EVENT  = 23496
DMTD_ACCEPT           = 46385
SPLL_TAG_VALID        = 23510
SPLL_TRR_WRITE        = 23512
SPLL_TRR_POP          = 25813
WDIAGS_IRQ            = 25812
HELPER_UPDATE         = 25813
BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET delta   = 0
SI_CONFIG_DROP delta  = 0
STEP4A_MASTER_EVENT_CHAIN = PASS
```

這表示本輪映像不是完全未執行；但 Master event chain PASS 不等於兩板 WR Link 已成立。

### Slave DE5 [1-11.2]

本地接收與 reset 基礎條件部分成立，但 upstream link 未成立：

```text
si_config_done       = 1  PASS
wr_ready             = 1  PASS
wr_rx_ready          = 1  PASS
wr_tx_ready          = 1  PASS
CPU_RESET_n          = 1  PASS
wr_rx_locked_to_data = 1  PASS
core_tm_link_up      = 0/1  ERROR
core_link_ok         = 0/1  ERROR
wr_rx_locked_to_ref  = 0  INFO/NA
WDIAGS_PTP           = LISTENING (raw=00004104)
WDIAGS_FOREIGN_META  = 0/1 and 255/0  ERROR
parentIsWRnode       = 0/1  ERROR
parentCalibrated     = 0/1  ERROR
LOCK_ENABLE          = 0/>0  ERROR
STEP4B_ALLOWED       = NO
STEP4B_RESULT        = BLOCKED_BY_STEP1
```

## 判定

```text
STEP1_REGRESSION = FAIL
STEP2_REGRESSION = INVALID
STEP3_REGRESSION = INVALID
STEP4A_RESULT    = PASS (Master local event chain only)
STEP4B_RESULT    = BLOCKED_BY_STEP1
STEP5_RESULT     = UPSTREAM_NOT_READY
```

第一次 preflight 的 `FAILURE_CLASSIFICATION=JTAG/DASHBOARD_MEASUREMENT_FAILURE` 描述的是冷啟動後的上游 Link/量測阻擋，不能拿來歸因於 Helper Kp=-125。recovery 後已取得有效 coherent 3600-snapshot Step5 observer，故本輪後半段可以正式評估 Kp=-125。

## Recovery 後 3600-snapshot coherent observer

```text
SAMPLES = 3600
COHERENT_MEASUREMENT_SNAPSHOTS = 3600
REJECTED_EPOCH_SNAPSHOTS = 0
REJECTED_ACCOUNTING_CANDIDATES = 104
MEASUREMENT_ACCOUNTING_FAILS = 0
POSITION_SNAPSHOTS = 3462
POSITION_INVARIANT_FAILS = 0
TRANSACTION_INVARIANT_FAILS = 0
DCO_TOTAL_LOWER_BOUND_FAILS = 0

FREQ_ERROR_MEAN = 0.999444444444
FREQ_ERROR_RMS = 10.4468230152
FREQ_ERROR_MIN = -120
FREQ_ERROR_MAX = 35

HELPER_ERROR_MEAN = -2749.52138889
HELPER_ERROR_RMS = 20626.9072427
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_200 = 0.050277777778
LOW_RAIL_FRACTION = 0.000277777778
HIGH_RAIL_FRACTION = 0.0258333333333
NO_RAIL_FRACTION = 0.973888888889

LOCK_COUNT_MAX = 1000
LOCK_COUNT_FINAL = 1000
LOCK_COUNT_RISE_EVENTS = 999
LOCK_COUNT_FALL_EVENTS = 645
ERROR_BAND_EXIT_EVENTS = 165
ACTUATOR_HUNT_OBSERVED = YES
HELPER_DYNAMICS = UNDERDAMPED_OR_OVERAGGRESSIVE

HELPER_LOCKED_SEEN = 404
HELPER_LOCKED_FINAL = 1
FIRST_HELPER_LOCK_SAMPLE = 11
MAIN_ENABLED_FINAL = 1
MAIN_FREQ_LOCKED_FINAL = 0
MAIN_PHASE_LOCKED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0

FULL_CHAIN_MAX_SECONDS = 9.987
FULL_CHAIN_300S = 0
STEP5_CHAIN_RESULT = NOT_COMPLETE
SPLL_DELOCK_COUNT_MAX = 239

RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
MEASUREMENT_COHERENCE = PASS
POSITION_ACCOUNTING = FAIL
RESET_STABLE = PASS
```

相較於上一輪同為 Main Kp=300、Helper Kp=-150 的有效結果，Kp=-125 沒有改善閉迴路：Helper RMS 由約 19589 上升至約 20627，high-rail 比例由約 2.14% 上升至約 2.58%，且 Main/PSTAT 在觀測末端由 lock 狀態掉出。故 `kp=-125` 應淘汰，不應作為下一個 baseline。

## 原始紀錄

遠端 Pain 初次 build/program/preflight 原始紀錄已打包並複製至本資料夾：

```text
raw-observer.tar.gz
SHA256 = 0227b756bb8baca9a9b82d1f03cb27d954fbb392fb1d3aa57731437084dba6c9
```

內容包含：

```text
preflight-step5-mainkp300-helperkp125-20260912.log
preflight-step5-mainkp300-helperkp125-20260912-settled120.log
build-step5-mainkp300-helperkp125-master-20260912.log
build-step5-mainkp300-helperkp125-slave-20260912.log
program-step5-mainkp300-helperkp125-master-20260912.log
program-step5-mainkp300-helperkp125-slave-20260912.log
```

Recovery programming、recovery preflight 與有效 3600-snapshot observer 已另行封存：

```text
raw-recovery-observer.tar.gz
SHA256 = bc1867e21764c4fdafb1675503aca6a66dcc777ce89921540ff76193175e884e
```

內容另包含：

```text
program-step5-mainkp300-helperkp125-recovery-master-20260912.log
program-step5-mainkp300-helperkp125-recovery-slave-20260912.log
preflight-step5-mainkp300-helperkp125-recovery-20260912.log
preflight-step5-mainkp300-helperkp125-recovery-20260912-settled120.log
observer-step5-mainkp300-helperkp125-20260912.log
```

## 下一步

下一輪應恢復 Helper Kp=-150 這個較佳 baseline，並仍先用 Master→45 秒→Slave recovery sequence 取得有效 settled preflight。不能再以 Kp=-125 掃描；下一個控制變數應改為小幅的 Helper 積分／更新速率控制，且每輪固定 Main Kp=300、bootstrap=3388、Ki=-1（若測更新速率則不與 Ki 同輪變更），以直接針對 hunting 與 long-run chain。

有效 settled preflight 必須確認：

```text
Master core_tm_link_up=1, core_link_ok=1
Slave  core_tm_link_up=1, core_link_ok=1
Slave  WDIAGS_PTP=SLAVE
Step3 PASS
Step4B_ALLOWED=YES
```

只有上游 gate 恢復後，才可執行下一輪有效 observer。Step5 PASS 仍必須同時滿足 Main/Helper/PSTAT lock、連續 300 秒 full chain、position accounting PASS、measurement coherence/accounting PASS，以及 reset delta 全為零。
