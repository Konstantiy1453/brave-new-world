<#
.SYNOPSIS
    Runs Colony Charter test suites, each in its own Godot process.
.DESCRIPTION
    Suites come from tools\test_suites.json. Every run gets an isolated APPDATA under
    evidence\v17\userdata_tests\<suite> and a log at evidence\v17\tests\<suite>.log.
    A suite fails on a non-zero exit, a timeout, SCRIPT ERROR, its failure marker, or a
    missing success marker. Exits non-zero when anything failed.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1 -Only sim_tests,v16_flow -Jobs 2
#>
[CmdletBinding()]
param(
    [string[]]$Only = @(),
    [int]$Jobs = 6,
    [switch]$Window,
    [int]$DefaultTimeout = 600
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $root 'tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'
$gamePath = Join-Path $root 'game'
$logDir = Join-Path $root 'evidence\v17\tests'
$userRoot = Join-Path $root 'evidence\v17\userdata_tests'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
New-Item -ItemType Directory -Force -Path $userRoot | Out-Null

$config = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'test_suites.json'), [Text.Encoding]::UTF8) | ConvertFrom-Json
$defaultFailure = [string]$config.default_failure
$scriptErrors = [string]$config.script_errors

# "powershell -File" passes a comma list as one string.
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$selected = @($config.suites | Where-Object {
    if ($Only.Count -gt 0) { return $Only -contains $_.name }
    if ($_.window -and -not $Window) { return $false }
    return -not $_.disabled
})
if ($selected.Count -eq 0) { throw 'No suites selected' }

function Start-Suite($suite) {
    $userData = Join-Path $userRoot $suite.name
    if (Test-Path -LiteralPath $userData) { Remove-Item -LiteralPath $userData -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $userData | Out-Null
    $env:APPDATA = $userData
    $stdout = Join-Path $logDir ("{0}.stdout.tmp" -f $suite.name)
    $stderr = Join-Path $logDir ("{0}.stderr.tmp" -f $suite.name)
    $arguments = @()
    if (-not $suite.window) { $arguments += '--headless' }
    $arguments += @('--path', "`"$gamePath`"")
    if ($suite.window) { $arguments += @('--rendering-method', 'gl_compatibility') }
    $arguments += @('--script', "`"$($suite.script)`"")
    if ($suite.args) { $arguments += @('--') + @($suite.args) }
    $timeout = if ($suite.timeout) { [int]$suite.timeout } else { $DefaultTimeout }
    $process = Start-Process -FilePath $engine -ArgumentList $arguments -PassThru -NoNewWindow `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $null = $process.Handle
    return [pscustomobject]@{
        Suite = $suite
        Process = $process
        Stdout = $stdout
        Stderr = $stderr
        Started = Get-Date
        Timeout = $timeout
        TimedOut = $false
    }
}

function Read-Released($path) {
    # The console wrapper can exit a moment before its engine child releases the file.
    for ($attempt = 0; $attempt -lt 150; $attempt++) {
        try {
            $text = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
            Remove-Item -LiteralPath $path -Force
            return $text
        } catch [IO.IOException] {
            Start-Sleep -Milliseconds 200
        }
    }
    return "RUNNER: could not read $path`n"
}

function Finish-Suite($run) {
    $suite = $run.Suite
    $seconds = ((Get-Date) - $run.Started).TotalSeconds
    $output = ''
    foreach ($path in @($run.Stdout, $run.Stderr)) {
        if (Test-Path -LiteralPath $path) {
            $output += Read-Released $path
        }
    }
    $logPath = Join-Path $logDir ("{0}.log" -f $suite.name)
    [IO.File]::WriteAllText($logPath, $output, (New-Object Text.UTF8Encoding($false)))

    $reason = ''
    $exitCode = $run.Process.ExitCode
    $failure = if ($suite.failure) { [string]$suite.failure } else { $defaultFailure }
    if ($run.TimedOut) { $reason = "timeout after $($run.Timeout) s" }
    elseif ($exitCode -ne 0) { $reason = "exit code $exitCode" }
    if (-not $suite.allow_script_errors -and $output -match $scriptErrors) {
        $reason = (@($reason, 'script error in log') | Where-Object { $_ }) -join '; '
    }
    if ($failure -and $output -cmatch $failure) {
        $reason = (@($reason, 'failure marker in log') | Where-Object { $_ }) -join '; '
    }
    if ($suite.success -and $output -cnotmatch [string]$suite.success) {
        $reason = (@($reason, 'success marker missing') | Where-Object { $_ }) -join '; '
    }
    return [pscustomobject]@{
        Suite = $suite.name
        Result = if ($reason) { 'FAIL' } else { 'PASS' }
        Seconds = [math]::Round($seconds, 1)
        Exit = $exitCode
        Reason = $reason
    }
}

$queue = New-Object System.Collections.Queue
foreach ($suite in $selected) { $queue.Enqueue($suite) }
$running = New-Object System.Collections.ArrayList
$results = New-Object System.Collections.ArrayList
$savedAppData = $env:APPDATA
try {
    while ($queue.Count -gt 0 -or $running.Count -gt 0) {
        while ($queue.Count -gt 0 -and $running.Count -lt $Jobs) {
            $next = $queue.Peek()
            # A window suite measures real frames: it never shares the machine with other suites.
            if ($next.window -and $running.Count -gt 0) { break }
            [void]$running.Add((Start-Suite $queue.Dequeue()))
            if ($next.window) { break }
        }
        Start-Sleep -Milliseconds 200
        foreach ($run in @($running)) {
            if (-not $run.Process.HasExited -and ((Get-Date) - $run.Started).TotalSeconds -gt $run.Timeout) {
                $run.TimedOut = $true
                & taskkill /T /F /PID $run.Process.Id 2>$null | Out-Null
                $run.Process.WaitForExit(10000) | Out-Null
            }
            if ($run.Process.HasExited) {
                $result = Finish-Suite $run
                [void]$results.Add($result)
                [void]$running.Remove($run)
                Write-Host ("{0,-4} {1,-34} {2,7:N1}s  {3}" -f $result.Result, $result.Suite, $result.Seconds, $result.Reason)
            }
        }
    }
} finally {
    $env:APPDATA = $savedAppData
}

$failed = @($results | Where-Object { $_.Result -eq 'FAIL' })
Write-Host ''
Write-Host ("{0} suites, {1} failed. Logs: {2}" -f $results.Count, $failed.Count, $logDir)
$summary = [pscustomobject]@{
    finished = (Get-Date).ToString('s')
    suites = $results.Count
    failed = $failed.Count
    results = $results
}
[IO.File]::WriteAllText((Join-Path $logDir 'summary.json'), ($summary | ConvertTo-Json -Depth 4), (New-Object Text.UTF8Encoding($false)))
if ($failed.Count -gt 0) { exit 1 }
exit 0
