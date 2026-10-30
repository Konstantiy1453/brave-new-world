$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'
$game = Join-Path $projectRoot 'game'
$build = Join-Path $projectRoot 'build\v16'
New-Item -ItemType Directory -Force -Path $build | Out-Null
& $engine --headless --path $game --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $engine --headless --path $game --export-release 'Windows Desktop' (Join-Path $build 'ColonyCharter.exe')
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\GODOT_LICENSE.txt') -Destination $build
Copy-Item -LiteralPath (Join-Path $projectRoot 'docs\GODOT_COPYRIGHT.txt') -Destination $build
Copy-Item -LiteralPath (Join-Path $game 'assets\fonts\OFL.txt') -Destination $build
Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $build 'ColonyCharter.exe'),(Join-Path $build 'ColonyCharter.pck') | Format-List
