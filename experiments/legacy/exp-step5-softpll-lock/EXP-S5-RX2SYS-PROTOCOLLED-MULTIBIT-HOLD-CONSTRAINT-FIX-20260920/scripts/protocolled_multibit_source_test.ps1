$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$sdcFiles = [ordered]@{
    MASTER = Join-Path $repoRoot 'quartus\jtag_runtime_diag\DE5a_wr_master_jtag.sdc'
    SLAVE  = Join-Path $repoRoot 'quartus\jtag_runtime_diag\DE5a_wr_slave_jtag.sdc'
}

$checks = [ordered]@{}
$protocolPattern = '(?s)# EXP-S5-RX2SYS-PROTOCOLLED-MULTIBIT-HOLD-CONSTRAINT-FIX-20260920.*?(?=# Diagnostic-only activity-toggle CDC\.)'

foreach ($role in $sdcFiles.Keys) {
    $text = Get-Content -Raw -LiteralPath $sdcFiles[$role]
    $blocks = [regex]::Matches($text, $protocolPattern)
    $block = if ($blocks.Count -eq 1) { $blocks[0].Value } else { '' }

    $checks["${role}_PROTOCOL_BLOCK_COUNT"] = ($blocks.Count -eq 1)
    $checks["${role}_LCR_SOURCE"] = ($block -match '\{\*\|ep_rx_pcs_8bit:\*\|lcr_final_val\*\}')
    $checks["${role}_LCR_DEST_RX_CONFIG"] = ($block -match '\{\*\|ep_autonegotiation:\*\|rx_config_reg\*\}')
    $checks["${role}_LCR_DEST_MDIO"] = ($block -match 'mdio_lpa_full_o|mdio_lpa_half_o|mdio_lpa_pause_o|mdio_lpa_rfault_o|mdio_lpa_lpack_o|mdio_lpa_npage_o')
    $checks["${role}_LCR_DEST_STATE"] = ($block -match '\{\*\|ep_autonegotiation:\*\|state\*\}')
    $checks["${role}_PCLASS_SOURCE"] = ($block -match '\{\*\|ep_packet_filter:\*\|pclass_int\*\}')
    $checks["${role}_PCLASS_DEST"] = ($block -match '\{\*\|ep_packet_filter:\*\|pclass_o\*\}')
    $checks["${role}_DROP_SOURCE"] = ($block -match '\{\*\|ep_packet_filter:\*\|drop_int\*\}')
    $checks["${role}_DROP_DEST"] = ($block -match '\{\*\|ep_packet_filter:\*\|drop_o\*\}')
    $checks["${role}_LCR_HOLD_EXCEPTION"] = ($block -match 'set_false_path\s+-hold\s+-from\s+\$lcr_src\s+-to\s+\$lcr_dst')
    $checks["${role}_PCLASS_DROP_HOLD_EXCEPTION"] = ([regex]::Matches($block, 'set_false_path\s+-hold\s+-from\s+\$src\s+-to\s+\$dst').Count -eq 1)
    $checks["${role}_NO_FULL_FALSE_PATH"] = ($block -notmatch '(?m)^\s*set_false_path\s+-from')
    $checks["${role}_NO_CLOCK_GROUP"] = ($block -notmatch 'set_clock_groups')
    $checks["${role}_NO_MULTICYCLE"] = ($block -notmatch 'set_multicycle_path')
    $checks["${role}_NO_MIN_MAX_DELAY"] = ($block -notmatch 'set_(min|max)_delay')
    $checks["${role}_NO_BROAD_LCR_DEST"] = ($block -notmatch '\{\*\|ep_autonegotiation:\*\|\*\}')
}

$changedQuartus = @(& git -C $repoRoot diff --name-only HEAD -- 'quartus/jtag_runtime_diag')
$checks['ONLY_TWO_SDC_PRODUCTION_FILES_CHANGED'] = (
    $changedQuartus.Count -eq 2 -and
    @($changedQuartus | Where-Object { $_ -notin @(
        'quartus/jtag_runtime_diag/DE5a_wr_master_jtag.sdc',
        'quartus/jtag_runtime_diag/DE5a_wr_slave_jtag.sdc') }).Count -eq 0)

$changedQsf = @(& git -C $repoRoot diff --name-only HEAD -- 'quartus/jtag_runtime_diag' | Where-Object { $_ -match '\.qsf$' })
$changedRtl = @(& git -C $repoRoot diff --name-only HEAD -- 'vendor')
$checks['QSF_UNCHANGED'] = ($changedQsf.Count -eq 0)
$checks['RTL_UNCHANGED'] = ($changedRtl.Count -eq 0)

$checks.GetEnumerator() | ForEach-Object {
    '{0}={1}' -f $_.Key, ([int]$_.Value)
}

if (@($checks.Values | Where-Object { $_ -eq $false }).Count -ne 0) {
    'PROTOCOLLED_MULTIBIT_SOURCE_GATE=FAIL'
    exit 1
}

'PROTOCOLLED_MULTIBIT_SOURCE_GATE=PASS'
