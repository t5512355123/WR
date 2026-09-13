# EXP-S5-OBSERVER-MAIN-DECODE-FIX-STARTUP-ARM-7CF2375-20260913

## 結論

本輪是為了恢復燒錄後的 startup 前置條件，`STEP5 = NOT COMPLETE`，沒有進入 Step5 觀測。

既有 shell-ready-gated reader 沒有送出 `mode master`，因為 Master 的 generation gate 不成立；Slave 端在 gate 不成立時沒有自己的總 timeout，持續取樣到約 `529 s`，因此手動中止。這是 startup/setup failure，不是新的 SoftPLL 功能性結果。

## 實驗身分

- Branch: `exp/step5-softpll-lock`
- Source commit: `7cf2375189b5e0b525687516074a598ccac92add`
- Board pair: `DE5 [1-11.1]` Master、`DE5 [1-11.2]` Slave
- Trial: `EXP-S5-OBSERVER-MAIN-DECODE-FIX-STARTUP-ARM-7CF2375-20260913`
- Reader: `read_fixed_image_shell_ready_gated_runtime_retest.tcl`
- Requested ready timeout: `30000 ms`
- Requested stable gate: `1500 ms`
- Master injection: `未發生`
- Reader termination: 手動中止；未取得正常 exit summary

## 關鍵證據

Master 在 gate timeout 前已有部分 marker：

```text
POST_STARTUP_ARMED=1
STARTUP_READY_FINAL=1
PERSIST_CMD_STAGE=00000005
FIRMWARE_MAIN_LOOP_REACHED=00000004
SHELL_POLL_LOOP_REACHED=00000002
BOOT_INIT_SEQUENCE_DONE=00000001
FIRMWARE_SHELL_READY=000004D9
BOOT_GENERATION=00000001
FIRMWARE_MAIN_LOOP_GENERATION=00000000
SHELL_POLL_GENERATION=00000001
BOOT_INIT_GENERATION=00000000
GENERATION_MATCH=0
GATE=0
RUNTIME_IDLE=0
```

因此 reader 正確輸出：

```text
SHELL_READY_GATED_INJECT_SKIPPED board=DE5 [1-11.1]
reason=gate_timeout_or_nonidle
```

Master 沒有收到 `mode master`，所以不能期待 Slave 建立 WR link。

Slave 端在 startup-arm log 的後段仍反覆顯示：

```text
FIRMWARE_MAIN_LOOP_REACHED=00000000
SHELL_POLL_LOOP_REACHED=00000000
BOOT_INIT_SEQUENCE_DONE=00000000
FIRMWARE_SHELL_READY=00000000
GENERATION_MATCH=0
GATE=0
RUNTIME_IDLE=1
```

## 判定

- Shell-ready reader transport: `UNRESOLVED_BY_MANUAL_ABORT`
- Master mode-master stimulus: `NOT SENT`
- WR core link: `NOT TESTED`
- SoftPLL startup: `NOT TESTED`
- Step5: `NOT COMPLETE`

本輪不能把沒有 mode-master 刺激的被動 Slave 狀態，解讀成 WR 或 SoftPLL failure。

## 診斷與下一步

目前需要先恢復乾淨的 boot-generation contract：

1. 讓 Master/Slave 都從真正的 cold boot 開始，使 `FIRMWARE_*_GENERATION` 與 `BOOT_GENERATION` 一致。
2. 重新執行 shell-ready gate，確認 Master 實際出現 `SHELL_READY_GATED_STIMULUS_SENT` 與 `COMMAND_DISPATCH_SUCCESS`。
3. 再用已修正的 `read_step5_startup_timeline_first_divergence.tcl` 做 60 秒 smoke；smoke 通過後才進 600 秒觀測。

在 startup gate 恢復前，不修改 PI、timeout、bootstrap、guard、arbiter 或 WR handshake。

## 原始檔案

- `raw/startup-arm.log`
