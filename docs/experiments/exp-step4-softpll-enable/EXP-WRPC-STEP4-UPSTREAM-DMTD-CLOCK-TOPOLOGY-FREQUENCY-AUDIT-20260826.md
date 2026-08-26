# EXP-WRPC-STEP4-UPSTREAM-DMTD-CLOCK-TOPOLOGY-FREQUENCY-AUDIT-20260826

## 稽核基本資料

- 日期：2026-08-26（Asia/Taipei）
- Experiment ID：EXP-WRPC-STEP4-UPSTREAM-DMTD-CLOCK-TOPOLOGY-FREQUENCY-AUDIT-20260826
- Repository：t5512355123/WR
- Branch：exp/step4-softpll-enable
- Source HEAD：cd8eb15
- 實驗類型：source-only；不編譯、不燒錄、不修改 functional RTL

本輪依分支 2 的 UPSTREAM_DMTD_CLOCK_TOPOLOGY_FREQUENCY_AUDIT 建議，追蹤
upstream/reference design 的 DMTD clock 從 board input、platform clock
generator 到 WR core clk_dmtd_i 的完整路徑，並與目前 DE5a top-level 接線
比較。

## 先看結論

upstream source 顯示，core 端使用的是約 62.5 MHz 的 DMTD offset clock：

~~~text
upstream 8-bit SPEC reference:
  20 MHz VCXO -> DMTD PLL -> 62.5 MHz -> xwr_core.clk_dmtd_i

upstream CLBv3 direct-DMTD reference:
  124.992 MHz board input -> /2 -> 62.496 MHz -> WR core clk_dmtd_i

current DE5a:
  QSFPB_REFCLK_p = 124.992 MHz -> directly -> u_xwr_core.clk_dmtd_i
~~~

因此目前已找到一個具體的 porting mismatch 候選：

~~~text
CURRENT_DE5A_CORE_DMTD_INPUT = 124.992 MHz
UPSTREAM_CORE_DMTD_INPUT     ~= 62.5 MHz
MISSING_TOPOLOGY_OPERATION    = input / 2 before core
~~~

這是 source-level mismatch evidence，不等於已完成 functional fix；本輪沒有
改 RTL、沒有重新編譯、也沒有重新燒錄。

## Upstream 8-bit SPEC reference

vendor/wr-cores/top/spec_1_1/wr_core_demo/spec_top.vhd 的 reference top
將 platform output 接到 core：

~~~text
WRC_PLATFORM.clk_62m5_dmtd_o => signal clk_dmtd
U_WR_CORE.clk_dmtd_i         => signal clk_dmtd
~~~

source locations：

- spec_top.vhd:459-480：U_WR_CORE 與 clk_dmtd_i => clk_dmtd
- spec_top.vhd:564-608：WRC_PLATFORM 與 clk_62m5_dmtd_o => clk_dmtd

其使用 g_family => "spartan6"、default platform PLL。platform source 對
default PLL 的明確說明與輸出如下：

~~~text
20 MHz VCXO
  -> DMTD PLL
  -> 62.5 MHz DMTD clock
  -> clk_62m5_dmtd_o
  -> xwr_core.clk_dmtd_i
~~~

source locations：

- vendor/wr-cores/platform/xilinx/xwrc_platform_xilinx.vhd:237-247：
  default PLL topology 說明
- xwrc_platform_xilinx.vhd:357-393：Spartan-6 DMTD PLL 與
  clk_62m5_dmtd_o output

因此，對 upstream 8-bit SPEC reference，clk_dmtd_i 的 source-level
frequency 是約 62.5 MHz，不是 124.992 MHz。

## Upstream CLBv3 direct-DMTD reference

CLBv3 source 更直接呈現了 124.992 MHz input 與 core 端 clock 的差異。

board wrapper 的 port comment 將 input/output 定義為：

~~~text
input  clk_125m_dmtd_* : 124.992 MHz
output clk_dmtd_62m5_o : 124.992 / 2 = 62.496 MHz
~~~

source location：

- vendor/wr-cores/board/clbv3/xwrc_board_clbv3.vhd:90-105

其 clock path 為：

~~~text
IBUFGDS
  clk_125m_dmtd_p/n_i
  -> clk_125m_dmtd_buf       (124.992 MHz)

xwrc_platform_xilinx
  g_fpga_family  => "artix7"
  g_direct_dmtd  => TRUE
  clk_125m_dmtd_i => clk_125m_dmtd_buf

direct-DMTD process
  toggle clk_dmtd on every rising edge
  -> clk_dmtd = 62.496 MHz

clk_62m5_dmtd_o => clk_dmtd
~~~

source locations：

- xwrc_board_clbv3.vhd:299-307：差動 input buffer 與 output signal
- xwrc_board_clbv3.vhd:309-331：platform instance 與 output map
- vendor/wr-cores/platform/xilinx/xwrc_platform_xilinx.vhd:732-750：
  g_direct_dmtd 的 input divide-by-2 與 clk_62m5_dmtd_o output

CLBv3 後續把這個 62.496 MHz signal 接到 WR core wrapper：

- xwrc_board_clbv3.vhd:453-456：clk_dmtd_i => clk_dmtd

CLBv3 是 16-bit PHY reference，因此它的 g_pcs_16bit => TRUE 不再由
SoftPLL 內部做 input divide-by-2；但 platform 仍先把 124.992 MHz board
clock 變成 62.496 MHz core-side DMTD clock。這正好隔離了 platform-side
clock divide 與 SoftPLL sampler generic 兩個不同層次。

## Upstream Altera platform interface

即使不採用 CLBv3 的 Xilinx implementation，Altera platform interface 也把
core-facing DMTD clock 命名為 clk_62m5_dmtd：

~~~text
custom PLL input : clk_62m5_dmtd_i
platform output  : clk_62m5_dmtd_o
~~~

default Arria-5 path 則由 20 MHz VCXO 的 DMTD PLL 產生
clk_62m5_dmtd_o。

source locations：

- vendor/wr-cores/platform/altera/xwrc_platform_altera.vhd:77-84：
  custom PLL 的 62.5 MHz DMTD input interface
- xwrc_platform_altera.vhd:175-207：default Arria-5 DMTD PLL
- xwrc_platform_altera.vhd:249-254：custom PLL output pass-through

這是與目前 DE5a 使用 Arria 10、直接 instantiate xwr_core 的重要
interface-level 對照：upstream platform abstraction 將 62.5 MHz clock
交給 core，而不是把 124.992 MHz board reference 直接當成 core DMTD clock。

## Current DE5a path

目前兩個 DE5a top 都由 SI5340 產生：

~~~text
OUT0 = 125 MHz
OUT1 = 124.992 MHz
~~~

source locations：

- quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd:153-155,587-594
- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:154-156,609-615

目前 u_xwr_core 的直接接線是：

~~~text
u_xwr_core.clk_sys_i  => clk_sys_625
u_xwr_core.clk_dmtd_i => QSFPB_REFCLK_p
u_xwr_core.clk_ref_i  => QSFPA_REFCLK_p
~~~

source locations：

- quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd:670-687
- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:693-710

相應 SDC 也將 QSFPB_REFCLK_p 定義為 124.992 MHz：

- quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc:1-5
- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc:1-5

目前 top 沒有 platform-side divider、62.496 MHz generated signal，或其他
把 QSFPB_REFCLK_p 除 2 後再交給 u_xwr_core.clk_dmtd_i 的 instance。

## Frequency comparison

| Path | board/platform input | core-side clk_dmtd_i | operation |
|---|---:|---:|---|
| SPEC 8-bit reference | 20 MHz VCXO to DMTD PLL | about 62.500 MHz | PLL multiplication |
| CLBv3 direct-DMTD reference | 124.992 MHz | 62.496 MHz | explicit /2 toggle |
| DE5a current | 124.992 MHz QSFP-B ref input | 124.992 MHz | direct connection |

目前 8-bit SoftPLL generic 已經在前一份 audit 證明為：

~~~text
g_pcs_16bit             = false
g_softpll_reverse_dmtds = false
g_divide_input_by_2     = true
~~~

因此 current DE5a 同時具備：

~~~text
sampler input divide-by-2 = true
core DMTD clock           = 124.992 MHz
~~~

而 upstream 8-bit reference 的對應 topology 是：

~~~text
sampler input divide-by-2 = true
core DMTD clock           ~= 62.5 MHz
~~~

這表示上一輪把 124.992 MHz 直接當成 core clk_dmtd_i 的假設不能再
視為與 upstream reference 等價。

## 對 run-length 與 Step4 blocker 的影響

在目前 sampler generic 已與 upstream core-level reference 對齊的前提下，
最大的已知差異從 generic 轉移到 clock topology：

~~~text
upstream:
  core clk_dmtd ~= post-divided 62.5 MHz clock

current DE5a:
  core clk_dmtd = raw 124.992 MHz clock
~~~

這個 x2 clock-rate difference 足以改變 dmtd_sampler 的 sampling phase
walk、clk_sampled run length 與 GOT_EDGE qualification 行為；它比
單純再次爭論 threshold 或 reverse 更直接地對應目前觀測到的
HIGH_QUAL_MAX_STAB << 1000。

目前 source evidence 已支持：

~~~text
CURRENT_DE5A_CORE_DMTD_TOPOLOGY = NOT UPSTREAM-EQUIVALENT
LIKELY_MISMATCH                 = raw 124.992 MHz used where ~=62.5 MHz expected
STEP4_ROOT_CAUSE                = STRONGLY SUSPECTED, NOT YET RUNTIME-PROVEN
~~~

尚未支持的事項：

~~~text
whether a local /2 divider alone is sufficient
whether reset/clock constraints need a coordinated change
whether the resulting image passes Step2/3 and Step4
~~~

因此本輪不直接修改 top-level clocking；下一輪應由 reviewer 指定一個單一
functional A/B，優先驗證 core-side clk_dmtd_i 改為 62.496 MHz 是否使
目前 threshold=1000 的 qualification 具備合理的 phase-walk 行為。

## 正式判定

~~~text
UPSTREAM_8BIT_CORE_DMTD_FREQUENCY      = about 62.5 MHz
UPSTREAM_CLBV3_CORE_DMTD_FREQUENCY     = 62.496 MHz
CURRENT_DE5A_CORE_DMTD_FREQUENCY       = 124.992 MHz
CURRENT_TOPOLOGY_MATCH                 = NO
MISSING_OPERATION                      = core-side /2 before xwr_core
CURRENT_SAMPLER_GENERIC                = upstream-equivalent at core level
CLOCK_TOPOLOGY_MISMATCH                = STRONGLY_SUSPECTED
FUNCTIONAL_FIX                         = NOT_APPLIED
RTL_CHANGE                             = NONE
COMPILE_PROGRAM                        = SKIPPED
RUNTIME_VERIFICATION                   = PENDING_SINGLE_A_B
~~~

## Evidence paths

- vendor/wr-cores/top/spec_1_1/wr_core_demo/spec_top.vhd:459-480,564-608
- vendor/wr-cores/platform/xilinx/xwrc_platform_xilinx.vhd:237-247,357-393
- vendor/wr-cores/board/clbv3/xwrc_board_clbv3.vhd:90-105,299-331,453-456
- vendor/wr-cores/platform/xilinx/xwrc_platform_xilinx.vhd:732-750
- vendor/wr-cores/platform/altera/xwrc_platform_altera.vhd:77-84,175-207,249-254
- quartus/jtag_runtime_diag/DE5a_wr_master_jtag.vhd:153-155,587-594,670-687
- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.vhd:154-156,609-615,693-710
- quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc:1-5
- quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc:1-5
- docs/experiments/exp-step4-softpll-enable/EXP-WRPC-STEP4-UPSTREAM-REFERENCE-DMTD-CONFIGURATION-AUDIT-20260826.md
