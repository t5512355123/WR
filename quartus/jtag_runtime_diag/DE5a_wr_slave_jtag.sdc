create_clock -name clk_50m -period 20.000 [get_ports CLK_50_B2J]
create_clock -name qsfp_ref_125m -period 8.000 [get_ports QSFPA_REFCLK_p]
create_clock -name qsfp_dmtd_124m992 -period 8.000512 [get_ports QSFPB_REFCLK_p]
create_generated_clock -name wr_core_dmtd_62m496 -source [get_ports QSFPB_REFCLK_p] -divide_by 2 [get_registers {*|clk_dmtd_62m496}]
derive_pll_clocks
derive_clock_uncertainty
