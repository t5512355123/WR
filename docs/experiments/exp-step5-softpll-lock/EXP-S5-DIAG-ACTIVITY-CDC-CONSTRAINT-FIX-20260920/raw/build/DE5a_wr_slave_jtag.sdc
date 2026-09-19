create_clock -name clk_50m -period 20.000 [get_ports CLK_50_B2J]
create_clock -name qsfp_ref_125m -period 8.000 [get_ports QSFPA_REFCLK_p]
create_clock -name qsfp_dmtd_124m992 -period 8.000512 [get_ports QSFPB_REFCLK_p]
create_generated_clock -name wr_core_dmtd_62m496 -source [get_ports QSFPB_REFCLK_p] -divide_by 2 [get_registers {*|clk_dmtd_62m496}]
derive_pll_clocks
derive_clock_uncertainty

# Diagnostic-only activity-toggle CDC.
# Only the asynchronous source -> first metastability-capture register is
# excluded from synchronous setup/hold analysis.  meta -> sync -> prev remains
# fully timed by clk_50m.
foreach {src dst} {
    ref_activity_toggle   ref_activity_meta
    dmtd_activity_toggle  dmtd_activity_meta
    rx_activity_toggle    rx_activity_meta
} {
    set src_regs [get_registers -nowarn $src]
    set dst_regs [get_registers -nowarn $dst]

    if {[get_collection_size $src_regs] != 1 ||
        [get_collection_size $dst_regs] != 1} {
        post_message -type error \
            "Diagnostic CDC constraint did not resolve exactly 1:1: $src -> $dst"
        error "DIAG_ACTIVITY_CDC_CONSTRAINT_TARGET_MISMATCH"
    }

    set_false_path -from $src_regs -to $dst_regs
}
