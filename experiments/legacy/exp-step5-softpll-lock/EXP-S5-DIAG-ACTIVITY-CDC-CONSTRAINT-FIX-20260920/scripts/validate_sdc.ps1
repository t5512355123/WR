param(
    [Parameter(Mandatory = $true)]
    [string[]] $SdcPath
)

$expectedPairs = @(
    'ref_activity_toggle   ref_activity_meta',
    'dmtd_activity_toggle  dmtd_activity_meta',
    'rx_activity_toggle    rx_activity_meta'
)

$failed = $false
foreach ($path in $SdcPath) {
    $text = Get-Content -LiteralPath $path -Raw
    $pairCount = 0
    foreach ($pair in $expectedPairs) {
        if ($text.Contains($pair)) {
            $pairCount++
        }
    }

    $hasLoop = $text.Contains('foreach {src dst}')
    $hasExactResolution = $text.Contains('get_collection_size $src_regs') -and
        $text.Contains('get_collection_size $dst_regs')
    $hasPointToPoint = $text.Contains('set_false_path -from $src_regs -to $dst_regs')
    $hasForbidden = $text -match '(?m)^\s*set_clock_groups\b' -or
        $text -match '\*meta\*' -or
        $text -match '(?m)^\s*set_false_path\s+-from\s+\[get_clocks'

    if ($pairCount -ne 3 -or -not $hasLoop -or -not $hasExactResolution -or
        -not $hasPointToPoint -or $hasForbidden) {
        Write-Output "DIAG_ACTIVITY_CDC_SDC_TEST=FAIL path=$path pair_count=$pairCount"
        $failed = $true
    } else {
        Write-Output "DIAG_ACTIVITY_CDC_SDC_TEST=PASS path=$path pair_count=$pairCount"
    }
}

if ($failed) {
    exit 1
}

Write-Output 'DIAG_CDC_PAIR_COUNT_MASTER=3'
Write-Output 'DIAG_CDC_PAIR_COUNT_SLAVE=3'
Write-Output 'DIAG_ACTIVITY_CDC_SDC_TEST=PASS'
