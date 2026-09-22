# EXP-S6-WR-EXTENSION-AUTO-REARM-GLOBAL-TIME-20260922

## 結論

**PASS — WR extension auto-rearm 後 Global Time 可恢復並穩定運作。**

本輪修正後，Slave 不再永久停在 `PTP fallback`。燒錄後它先經歷正常的 startup/lock 過程，在約 70 秒時恢復 Global Time；之後持續超過 140 秒有效採樣，沒有再次退回 INVALID。

## 為什麼先前會等 120 秒

`GLOBAL_TIME_WAIT elapsed=.../120s` 是 `scripts/monitor/step1_6_dashboard.sh` 的主機端 presentation gate，由 `WAIT_FOR_GLOBAL_TIME_SECONDS=120` 明確啟用。它會等待所有可見板卡同時滿足：

```text
TIME_VALID=1
PPS_VALID=1
SNAPSHOT_VALID=1
SNAPSHOT_STABLE=1
TAI/CYCLES 可讀
```

它不是 FPGA 的 120 秒 timeout，也沒有對 FPGA 寫入或重置。先前 Slave 因 WR extension terminal fallback 沒有恢復，才把這個 host gate 等到 timeout。

## 真正根因

Slave 的 `WRS_S_LOCK` timeout 在原始程式中會呼叫 `wr_handshake_fail_reason()`；該路徑會：

1. 將 WR state 設成 `WRS_IDLE`；
2. 將 role reset 成 `WR_ROLE_NONE`；
3. reset WR servo；
4. disable WR extension、切到普通 PTP；
5. 清掉後續自動重新進入 `WRS_PRESENT` 所需的 parent context。

因此 SoftPLL/Step5 診斷可以仍然顯示 lock，但 `tm_time_valid_o` / PPS snapshot 永遠沒有重新建立。

## Source 修正

Commit：

```text
fb0d038bd4bbe5ffc37fcc4d5e441ede039bf5ca
```

修改檔案：

```text
vendor/wrpc-sw/ppsi/proto-ext-whiterabbit/common-fun.c
```

只對「仍有 WR parent 的 Slave `WR_S_LOCK_TIMEOUT`」保留 parent context，reset WR servo，重新設定 `PPS_UNCALIBRATED`，並重新啟用 extension；其他 handshake failure 維持原本 fallback。

## Build / program evidence

Pain 使用乾淨 worktree：

```text
/home/b10504072/step6-wr-rearm-fb0d038b
```

Source guard、Slave/Master firmware、兩份 Quartus JTAG compile 均成功：

```text
Full Compilation was successful
Slave TIMING_CLOSED=NO   (記錄但不作本輪 functional gate)
Master TIMING_CLOSED=NO  (記錄但不作本輪 functional gate)
```

SOF SHA-256：

```text
Slave  db8ec57f4b53b784585f83880774e5eb2a11069cbd8d3ef921eed4e1270de6a6
Master 45a671b75bacfc98859e97006098a59c3fed460a5186884439e41a0bec75de8f
```

Slave 與 Master programming 均為 Quartus `0 errors, 0 warnings`。

## Runtime timeline

### 燒錄後早期

```text
18:58:34  Master Global Time VALID
          Slave TIME_VALID=0, PPS_VALID=0, snapshot=0
18:58:44  Slave Helper/Main/PSTAT lock signals 已恢復為 1
          但 Global Time 尚未有效
18:59:44  Slave 仍在等待 Global Time
```

### 自動恢復

```text
18:59:54  Slave TIME_VALID=1, PPS_VALID=1
          SNAPSHOT_VALID=1, SNAPSHOT_STABLE=1
          TAI=125, CYCLES=124999999, snapshot count=8
```

### 穩定尾端

自 `18:59:54` 至 `19:02:04` 每 10 秒採樣均維持 Global Time VALID；最後一次唯讀 snapshot：

```text
MASTER  TIME_VALID=1 PPS_VALID=1 SNAPSHOT_VALID=1 SNAPSHOT_STABLE=1
        TAI=308 CYCLES=124999999 SNAPSHOT_COUNT=309

SLAVE   TIME_VALID=1 PPS_VALID=1 SNAPSHOT_VALID=1 SNAPSHOT_STABLE=1
        TAI=313 CYCLES=124999999 SNAPSHOT_COUNT=196
```

Slave 同時維持：

```text
Step1=PASS  Step2=PASS  Step3=PASS  Step4=PASS
HelperLock=1 MainFreq=1 MainPhase=1 MainLock=1 PSTAT=1
```

## Verdict

```text
WR_EXTENSION_AUTO_REARM = PASS
SLAVE_GLOBAL_TIME_RECOVERY = PASS
GLOBAL_TIME_STABLE_TAIL = PASS
STEP6A_GLOBAL_TIME = PASS
```

本輪沒有實體斷電、沒有修改 timing closure、沒有修改 Step5 control law。後續若要使用儀表板即時顯示，建議互動監控使用 `WAIT_FOR_GLOBAL_TIME_SECONDS=0`，讓 dashboard 立即顯示目前狀態；需要 strict one-shot gate 時才設定等待秒數。

