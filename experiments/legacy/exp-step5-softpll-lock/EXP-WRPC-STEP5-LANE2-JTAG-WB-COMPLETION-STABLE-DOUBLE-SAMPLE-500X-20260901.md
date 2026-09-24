# EXP-WRPC-STEP5-LANE2-JTAG-WB-COMPLETION-STABLE-DOUBLE-SAMPLE-500X-20260901

## 結論

本輪依分支5建議，只修改 read-only Tcl mailbox reader：當 completion
`done_toggle`/`active` 首次成立後，不立即接受低 32-bit data，而是要求
完整 64-bit probe word 的 P1/P2/P3 連續三次一致，且每次的 completion
bits 都符合本次 request。

正式結果排除了單純的 probe visibility settling race：三次穩定取樣全部
成功，但仍有穩定且錯誤的 response。因此目前 blocker 已縮小為 request-side
或 mailbox transaction path instability。

```text
ITERATIONS = 500
TOTAL_WB_REQUESTS = 10000
TOTAL_PROBE_READS = 40001

INITIAL_COMPLETION_UNSTABLE_COUNT = 0
INITIAL_DATA_WRONG_BUT_STABILIZED_CORRECT_COUNT = 0
STABLE_RESPONSE_WRONG_COUNT = 92
PROBE_STABILIZATION_TIMEOUT_COUNT = 0
PROBE_2WAY_MATCH_COUNT = 10000
PROBE_3WAY_MATCH_COUNT = 10000
STABLE_TRANSACTION_COUNT = 10000
UNSTABLE_TRANSACTION_COUNT = 0

STATIC_SIGNATURE_MISMATCH = 42
BOARD_ID_MISMATCH = 50
ADDRESS_CROSS_CONTAMINATION_COUNT = 51
STALE_A5A5_COUNT = 0
TIMEOUT_COUNT = 0
INVALID_COUNT = 0

DMTD_REF_DECREASE_COUNT = 5
DMTD_FB_DECREASE_COUNT = 0
DMTD_REF_TRIPLE_VALID = 495
DMTD_FB_TRIPLE_VALID = 500

JTAG_PROBE_SETTLING_ONLY = REJECTED
REQUEST_OR_MAILBOX_TRANSACTION_PATH_INSTABILITY = CONFIRMED

V4_SMOKE = BLOCKED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

## Fixed conditions

```text
Board = DE5 [1-11.2]
QSFPA lane = 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

本輪沒有 rebuild、沒有 reprogram，也沒有修改 RTL、firmware、PI、WDIAGS
ownership、PHY、PTP 或 SoftPLL；沒有執行 V4 snapshot smoke。

## Stable completion result

每個 Wishbone request 採用：

```text
write request
    ↓
poll until done_toggle == expected and active == 0
    ↓
first completion probe P0
    ↓
probe P1
    ↓ 1 ms
probe P2
    ↓ 1 ms
probe P3
    ↓
accept only if full 64-bit P1 == P2 == P3
```

結果：

```text
P1/P2/P3 stable for every request = 10000 / 10000
PROBE_3WAY_MATCH_COUNT = 10000
PROBE_STABILIZATION_TIMEOUT_COUNT = 0
```

沒有任何 transaction 出現：

```text
P0 != P1 then stabilized correct
```

因此：

```text
INITIAL_COMPLETION_UNSTABLE_COUNT = 0
INITIAL_DATA_WRONG_BUT_STABILIZED_CORRECT_COUNT = 0
```

但在三次穩定取樣後仍有：

```text
STABLE_RESPONSE_WRONG_COUNT = 92
```

第一個穩定錯誤：

```text
iteration = 5
requested = STATIC_B (0x00100128)
expected = 0x22334402
stable_response = 0x00000000
classification = STABLE_RESPONSE_WRONG
```

## Remaining failure evidence

```text
STATIC_SIGNATURE_MISMATCH = 42
BOARD_ID_MISMATCH = 50
ADDRESS_CROSS_CONTAMINATION_COUNT = 51

DMTD_REF_DECREASE_COUNT = 5
DMTD_FB_DECREASE_COUNT = 0
```

這些錯誤不是因為 completion probe 在 P1/P2/P3 間尚未穩定，因為全部
10,000 個 request 都已通過完整 64-bit stable triple gate。這表示即使
probe word 已穩定，request address capture、Wishbone mailbox address
transaction，或 response/data 對應仍可能錯誤。

## 判定

分支5的 Case B 已成立：

```text
STABLE_RESPONSE_WRONG_COUNT > 0
```

因此：

```text
JTAG_PROBE_SETTLING_ONLY = REJECTED
REQUEST_OR_MAILBOX_TRANSACTION_PATH_INSTABILITY = CONFIRMED
```

本輪不能再靠增加 settle delay 解決，也不能把錯誤 stable response 當成
V4 ownership 或 Step5 PI 結果。

```text
V4_EXCLUSIVE_PI_BANK_DOUBLE_READ = NOT_RUN
V4_SMOKE = BLOCKED
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

下一輪應由分支5決定最小的 request/response provenance instrument，
例如加入 request address echo 或 transaction sequence；在 read path
可信前，不應修改 SoftPLL/PI，也不應 merge。

## Raw evidence

```text
docs/experiments/exp-step5-softpll-lock/raw/EXP-WRPC-STEP5-LANE2-JTAG-WB-COMPLETION-STABLE-DOUBLE-SAMPLE-500X-20260901.log
```
