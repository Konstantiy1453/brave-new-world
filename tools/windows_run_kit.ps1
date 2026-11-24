<#
Colony Charter 1.11.0 - Windows run kit (2026-11-24).

Runs the packaged game from the delivery ZIP (ColonyCharter.exe with its own ColonyCharter.pck)
through the automated drivers on this Windows PC, with user data isolated, and packs every log
and record into one ZIP to send back. Instructions and pass/fail criteria:
docs/v17/WINDOWS_RUN_KIT.md.

PowerShell, from the repository root (branch v17-charter at 8ecc070 or later):

  powershell -ExecutionPolicy Bypass -File tools\windows_run_kit.ps1 -Zip <path>\ColonyCharter-1.11.0-Windows-x64.zip

  -Suites   also runs the checks that only run on Windows (v17_saves, v18_systems,
            world_v16_seed, v17_tutorial) from the source project with tools\run_tests.ps1
  -Only     comma-separated cases to run (default: all eight)
  -Engine   another executable for the driver cases, if the packaged EXE will not run a
            script: tools\godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe (same engine, same PCK)

Nothing here writes to %APPDATA%\ColonyCharter: APPDATA points into the kit's own folder for
every game the kit starts, and the player's saves are never read or written.
#>
param(
    [Parameter(Mandatory = $true)][string]$Zip,
    [string]$ExpectedSha = "CEA06CCF7F4DD9D122951E560E46FD2850406241FD18B514F9744FB94D8DAC5A",
    [switch]$Suites,
    [string]$Only = "",
    [string]$Engine = ""
)
$ErrorActionPreference = "Stop"
$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Kit = Join-Path $Repo "evidence\v17\windows_kit\$Stamp"
$Game = Join-Path $Kit "game"
$Out = Join-Path $Kit "out"
$UserData = Join-Path $Kit "userdata"
New-Item -ItemType Directory -Force -Path $Game, $Out, $UserData | Out-Null
$Summary = Join-Path $Out "SUMMARY.txt"

function Note([string]$Text) {
    Add-Content -Path $Summary -Value $Text -Encoding UTF8
    Write-Host $Text
}

Note "KIT_START $(Get-Date -Format s) repo=$Repo commit=$(git -C $Repo rev-parse --short HEAD 2>$null)"
Note "WINDOWS $([Environment]::OSVersion.VersionString) PS=$($PSVersionTable.PSVersion)"

# 0. The archive is the one that was built.
$Sha = (Get-FileHash -Algorithm SHA256 $Zip).Hash
Note "ZIP_SHA256 $Sha expected=$ExpectedSha match=$($Sha -eq $ExpectedSha)"
Expand-Archive -Force -Path $Zip -DestinationPath $Game
$Exe = Join-Path $Game "ColonyCharter.exe"
$Pck = Join-Path $Game "ColonyCharter.pck"
$Runner = if ($Engine -ne "") { (Resolve-Path $Engine).Path } else { $Exe }
Note "EXE_SHA256 $((Get-FileHash -Algorithm SHA256 $Exe).Hash)"
Note "PCK_SHA256 $((Get-FileHash -Algorithm SHA256 $Pck).Hash)"
Note "DRIVER_RUNNER $Runner"

# User data isolated for every game this kit starts (the real value comes back for the suites,
# whose runner isolates its own).
$RealAppData = $env:APPDATA
$env:APPDATA = $UserData

# The outpost cases play to the expansion licence with the balanced bot: a copy of the bots whose
# extends lines point at the copy (the shipped PCK has no tests folder).
$Bots = Join-Path $Kit "bots"
New-Item -ItemType Directory -Force -Path $Bots | Out-Null
$BotsSlash = $Bots -replace "\\", "/"
foreach ($Name in "bot.gd", "colony_bot.gd", "balanced_bot.gd", "contract_play.gd") {
    $Text = [IO.File]::ReadAllText((Join-Path $Repo "game\tests\balance\bots\$Name"))
    $Text = $Text.Replace("res://tests/balance/bots/", "$BotsSlash/")
    [IO.File]::WriteAllText((Join-Path $Bots $Name), $Text, (New-Object Text.UTF8Encoding $false))
}
$Placement = Join-Path $Repo "tools\verify\placement_driver.gd"
$Carry = Join-Path $Repo "tools\verify\save_carry_driver.gd"

# One driver case: the packaged EXE with its PCK, a log of its own, a JSON record, a time limit.
function Run-Case([string]$Name, [string]$Script, [string[]]$CaseArgs, [int]$TimeoutSec) {
    if ($Only -ne "" -and -not (($Only -split ",") -contains $Name)) { return }
    $Log = Join-Path $Out "$Name.log"
    $Record = Join-Path $Out "$Name.json"
    $ArgList = @("--main-pack", "`"$Pck`"", "--log-file", "`"$Log`"", "--script", "`"$Script`"", "--") + $CaseArgs + @("--out=`"$Record`"")
    $Started = Get-Date
    Note "CASE_START $Name $(Get-Date -Format T) timeout=${TimeoutSec}s"
    $Process = Start-Process -FilePath $Runner -ArgumentList $ArgList -PassThru
    if (-not $Process.WaitForExit($TimeoutSec * 1000)) {
        $Process.Kill()
        Note "CASE_DIED $Name timeout ${TimeoutSec}s"
        return
    }
    $Seconds = [int]((Get-Date) - $Started).TotalSeconds
    $Errors = 0
    if (Test-Path $Log) { $Errors = (Select-String -Path $Log -Pattern "SCRIPT ERROR" -SimpleMatch).Count }
    if (Test-Path $Record) {
        $Json = Get-Content -Raw -Encoding UTF8 $Record | ConvertFrom-Json
        $Failed = @($Json.checks | Where-Object { -not $_.ok }).Count
        $Verdict = if ($Json.ok -and $Failed -eq 0 -and $Errors -eq 0) { "PASS" } else { "FAIL" }
        Note "CASE_$Verdict $Name checks=$(@($Json.checks).Count) failed=$Failed script_errors=$Errors exit=$($Process.ExitCode) ${Seconds}s"
        foreach ($Check in @($Json.checks | Where-Object { -not $_.ok })) { Note "  FAILED: $($Check.label)" }
    } else {
        Note "CASE_FAIL $Name no record written; exit=$($Process.ExitCode) script_errors=$Errors ${Seconds}s"
    }
}

# 1. Free placement through the real interface (the same six cases as docs/v17/placement/README.md,
#    95 checks on the Linux runtime).
Run-Case "cap_globe" $Placement @("--case=capital", "--view=planet", "--seed=3", "--target=0", "--pck=`"$Pck`"") 900
Run-Case "cap_flat" $Placement @("--case=capital", "--view=flat", "--seed=3", "--target=1", "--pck=`"$Pck`"") 900
Run-Case "regression" $Placement @("--case=regression", "--seed=3", "--pck=`"$Pck`"") 900
Run-Case "refusal" $Placement @("--case=refusal", "--seed=3", "--pck=`"$Pck`"") 900
Run-Case "out_inland_globe" $Placement @("--case=outpost", "--view=planet", "--coast=0", "--seed=3", "--bots=`"$Bots`"", "--pck=`"$Pck`"") 3600
Run-Case "out_coast_flat" $Placement @("--case=outpost", "--view=flat", "--coast=1", "--seed=3", "--bots=`"$Bots`"", "--pck=`"$Pck`"") 3600

# 2. A 1.10.0 save carries over to this build (1.11 upgrades it to schema 7 on load).
$Before = Join-Path $Repo "docs\v17\placement\save_files\before-1.10.0.save"
$BeforeRecord = Join-Path $Repo "docs\v17\placement\save_make_1.10.0.json"
Run-Case "save_carry" $Carry @("--check", "--save=`"$Before`"", "--after=`"$(Join-Path $Out 'after.save')`"", "--before=`"$BeforeRecord`"") 900

# 3. The game starts and runs on its own for a while (no driver): the log must stay clean.
if ($Only -eq "" -or (($Only -split ",") -contains "boot")) {
    $BootLog = Join-Path $Out "boot.log"
    Note "CASE_START boot $(Get-Date -Format T) (closes itself after 3000 frames)"
    $Boot = Start-Process -FilePath $Exe -ArgumentList @("--main-pack", "`"$Pck`"", "--log-file", "`"$BootLog`"", "--quit-after", "3000") -PassThru
    if (-not $Boot.WaitForExit(600000)) { $Boot.Kill(); Note "CASE_DIED boot timeout 600s" }
    else {
        $BootErrors = 0
        if (Test-Path $BootLog) { $BootErrors = (Select-String -Path $BootLog -Pattern "SCRIPT ERROR" -SimpleMatch).Count }
        $BootVerdict = if ((Test-Path $BootLog) -and $BootErrors -eq 0) { "PASS" } else { "FAIL" }
        Note "CASE_$BootVerdict boot script_errors=$BootErrors exit=$($Boot.ExitCode) log=$(Test-Path $BootLog)"
    }
}

# 4. Optional: the checks that only run on Windows, from the source project.
if ($Suites) {
    $env:APPDATA = $RealAppData
    Note "SUITES_START $(Get-Date -Format T)"
    & powershell -ExecutionPolicy Bypass -File (Join-Path $Repo "tools\run_tests.ps1") -Only "v17_saves,v18_systems,world_v16_seed,v17_tutorial" -Jobs 2 *>&1 | Tee-Object -FilePath (Join-Path $Out "suites.txt")
    Copy-Item -Force (Join-Path $Repo "evidence\v17\tests\v17_saves.log"), (Join-Path $Repo "evidence\v17\tests\v18_systems.log"), (Join-Path $Repo "evidence\v17\tests\world_v16_seed.log"), (Join-Path $Repo "evidence\v17\tests\v17_tutorial.log") $Out -ErrorAction SilentlyContinue
    Note "SUITES_DONE $(Get-Date -Format T) (see suites.txt)"
}

# 5. Everything the game wrote under the isolated user data (its own logs included), then one ZIP.
if (Test-Path $UserData) {
    Get-ChildItem -Recurse -Filter "*.log" $UserData | ForEach-Object { Copy-Item -Force $_.FullName (Join-Path $Out ("userdata_" + $_.Name)) }
}
$Pass = (Select-String -Path $Summary -Pattern "CASE_PASS").Count
$Fail = (Select-String -Path $Summary -Pattern "CASE_FAIL|CASE_DIED").Count
Note "KIT_DONE $(Get-Date -Format s) pass=$Pass fail=$Fail"
$Results = Join-Path $Kit "windows-kit-results-$Stamp.zip"
Compress-Archive -Force -Path (Join-Path $Out "*") -DestinationPath $Results
Note "SEND_BACK $Results"
