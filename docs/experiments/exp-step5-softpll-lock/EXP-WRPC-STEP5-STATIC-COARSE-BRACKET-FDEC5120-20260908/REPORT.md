# EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC5120-20260908

## 結論

本輪原定測量 4096～6144 FDEC coarse bracket 之間的 5120-step 中點。source
已完成編譯並成功燒錄兩張 DE5a，但燒錄後四次 runtime preflight（包含一次
Master→Slave 同一 SOF 的重新燒錄）都未恢復 upstream link：兩張板的
`core_tm_link_up` 與 `core_link_ok` 仍為 0，Slave `spll_init_count` 也未啟動。

因此本輪沒有執行有效的 Step5 coarse observer，不能把結果解讀成 5120 工作點
的 Helper response，也不能據此否定 5120。這是 upstream/physical startup
regression，實驗在 Step1 邊界無效結束。

```text
STEP1_TO_STEP3 = INVALID_UPSTREAM
STEP4B = INVALID_UPSTREAM
STEP5 = NOT_APPLICABLE
STEP5_RESULT = BLOCKED_BY_UPSTREAM_STEP1
STEP5_FIRST_INACTIVE_BOUNDARY = UPSTREAM_STEP1
OBSERVER_EXECUTED = NO
MERGE_APPROVED = NO
```

## 版本與目標設定

```text
branch = exp/step5-softpll-lock
source_commit = 29525f370cd362fb4ca46ba8ca5d9de9014f54b6
bootstrap_steps = 5120
bootstrap_direction = FDEC (STEP5_BOOTSTRAP_REVERSE=0)
code_per_physical_step = 16
normal_hpll_tracker = 0
```

本輪 source 只將 static coarse bootstrap 設為 5120，並同步更新 observer 的
bootstrap guard 與實驗名稱；沒有修改 PI、lock threshold、DMTD、PTP、PHY 或
reset policy。

## Build 與 program

```text
SIMULATION_RC = 0
FIRMWARE_MASTER_RC = 0
FIRMWARE_SLAVE_RC = 0
COMPILE_MASTER_RC = 0
COMPILE_SLAVE_RC = 0
PROGRAM_MASTER_RC = 0
PROGRAM_SLAVE_RC = 0
PROGRAM_MASTER_RERUN_RC = 0
PROGRAM_SLAVE_RERUN_RC = 0
```

SOF SHA-256：

```text
MASTER = bf9634e3b5f7ac6819971ecebb06873dfa358d4ec91330eb969ecd72de382a4e
SLAVE  = 4353cb094124322b1b28a7c2314a6b1ddc5c15cde76a8bc62a577c997098e877
```

## Preflight 結果

初次燒錄後的 preflight 1、2、3，以及 Master→Slave 重燒後的 preflight 4，
均維持：

```text
STEP1_REGRESSION = FAIL
core_tm_link_up = 0/1
core_link_ok = 0/1
STEP4B_RESULT = BLOCKED_BY_STEP1
SLAVE_SPLL_INIT_COUNT = 0
JTAG_WB_DIAGNOSTIC_PATH = TRUSTED
```

JTAG/WB transport 本身仍為 trusted，沒有 timeout、stale response 或 address
cross-contamination；失敗是在實際 White Rabbit upstream link/startup，而非
JTAG 讀取通道。由於 Step1 未通過，沒有執行 1200-sample Step5 observer。

## 判讀與後續條件

本輪唯一可靠結論是：目前 Pain 在多次重編程後進入需要實體 power-cycle
才能排除的 cold/startup 狀態。不能把「未 lock」寫成 5120 的 actuator 結論。
在實體斷電重開並重新確認 Step1～4B PASS 前，不應繼續做 coarse 二分或改 PI；
否則會把 upstream 問題污染成控制器資料。

恢復後應從已推送的 `29525f3`（5120 image）重新開始，先做 Step1～4B settled
preflight，再決定是否重跑 5120 observer；若需要新的中點，仍以 4096、6144、
8192 已取得的有效資料為基礎。

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Raw evidence

- [raw archive](raw/EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC5120-20260908-UPSTREAM-REGRESSION.tar.gz)
- [archive SHA-256](raw/EXP-WRPC-STEP5-STATIC-COARSE-BRACKET-FDEC5120-20260908-UPSTREAM-REGRESSION.tar.gz.sha256)
- [initial preflight 1](raw/preflight-1.log)
- [initial preflight 2](raw/preflight-2.log)
- [delayed preflight 3](raw/preflight-3.log)
- [post-reprogram preflight 4](raw/preflight-4.log)
