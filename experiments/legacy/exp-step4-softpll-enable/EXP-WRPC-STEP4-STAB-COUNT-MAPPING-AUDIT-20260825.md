# EXP-WRPC-STEP4-STAB-COUNT-MAPPING-AUDIT-20260825

## 實驗名稱

Step 4 functional `dbg_stab_count_o` Wishbone mapping source audit

## 日期與 Git

- 日期：2026-08-25
- Repository：`t5512355123/WR`
- Branch：`exp/step4-softpll-enable`
- HEAD：`c8e81f56563ad3bf64d994c92f4589bf08e01056`
- 類型：source-only/read-only mapping audit
- Quartus compile：未執行
- FPGA program：未執行

## 為了驗證什麼

確認 reviewer 建議的 functional `dbg_stab_count_o` 是否已經存在可合法使用的 JTAG/Wishbone read address，避免直接猜測位址或把其他 diagnostic 當成 `stab_cntr`。

## Source evidence

### 1. Counter 在 DMTD module 內確實存在

`vendor/wr-cores/modules/timing/dmtd_with_deglitcher.vhd`：

```text
dbg_stab_count_o : out std_logic_vector(15 downto 0)
U_sync_dbg_stab_count
q_o => dbg_stab_count_sys
dbg_stab_count_o <= dbg_stab_count_sys
```

這個輸出是 functional `stab_cntr` 的同步 read-only output，並不是輸入端 `clk_i_d0` low-run max。

### 2. Signal 只接到 wr_softpll_ng 內部 signal

`vendor/wr-cores/modules/wr_softpll_ng/wr_softpll_ng.vhd` 目前有：

```text
dmtd_ref_stab_count
dmtd_fb_stab_count
dbg_stab_count_o => dmtd_ref_stab_count(i)
dbg_stab_count_o => dmtd_fb_stab_count(i)
```

但這些 signal 沒有在 `spll_wb_slave` 的 port list 中成為 `diag_*_stab_count_i`，也沒有接到 Wishbone slave read data。

### 3. Wishbone mapping 沒有此欄位

`vendor/wr-cores/modules/wr_softpll_ng/spll_wb_slave.vhd` 的 port list 與 read cases 中沒有 `stab_count` 對應欄位。現有 `0x0010025C` 是 `diag_dmtd_input_d0_low_run_max_i`，不是 `dbg_stab_count_o`；現有 `0x001002DC` 是 packed `SPLL_DMTD_STATE`，只提供 state 與 stability bucket，不提供完整 16-bit `stab_cntr`。

因此目前沒有 source-backed address 可以讓 `read_step4_startup_focused.tcl` 直接讀到完整 functional `dbg_stab_count_o`。

## 結論

```text
EXACT_DBG_STAB_COUNT_WISHBONE_MAPPING = NOT_AVAILABLE
STEP4_RESULT                         = NOT_PASS
ROOT_CAUSE                           = NOT_PROVEN
```

目前不可以：

- 把 `0x0010025C` 當成 `dbg_stab_count_o`；它是 sampler `clk_i_d0` low-run max。
- 把 `0x001002DC` 的 bucket 當成完整 `stab_cntr`；它只是 coarse sampled field。
- 猜一個新的 Wishbone address。
- 修改 RTL 或重新宣稱 Step 4 已通過。

## 與本輪限制的關係

本輪限定只能修 Tcl/dashboard、執行 read-only regression、保存 logs/docs，禁止修改 FPGA RTL、firmware、MIF、SoftPLL、PHY 或任何 functional behavior。因此本輪到此已完成所有可合法執行的 mapping audit 與 coarse read-only observation。

若要取得 reviewer 要求的精確資訊，下一個必要變更只能是新增一個純 read-only 的 `diag_dmtd_ref/fb_stab_count_i` 接線與 Wishbone read mapping，然後重新 clean build/program；這需要明確授權，不能在目前限制下自行完成。

## 現有回歸證據狀態

- Step 1：PASS
- Step 2：PASS
- Step 3：PASS
- Step 4：NOT_PASS
- Step 4 allowed：YES，代表可以繼續診斷，不代表已達成。
- Hardware/firmware failure：尚未證明
- JTAG/dashboard measurement issue：已修正 threshold 高 16 位未定義造成的誤判；完整 functional `stab_cntr` 仍未被 export。
