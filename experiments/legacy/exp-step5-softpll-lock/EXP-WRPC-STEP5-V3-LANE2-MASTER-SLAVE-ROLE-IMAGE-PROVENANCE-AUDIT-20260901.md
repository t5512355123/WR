# EXP-WRPC-STEP5-V3-LANE2-MASTER-SLAVE-ROLE-IMAGE-PROVENANCE-AUDIT-20260901

## 判定

```text
ROLE_IMAGE_PROVENANCE = PASS
V3_PREFLIGHT_REVALIDATED = YES
V3_ATOMIC_SNAPSHOT_SMOKE = NOT_RUN
EXPERIMENT_VALID_FOR_STEP5 = NO
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```

本輪依分支 5 的建議，只驗證 Master/Slave image、MIF、SOF、JTAG cable 與 boot role 的 provenance；不修改功能碼、不改控制參數、不執行 V3 100-sample smoke、不執行 1800 秒 observer。

## 固定條件

```text
branch = exp/step5-softpll-lock
functional source commit = 493b54b757cb0473e1c0e070f6db3ee7ad9852fa
QSFPA data path = lane 2
bootstrap = 6176
code_per_physical_step = 64
kp = -150
ki = -1
threshold = 200
lock_samples = 10000
```

Build 完成後，pain 再 fast-forward 到 GitHub 最新的 `f7139aee6b5f491359745726e79a0f39fc59d5ce`；該 commit 只有前一輪報告，沒有功能碼差異。

## Build provenance

兩份韌體與 Quartus image 均重新 clean build 成功；build log 分別使用 role-specific defconfig：

```text
Master: de5a_master_defconfig
        CONFIG_INIT_COMMAND="mode master;vlan off;ptp stop;ptp start"
Slave:  de5a_slave_defconfig
        CONFIG_INIT_COMMAND="vlan off;ptp stop;mode slave;ptp start"
```

| artifact | SHA-256 |
|---|---|
| `firmware/configs/de5a_master_defconfig` | `01e63d6878772d9f8e9e3328dd003da9e18a93a5fac930f8cfd0bf6186b2ca2a` |
| `firmware/configs/de5a_slave_defconfig` | `1e66ef063512fd6cd64d21eafec602ac5d4a520627d46c6f8f6529286b7e0b7e` |
| `firmware/configs/de5a_master_identity.h` | `c8c8fbaf4c1a7b99c4cad7491a9134e4e0d698ac068b894d5a0ee2d18c06f692` |
| `firmware/configs/de5a_slave_identity.h` | `33ded2dc62811525a395d12a5a396dda1553339119eba2f37c86cf8cf4639d55` |
| `build/firmware/master/wrc.mif` | `113964ac258776c3ba1cef0792302b2eb144c7e3592c3f2bc8b90472426cc648` |
| `build/firmware/slave/wrc.mif` | `ed33c95cb9ab869837e7bb1170570263ac7229c81a8a022ccd4bdabd564d0440` |
| `DE5a_wr_master_jtag.sof` | `adea7e52d77f48098ba1e5bd2dcde31f6b74e4d9bf1c5a4e3db2515e333fd1a6` |
| `DE5a_wr_slave_jtag.sof` | `06bfb52aba02a82cd72691c8e4a99b9ad3bf164017e017d0784399bcfc0c6516` |

The Master/Slave MIF and SOF hashes are distinct. Quartus compilation succeeded for both images; `TIMING_CLOSED=NO` remains an implementation caveat and was not changed in this audit.

## Programming provenance

The Slave was programmed first, without programming the Master during the first decision point:

```text
PROGRAMMED_CABLE = DE5 [1-11.2]
PROGRAMMED_SOF = quartus/jtag_runtime_diag/output_files_slave_jtag/DE5a_wr_slave_jtag.sof
PROGRAMMER_CHECKSUM = 0x30BA8368
PROGRAM_RESULT = SUCCESS
```

The immediate readback reported:

```text
DE5 [1-11.2] WDIAGS_MODE = 3 SLAVE
```

This proves the Slave image did not boot as Master. The Master was then programmed:

```text
PROGRAMMED_CABLE = DE5 [1-11.1]
PROGRAMMED_SOF = quartus/jtag_runtime_diag/output_files_master_jtag/DE5a_wr_master_jtag.sof
PROGRAMMER_CHECKSUM = 0x30B1A900
PROGRAM_RESULT = SUCCESS
```

## Three consecutive clean post-program dashboards

After both boards reached steady state, the following three consecutive windows passed the applicable upstream gates:

| window | time (pain) | Master | Slave | key evidence |
|---|---|---|---|---|
| 1 | 13:17:45–13:17:58 | Step 1/2/4A PASS | Step 1/2/3/4B PASS | WRC mode 2/3, PTP MASTER/SLAVE, RXERR Δ=0 |
| 2 | 13:18:22–13:18:35 | Step 1/2/4A PASS | Step 1/2/3/4B PASS | core link 1/1, PTP RX/TX increasing, reset Δ=0 |
| 3 | 13:18:59–13:19:12 | Step 1/2/4A PASS | Step 1/2/3/4B PASS | DMTD accepted and TAG/TRR/IRQ/helper activity increasing |

Stable role/link evidence across the clean windows:

```text
Master WRC_MODE = 2 MASTER
Slave  WRC_MODE = 3 SLAVE
Master PTP = 6 MASTER
Slave  PTP = 9 SLAVE

Master core_tm_link_up/core_link_ok = 1/1
Slave  core_tm_link_up/core_link_ok = 1/1
wr_rx_ready = 1/1
wr_tx_ready = 1/1
wr_rx_locked_to_data = 1/1
wr_rx_enc_err = 0/0
WDIAGS_RXERR delta = 0

Slave parentIsWRnode = 1
Slave parentCalibrated = 1
Slave WR_RX_SIGNAL_DEBUG = LOCK, count > 0
Slave WR_TX_SIGNAL_DEBUG = SLAVE_PRESENT, count > 0
Slave LOCK_ENABLE_COUNT > 0
Slave SPLL_MODE = 3 (SPLL_MODE_SLAVE)
Slave SPLL_SEQ_STATE = 4 (SEQ_WAIT_HELPER)
Slave SPLL_INIT_COUNT = 1
BOOT_GENERATION delta = 0
CPU_RESET_COUNT delta = 0
WR_CORE_RESET_COUNT delta = 0
SI_CONFIG_DROP_COUNT delta = 0
```

## Step5 boundary observed but not adjudicated

The clean windows show the Slave SoftPLL startup path is active, but the Step5 lock detector is not locked:

```text
HELPER_LOCKED = 0
HELPER_LOCK_COUNT = 100 / 10000   # latest clean window
MAIN_ENABLED = 0
MAIN_LOCKED = 0
PSTAT_LOCKED = 0
STEP5_RESULT = NEVER_LOCKED
STEP5_FIRST_INACTIVE_BOUNDARY = HELPER_LOCK
```

This is not a valid closed-loop Step5 result because the V3 atomic snapshot smoke was deliberately not run in this audit. It only records the current downstream boundary after the upstream role/image/link provenance was repaired and revalidated.

## Next action

Return to branch 5 with the exact requested message and wait for its next decision. Do not run V3 smoke, 1800 seconds, or merge until branch 5 explicitly confirms the next step. Current merge gate remains:

```text
STEP5_COMPLETE = NO
MERGE_APPROVED = NO
```
