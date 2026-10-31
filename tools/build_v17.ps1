# Builds the 1.7 Windows x64 export into build\v17. Run with the real %APPDATA%: Godot looks for
# export templates under %APPDATA%\Godot.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'
$game = Join-Path $projectRoot 'game'
$build = Join-Path $projectRoot 'build\v17'
if ($env:APPDATA -like '*evidence*') { throw 'APPDATA is isolated in this shell; open a fresh one to export.' }
New-Item -ItemType Directory -Force -Path $build | Out-Null
& $engine --headless --path $game --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $engine --headless --path $game --export-release 'Windows Desktop' (Join-Path $build 'ColonyCharter.exe')
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\GODOT_LICENSE.txt') -Destination $build -Force
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\GODOT_COPYRIGHT.txt') -Destination $build -Force
Copy-Item -LiteralPath (Join-Path $game 'assets\fonts\OFL.txt') -Destination $build -Force
Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $build 'ColonyCharter.exe'),(Join-Path $build 'ColonyCharter.pck') |
    Format-Table Algorithm, Hash, Path -AutoSize
