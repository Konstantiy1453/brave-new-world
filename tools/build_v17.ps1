# Builds the 1.7 Windows x64 export into build\v17. Godot looks for export templates under
# %APPDATA%\Godot. If they are not installed there, the two this build needs are unpacked from
# tools\*.tpz into build\godot_home, and only this script's Godot sees that as its APPDATA.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = Join-Path $PSScriptRoot 'godot-4.5.1\Godot_v4.5.1-stable_win64_console.exe'
$game = Join-Path $projectRoot 'game'
$build = Join-Path $projectRoot 'build\v17'
$version = '4.5.1.stable'
if ($env:APPDATA -like '*evidence*') { throw 'APPDATA is isolated for tests in this shell; open a fresh one to export.' }

$installed = Join-Path $env:APPDATA "Godot\export_templates\$version\windows_release_x86_64.exe"
if (-not (Test-Path -LiteralPath $installed)) {
    $godotHome = Join-Path $projectRoot 'build\godot_home'
    $folder = Join-Path $godotHome "Godot\export_templates\$version"
    if (-not (Test-Path -LiteralPath (Join-Path $folder 'windows_release_x86_64.exe'))) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $package = Join-Path $PSScriptRoot 'Godot_v4.5.1-stable_export_templates.tpz'
        $archive = [System.IO.Compression.ZipFile]::OpenRead($package)
        try {
            foreach ($name in 'windows_release_x86_64.exe', 'windows_debug_x86_64.exe', 'version.txt') {
                $entry = $archive.GetEntry("templates/$name")
                if ($null -eq $entry) { throw "templates/$name is missing from $package" }
                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $folder $name), $true)
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    $env:APPDATA = $godotHome
}

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
