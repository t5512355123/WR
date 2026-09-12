# EXP-WRPC-STEP5-HPLL-BOOTSTRAP3388-MAIN-KP300-HELPER-KP-MINUS125-20260912

## 結論

本輪 **未完成 Step5 判定**。程式碼已成功編譯並燒錄，但燒錄後兩張 DE5a 的 White Rabbit 光纖 Link 沒有建立：

```text
Master: core_tm_link_up=0/1, core_link_ok=0/1
Slave:  core_tm_link_up=0/1, core_link_ok=0/1
Slave:  WDIAGS_PTP = LISTENING, LOCK_ENABLE=0
```

因此這不是 Helper Kp=-125 的有效閉迴路結果，而是上游 PHY/Link prerequisite failure。Step4B 與 Step5 均不可判定。

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

`FAILURE_CLASSIFICATION=JTAG/DASHBOARD_MEASUREMENT_FAILURE` 所描述的是本次診斷的上游 Link/量測阻擋；本輪沒有足夠條件把失敗歸因於 Helper Kp=-125，也沒有執行 coherent 3600-snapshot Step5 observer，避免在 invalid upstream 上產生誤導性的控制器結論。

## 原始紀錄

遠端 Pain 原始紀錄已打包並複製至本資料夾：

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

## 下一步

本輪不能做 gain 選擇。下一輪應先處理「兩板 Link 未建立」這個硬體/啟動前置條件，並以 settled preflight 重複確認：

```text
Master core_tm_link_up=1, core_link_ok=1
Slave  core_tm_link_up=1, core_link_ok=1
Slave  WDIAGS_PTP=SLAVE
Step3 PASS
Step4B_ALLOWED=YES
```

只有上游 gate 恢復後，才可重新執行同一個 `Main Kp=300 / Helper Kp=-125` 映像的 coherent observer，並與前一輪 Helper Kp=-150 進行有效 A/B 比較。Step5 PASS 仍必須同時滿足 Main/Helper/PSTAT lock、連續 300 秒 full chain、position accounting PASS、measurement coherence/accounting PASS，以及 reset delta 全為零。
