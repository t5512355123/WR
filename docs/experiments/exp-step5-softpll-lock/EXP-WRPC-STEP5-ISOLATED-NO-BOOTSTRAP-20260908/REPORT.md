# EXP-WRPC-STEP5-ISOLATED-NO-BOOTSTRAP-20260908

## 結論

本輪在已修正 DCO page/mask 的 source 上，將 Slave 的
`STEP5_BOOTSTRAP_STEPS` 設為 `0`，保留其餘 Step5 tracker、PI、lock detector、
static-FSM gate、reset tree 與 upstream 設定不變。目的在於確認 Helper 是否能
從無 bootstrap 的靜態起點自行找到可達 operating point。

```text
MASTER_BUILD = PASS
SLAVE_BUILD = PASS
MASTER_PROGRAM = PASS
SLAVE_PROGRAM = PASS
STEP1_TO_STEP3 = PASS (可信 preflight 2)
STEP4B = PASS (可信 preflight 2)
STEP5 = NOT_PASS
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

無 bootstrap 並未讓 Helper 進入 lock。120 秒內正常 tracker 確實持續完成
`4,938` 次 DCO transaction，但 `HELPER_ERROR` 仍主要飽和在 `-150000`，
`HELPER_OUTPUT` 接近上限 `65535`，最後 `HELPER_LOCKED=0`。因此 Step5 仍不能
宣告完成，也沒有 merge。

## 版本、編譯與燒錄

- Branch：`exp/step5-softpll-lock`
- Source commit：`40cb3eacb1f50bdff2a96fbd8e587ab8885c61cb`
- 唯一 functional variable：Slave `STEP5_BOOTSTRAP_STEPS: 6208 -> 0`
- 編譯：pain，Quartus Prime Pro 21.3 flow；firmware 與 full Quartus 均成功
- 燒錄：Master `DE5 [1-11.1]`，等待 46 秒後 Slave `DE5 [1-11.2]`
- 兩板 Programmer：成功，0 errors、0 warnings

SOF SHA-256：

```text
Master 1019a78d65d036b082ccb905e181da054aa159dae14023458cca1ccdccfa2f88
Slave  35c34ed9a9d4ce296aa26717d7a544578e2811797367592803c8d412938a9dea
```

Fitter 成功，但 timing 尚未 closed：Master worst setup slack `-0.246 ns`、
Slave `-0.105 ns`。這是 implementation caveat，本輪沒有把它誤判為 Step5
lock failure 的唯一原因。

## Preflight 結果

燒錄後第一個窗口是已知 startup transient；Slave Step2 invalid，Step4B 被
上游條件阻擋。等待後的 preflight 2 通過 upstream 與 Step4B：

```text
STEP1_REGRESSION = PASS
STEP2_REGRESSION = PASS
STEP3_REGRESSION = PASS
STEP4B_ALLOWED = YES
STEP4B_RESULT = PASS
STEP4B_FIRST_INACTIVE_BOUNDARY = ACTIVE
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

這表示本輪修改沒有破壞 PHY/link、Endpoint/PTP、WR handshake 或 Step4B 的
SoftPLL event chain；Step5 的第一個可靠失敗邊界仍是 Helper lock。

## 120 秒 Helper 收斂觀測

Slave 執行 1200 samples、100 ms gap；完整 raw output 保存在 `raw/`：

```text
SAMPLES = 1200
VALID_FRAMES = 1171
INVALID_FRAMES = 29
WINDOW_SECONDS = 119.900
HELPER_LOCK_COUNT_MAX = 10
HELPER_LOCK_COUNT_FINAL = 10
HELPER_LOCKED_SEEN = 0
HELPER_LOCKED_FINAL = 0
HELPER_ERROR_MEAN = -142321.905209
HELPER_ERROR_RMS = 148868.139927
HELPER_ERROR_MAX_ABS = 150000
FRACTION_ABS_ERROR_LE_THRESHOLD = 1.19555935098
HELPER_OUTPUT_RAIL5_FRACTION = 1.36635354398
HELPER_ERROR_PLUS150000_FRACTION = 1.70794192997
MAIN_ENABLED_FINAL = 0
MAIN_LOCKED_FINAL = 0
PSTAT_LOCKED_FINAL = 0
NORMAL_REQ_DELTA = 4938
NORMAL_COMPLETED_DELTA = 4938
DCO_STEP_DELTA = 4938
FORCED_ACTIVITY_DELTA = 0
BOOTSTRAP_COMPLETED_DELTA = 0
BOOTSTRAP_DONE_FINAL = 0
RESET_BOOT_GENERATION_DELTA = 0
RESET_CPU_DELTA = 0
RESET_WR_CORE_DELTA = 0
RESET_SI_CONFIG_DELTA = 0
NORMAL_TRANSACTION_ACCOUNTING = PASS
```

`FRACTION_ABS_ERROR_LE_THRESHOLD` 的數值是百分比型輸出，約等於 `1.20%`，
不是可解讀為 lock 的比例；Helper lock 本身仍為 0。正常交易 accounting PASS，
表示 DCO bus pipeline 在無 bootstrap 模式下有工作，但 actuator movement 沒有
把量測誤差帶入 lock window。

## 與前兩輪的對照與判斷

```text
normal bootstrap=6208, forward : error 約 +150000, output rail 5
reverse bootstrap=6208          : error mean +82793.9, rail 約 77.6%
no bootstrap=0                   : error mean -142321.9, output 接近 65535
```

這三輪共同證明：

1. DCO page/mask 修正後，runtime DCO transaction 可在硬體上完成。
2. `STEP5_BOOTSTRAP_REVERSE` 確實能改變 error 方向，所以 polarity 不是未接線的
   假象。
3. bootstrap 的絕對步數會改變 operating point，但 `0`、`+6208`、`-6208`
   都沒有進入 Helper lock；單純延長等待或盲調 PI 尚無充分依據。
4. 本輪未發生新增 boot generation、CPU、WR core 或 SI configuration reset，
   因而不是 static-FSM false restart 回歸。

## Step5 判定

```text
STEP5_COMPLETE = NO
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
MERGE_APPROVED = NO
```

## 下一輪建議

依 `Astra建議.md` 的 operating-point 優先原則，下一輪不應再把 PI 參數當成
第一變因。應先保留目前 page/mask fix，加入一個可重現、有限幅度且可觀測的
coarse operating-point sweep／絕對 DCO position accounting：每次 fresh program
只改一個受控 bootstrap position，量測 Helper error、output、DCO completed 與
direction；先找出 error 由正到負或由飽和進入可達區的 bracket，再在 bracket
內做細掃。若所有安全位置仍飽和，下一步應把 ACK、方向、applied position 與
Helper error 同窗記錄，優先檢查 Main absolute target／pending-step drain
語意，而不是繼續調 PI。

完整 build、program、preflight、120 秒觀測與 SHA256 evidence 均保留在
`raw/`（遠端封存 tar SHA-256：
`e86175653aaa61aa16b73ee790c5a5dc03bb1cbfbef2e5c01a4958b30330c919`）。
