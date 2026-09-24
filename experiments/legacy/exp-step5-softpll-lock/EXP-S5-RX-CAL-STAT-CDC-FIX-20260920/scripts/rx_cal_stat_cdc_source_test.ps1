$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$sourcePath = Join-Path $repoRoot 'vendor\wr-cores\modules\wr_endpoint\ep_rx_pcs_8bit.vhd'
$text = Get-Content -Raw -LiteralPath $sourcePath

$checks = [ordered]@{}
$checks['RX_CAL_STAT_SOURCE_DOMAIN'] =
    ([regex]::Matches($text, 'p_detect_cal\s*:\s*process\(phy_rx_clk_i\)').Count -eq 1)
$checks['RX_CAL_STAT_RAW_SIGNAL'] =
    ([regex]::Matches($text, 'mdio_wr_spec_rx_cal_stat_rx').Count -ge 5)
$checks['RX_CAL_STAT_RAW_WRITES'] =
    ([regex]::Matches($text, 'mdio_wr_spec_rx_cal_stat_rx\s*<=').Count -eq 3)
$checks['RX_CAL_STAT_DESTINATION_SYNCHRONIZER'] =
    ([regex]::Matches($text, 'U_sync_rx_cal_stat\s*:\s*entity\s+work\.gc_sync\b').Count -eq 1)
$checks['RX_CAL_STAT_SYNC_CLOCK'] =
    ([regex]::Matches($text, 'U_sync_rx_cal_stat[\s\S]{0,500}clk_i\s*=>\s*clk_sys_i').Count -eq 1)
$checks['RX_CAL_STAT_SYNC_INPUT'] =
    ([regex]::Matches($text, 'U_sync_rx_cal_stat[\s\S]{0,500}d_i\s*=>\s*mdio_wr_spec_rx_cal_stat_rx').Count -eq 1)
$checks['RX_CAL_STAT_SYNC_OUTPUT'] =
    ([regex]::Matches($text, 'U_sync_rx_cal_stat[\s\S]{0,500}q_o\s*=>\s*mdio_wr_spec_rx_cal_stat_o').Count -eq 1)
$checks['DIRECT_RAW_RX_TO_MDIO_OUTPUT_REMOVED'] =
    ([regex]::Matches($text, 'mdio_wr_spec_rx_cal_stat_o\s*<=').Count -eq 0)
$checks['FORBIDDEN_TIMING_EDIT_ABSENT'] =
    ($text -notmatch 'set_false_path|set_clock_groups|set_min_delay|set_max_delay|multicycle')

$checks.GetEnumerator() | ForEach-Object {
    '{0}={1}' -f $_.Key, ([int]$_.Value)
}

if (@($checks.Values | Where-Object { $_ -eq $false }).Count -ne 0) {
    'RX_CAL_STAT_CDC_IMPLEMENTATION=FAIL'
    exit 1
}

'RX_CAL_STAT_CDC_IMPLEMENTATION=PASS'
