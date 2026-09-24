create_clock -name clk_50m -period 20.000 [get_ports CLK_50_B2J]
create_clock -name qsfp_ref_125m -period 8.000 [get_ports QSFPA_REFCLK_p]
create_clock -name qsfp_dmtd_124m992 -period 8.000512 [get_ports QSFPB_REFCLK_p]
create_generated_clock -name wr_core_dmtd_62m496 -source [get_ports QSFPB_REFCLK_p] -divide_by 2 [get_registers {*|clk_dmtd_62m496}]
derive_pll_clocks
derive_clock_uncertainty

# WR RX/PMA -> SYS first-stage synchronizer CDC.
# Only asynchronous launch clocks entering the FIRST metastability stage
# of the standard WR synchronizer primitives are excluded.
# sync0 -> sync1 remains fully timed in the destination clock domain.
# Stable-data / synchronized-event multibit protocols are not covered here.
set wr_rx_clkout [get_clocks -nowarn {*|rx_clkout}]
set wr_rx_pma_clk [get_clocks -nowarn {*|rx_pma_clk}]

if {[get_collection_size $wr_rx_clkout] != 1} {
    post_message -type error \
        "WR RX CDC constraint expected exactly one rx_clkout"
    error "WR_RX_CLKOUT_COLLECTION_MISMATCH"
}

if {[get_collection_size $wr_rx_pma_clk] != 1} {
    post_message -type error \
        "WR RX CDC constraint expected exactly one rx_pma_clk"
    error "WR_RX_PMA_CLK_COLLECTION_MISMATCH"
}

set wr_rx_sync0_regs [get_registers -nowarn [list \
    {*|gc_sync:*|sync0*} \
    {*|gc_sync_register:*|sync0*} \
    {*|gc_sync_ffs:*|sync0*}]]

if {[get_collection_size $wr_rx_sync0_regs] <= 0} {
    post_message -type error \
        "WR RX CDC first-stage synchronizer collection is empty"
    error "WR_RX_SYNC0_COLLECTION_EMPTY"
}

set_false_path -from $wr_rx_clkout  -to $wr_rx_sync0_regs
set_false_path -from $wr_rx_pma_clk -to $wr_rx_sync0_regs

# EXP-S5-RX2SYS-PROTOCOLLED-MULTIBIT-HOLD-CONSTRAINT-FIX-20260920
# Source-proven RX -> SYS bundled-data protocols.
# Exclude HOLD analysis only; keep SETUP analysis as a datapath guard.
set lcr_src [get_registers -nowarn \
    {*|ep_rx_pcs_8bit:*|lcr_final_val*}]

set lcr_dst [get_registers -nowarn [list \
    {*|ep_autonegotiation:*|rx_config_reg*} \
    {*|ep_autonegotiation:*|mdio_lpa_full_o*} \
    {*|ep_autonegotiation:*|mdio_lpa_half_o*} \
    {*|ep_autonegotiation:*|mdio_lpa_pause_o*} \
    {*|ep_autonegotiation:*|mdio_lpa_rfault_o*} \
    {*|ep_autonegotiation:*|mdio_lpa_lpack_o*} \
    {*|ep_autonegotiation:*|mdio_lpa_npage_o*} \
    {*|ep_autonegotiation:*|state*}]]

if {[get_collection_size $lcr_src] <= 0 ||
    [get_collection_size $lcr_dst] <= 0} {
    post_message -type error \
        "LCR bundled-data CDC collection is empty"
    error "LCR_PROTOCOL_CDC_COLLECTION_EMPTY"
}

set_false_path -hold -from $lcr_src -to $lcr_dst

set pclass_src [get_registers -nowarn \
    {*|ep_packet_filter:*|pclass_int*}]
set pclass_dst [get_registers -nowarn \
    {*|ep_packet_filter:*|pclass_o*}]
set drop_src [get_registers -nowarn \
    {*|ep_packet_filter:*|drop_int*}]
set drop_dst [get_registers -nowarn \
    {*|ep_packet_filter:*|drop_o*}]

foreach {src dst name} [list \
    $pclass_src $pclass_dst PCLASS \
    $drop_src   $drop_dst   DROP] {

    if {[get_collection_size $src] <= 0 ||
        [get_collection_size $dst] <= 0} {
        post_message -type error \
            "${name} bundled-data CDC collection is empty"
        error "${name}_PROTOCOL_CDC_COLLECTION_EMPTY"
    }

    set_false_path -hold -from $src -to $dst
}

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
