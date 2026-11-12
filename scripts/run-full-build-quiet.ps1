#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$validateOnly = $false
$customGoals = $false
$goals = @('clean', 'license:format', 'spotless:apply', 'verify')
$mavenArgs = @()
for ($index = 0; $index -lt $args.Count; $index++) {
    switch ($args[$index]) {
        '--validate-only' { $validateOnly = $true }
        '--goals' {
            $index++
            if ($index -ge $args.Count -or [string]::IsNullOrWhiteSpace($args[$index])) {
                throw '--goals requires a value'
            }
            $goals = $args[$index] -split '\s+'
            $customGoals = $true
        }
        { $_ -in '-h', '--help' } {
            Write-Output 'Usage: scripts/run-full-build-quiet.ps1 [--validate-only] [--goals "goals..."] [-- Maven arguments...]'
            Write-Output 'Default: clean license:format spotless:apply verify; --validate-only runs clean verify with all Maven-native checks.'
            Write-Output 'QUIET_BUILD_TIMEOUT_SECONDS defaults to 180 (0 disables); QUIET_BUILD_HEARTBEAT_SECONDS defaults to 30.'
            exit 0
        }
        '--' {
            if ($index + 1 -lt $args.Count) { $mavenArgs += $args[($index + 1)..($args.Count - 1)] }
            $index = $args.Count
        }
        default { $mavenArgs += $args[$index] }
    }
}
if ($validateOnly -and $customGoals) { throw '--validate-only cannot be combined with --goals' }
if ($validateOnly) { $goals = @('clean', 'verify') }
$timeoutSeconds = 180
$heartbeatSeconds = 30
if ($env:QUIET_BUILD_TIMEOUT_SECONDS -and (-not [int]::TryParse($env:QUIET_BUILD_TIMEOUT_SECONDS, [ref]$timeoutSeconds) -or $timeoutSeconds -lt 0)) {
    throw 'QUIET_BUILD_TIMEOUT_SECONDS must be a non-negative integer'
}
if ($env:QUIET_BUILD_HEARTBEAT_SECONDS -and (-not [int]::TryParse($env:QUIET_BUILD_HEARTBEAT_SECONDS, [ref]$heartbeatSeconds) -or $heartbeatSeconds -lt 1)) {
    throw 'QUIET_BUILD_HEARTBEAT_SECONDS must be a positive integer'
}
$logDirectory = Join-Path $repoRoot '.agents/logs'
$null = New-Item -ItemType Directory -Force -Path $logDirectory
$logFile = Join-Path $logDirectory ('full-build-{0}-{1}.log' -f (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'), [guid]::NewGuid().ToString('N').Substring(0, 8))
$stdoutFile = [System.IO.Path]::GetTempFileName()
$stderrFile = [System.IO.Path]::GetTempFileName()
$mavenCommand = Join-Path $repoRoot $(if ($IsWindows) { 'mvnw.cmd' } else { 'mvnw' })
$commandArgs = @('-B', '-ntp', '-Dstyle.color=never') + $goals + $mavenArgs
$quotedArgs = ($commandArgs | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
$executable = $mavenCommand
if ($IsWindows) {
    $executable = $env:ComSpec
    $quotedArgs = '/d /s /c ""' + $mavenCommand + '" ' + $quotedArgs + '"'
}
$process = $null
$start = Get-Date
$lastHeartbeat = $start
$status = 1
$timedOut = $false
try {
    $process = Start-Process -FilePath $executable -ArgumentList $quotedArgs -WorkingDirectory $repoRoot -NoNewWindow -PassThru -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
    $null = $process.Handle
    while (-not $process.WaitForExit(1000)) {
        $now = Get-Date
        if ($timeoutSeconds -gt 0 -and ($now - $start).TotalSeconds -ge $timeoutSeconds) {
            $timedOut = $true
            $process.Kill($true)
            break
        }
        if (($now - $lastHeartbeat).TotalSeconds -ge $heartbeatSeconds) {
            Write-Output ('[WARN] quiet build still running after {0:F0}s; log: {1}' -f ($now - $start).TotalSeconds, $logFile)
            $lastHeartbeat = $now
        }
    }
    $process.WaitForExit()
    $process.Refresh()
    $status = if ($timedOut) { 124 } elseif ($null -ne $process.ExitCode) { $process.ExitCode } else { 1 }
} finally {
    if ($null -ne $process -and -not $process.HasExited) { $process.Kill($true); $process.WaitForExit() }
    @('Maven goals: ' + ($goals -join ' ')) + @(Get-Content -LiteralPath $stdoutFile) + @(Get-Content -LiteralPath $stderrFile) | Set-Content -LiteralPath $logFile
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force
    if ($null -ne $process) { $process.Dispose() }
    Get-Content -LiteralPath $logFile | Where-Object { $_ -match '\[(WARNING|WARN|ERROR)\]|(^|\s)(WARN|WARNING|ERROR|FATAL)(\s|:|$)' } | Write-Output
    $reports = @(Get-ChildItem -Path (Join-Path $repoRoot 'target/surefire-reports/TEST-*.xml') -ErrorAction SilentlyContinue)
    if ($reports.Count -gt 0) {
        $run = 0; $failures = 0; $errors = 0; $skipped = 0
        foreach ($report in $reports) {
            [xml]$xml = Get-Content -Raw -LiteralPath $report.FullName
            $run += [int]$xml.testsuite.tests
            $failures += [int]$xml.testsuite.failures
            $errors += [int]$xml.testsuite.errors
            $skipped += [int]$xml.testsuite.skipped
        }
        Write-Output "Tests run: $run, Failures: $failures, Errors: $errors, Skipped: $skipped"
    }
    $coverageFile = Join-Path $repoRoot 'target/site/jacoco/jacoco.csv'
    if (Test-Path -LiteralPath $coverageFile) {
        $lineMissed = 0; $lineCovered = 0; $branchMissed = 0; $branchCovered = 0
        foreach ($row in Import-Csv -LiteralPath $coverageFile) {
            $lineMissed += [long]$row.LINE_MISSED; $lineCovered += [long]$row.LINE_COVERED
            $branchMissed += [long]$row.BRANCH_MISSED; $branchCovered += [long]$row.BRANCH_COVERED
        }
        if ($lineMissed + $lineCovered -gt 0) {
            Write-Output ('Coverage: lines {0:F2}% ({1}/{2})' -f (100 * $lineCovered / ($lineMissed + $lineCovered)), $lineCovered, ($lineMissed + $lineCovered))
        }
        if ($branchMissed + $branchCovered -gt 0) {
            Write-Output ('Coverage: branches {0:F2}% ({1}/{2})' -f (100 * $branchCovered / ($branchMissed + $branchCovered)), $branchCovered, ($branchMissed + $branchCovered))
        }
    }
    if ($timedOut) { Write-Output "Build: timed out after ${timeoutSeconds}s" }
    elseif ($status -eq 0) { Write-Output ('Build: GREEN in {0:F0}s' -f ((Get-Date) - $start).TotalSeconds) }
    else { Write-Output ('Build: FAILED (Maven exit {0}) in {1:F0}s' -f $status, ((Get-Date) - $start).TotalSeconds) }
    Write-Output "Log: $logFile"
}
exit $status
