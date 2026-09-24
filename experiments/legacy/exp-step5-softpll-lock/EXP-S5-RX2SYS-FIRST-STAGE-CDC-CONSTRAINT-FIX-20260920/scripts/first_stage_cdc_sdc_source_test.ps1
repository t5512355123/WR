$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$sdcFiles = [ordered]@{
    MASTER = Join-Path $repoRoot 'quartus\jtag_runtime_diag\DE5a_wr_master_jtag.sdc'
    SLAVE  = Join-Path $repoRoot 'quartus\jtag_runtime_diag\DE5a_wr_slave_jtag.sdc'
}

$checks = [ordered]@{}
$blockPattern = '(?s)# WR RX/PMA -> SYS first-stage synchronizer CDC\..*?(?=# Diagnostic-only activity-toggle CDC\.)'

foreach ($role in $sdcFiles.Keys) {
    $text = Get-Content -Raw -LiteralPath $sdcFiles[$role]
    $blocks = [regex]::Matches($text, $blockPattern)
    $block = if ($blocks.Count -eq 1) { $blocks[0].Value } else { '' }

    $checks["${role}_SDC_FIRST_STAGE_BLOCK"] = ($blocks.Count -eq 1)
    $checks["${role}_RX_CLKOUT_COLLECTION"] = ($block -match '\[get_clocks\s+-nowarn\s+\{\*\|rx_clkout\}\]')
    $checks["${role}_RX_PMA_CLK_COLLECTION"] = ($block -match '\[get_clocks\s+-nowarn\s+\{\*\|rx_pma_clk\}\]')
    $checks["${role}_SYNC0_COLLECTION"] = ($block -match '\{\*\|gc_sync:\*\|sync0\*\}' -and $block -match '\{\*\|gc_sync_register:\*\|sync0\*\}')
    $checks["${role}_FALSE_PATH_COUNT"] = ([regex]::Matches($block, 'set_false_path\s+-from').Count -eq 2)
    $checks["${role}_NO_SYNC1_DESTINATION"] = ($block -notmatch '-to[^\r\n]*sync1')
    $checks["${role}_NO_PROTOCOLLED_DESTINATION"] = ($block -notmatch 'lcr_final_val|pclass_int|drop_int|rx_config_reg|mdio_lpa')
    $checks["${role}_NO_CLOCK_GROUP"] = ($block -notmatch 'set_clock_groups')
}

$rtlDiff = (& git -C $repoRoot diff -- 'vendor/wr-cores/modules/wr_endpoint/ep_rx_pcs_8bit.vhd' | Out-String)
$qsfDiff = (& git -C $repoRoot diff -- 'quartus/jtag_runtime_diag/*.qsf' | Out-String)
$checks['RTL_UNCHANGED'] = [string]::IsNullOrWhiteSpace($rtlDiff)
$checks['QSF_UNCHANGED'] = [string]::IsNullOrWhiteSpace($qsfDiff)

$checks.GetEnumerator() | ForEach-Object {
    '{0}={1}' -f $_.Key, ([int]$_.Value)
}

if (@($checks.Values | Where-Object { $_ -eq $false }).Count -ne 0) {
    'FIRST_STAGE_CDC_CONSTRAINT_IMPLEMENTATION=FAIL'
    exit 1
}

'FIRST_STAGE_CDC_CONSTRAINT_IMPLEMENTATION=PASS'
