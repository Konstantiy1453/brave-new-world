[CmdletBinding()]
param(
    [string]$Workspace = (Split-Path -Parent $PSScriptRoot)
)

# Packaging only: this script neither builds nor plays the game. Run after the
# final VALIDATION.md has been written and the EXE/PCK pair has been verified.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$packageRoot = [System.IO.Path]::GetFullPath($Workspace)
$deliveryRoot = Join-Path $packageRoot 'delivery'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$stageRoot = Join-Path $deliveryRoot ('.staging-' + [guid]::NewGuid().ToString('N'))
$sourceStage = Join-Path $stageRoot 'source'
$windowsStage = Join-Path $stageRoot 'windows'

function Assert-WithinDirectory {
    param([string]$Path, [string]$Base)
    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $resolvedBase = [System.IO.Path]::GetFullPath($Base).TrimEnd('\', '/')
    if (-not $resolvedPath.StartsWith($resolvedBase + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is not a child of the intended directory: $resolvedPath"
    }
}

function Require-File {
    param([string]$Relative)
    $path = Join-Path $packageRoot $Relative
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required delivery file is missing: $Relative" }
}

function Copy-One {
    param([string]$Source, [string]$Destination)
    $parent = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Copy-CleanTree {
    param([string]$Source, [string]$Destination)
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "Missing source directory: $Source" }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($entry in Get-ChildItem -LiteralPath $Source -Force) {
        if ($entry.Name -in @('.git', '.godot', '__pycache__')) { continue }
        if (($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Refusing to traverse a junction or symbolic link during packaging: $($entry.FullName)"
        }
        $target = Join-Path $Destination $entry.Name
        if ($entry.PSIsContainer) {
            Copy-CleanTree -Source $entry.FullName -Destination $target
        } elseif ($entry.Extension -notin @('.bak', '.tmp', '.pyc')) {
            Copy-One -Source $entry.FullName -Destination $target
        }
    }
}

function Add-FinalEvidence {
    param([string]$TargetRoot)
    foreach ($folder in @('screenshots', 'screenshots_final', 'screenshots_release', 'screenshots_v1_5')) {
        $captures = Join-Path $packageRoot ('evidence\' + $folder)
        if (Test-Path -LiteralPath $captures -PathType Container) {
            Copy-CleanTree -Source $captures -Destination (Join-Path $TargetRoot ('evidence\' + $folder))
        }
    }
    foreach ($entry in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'evidence') -File) {
        # Preserve actual UI screenshots and earlier failure evidence alongside
        # final logs; visual/runtime reports distinguish their source versions.
        if ($entry.Extension -in @('.png', '.json', '.log', '.gd', '.md') -and $entry.Length -lt 16777216) {
            Copy-One -Source $entry.FullName -Destination (Join-Path $TargetRoot ('evidence\' + $entry.Name))
        }
    }
    # Small legacy snapshots are needed for the compatibility probes. Preserve
    # their identity without duplicating old executable directories in each ZIP.
    $legacyEvidence = Join-Path $packageRoot 'evidence\v1_4'
    if (Test-Path -LiteralPath $legacyEvidence -PathType Container) {
        foreach ($entry in Get-ChildItem -LiteralPath $legacyEvidence -File) {
            if ($entry.Extension -in @('.json', '.gd', '.md', '.log') -and $entry.Length -lt 16777216) {
                Copy-One -Source $entry.FullName -Destination (Join-Path $TargetRoot ('evidence\v1_4\' + $entry.Name))
            }
        }
    }
}

function New-Manifest {
    param([string]$Directory, [string]$Kind)
    $prefix = [System.IO.Path]::GetFullPath($Directory).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $rows = @()
    $total = [long]0
    foreach ($file in Get-ChildItem -LiteralPath $Directory -Recurse -File | Sort-Object FullName) {
        $relative = $file.FullName.Substring($prefix.Length).Replace('\', '/')
        $rows += [ordered]@{ path = $relative; bytes = $file.Length; sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() }
        $total += $file.Length
    }
    $manifest = [ordered]@{
        package = $Kind
        created_utc = (Get-Date).ToUniversalTime().ToString('o')
        scope = 'File packaging and byte verification only; runtime/visual acceptance is recorded in docs/VALIDATION.md.'
        manifest_excludes_itself = $true
        file_count = $rows.Count
        total_uncompressed_bytes = $total
        files = $rows
    }
    $json = $manifest | ConvertTo-Json -Depth 8
    [System.IO.File]::WriteAllText((Join-Path $Directory 'PACKAGE_MANIFEST.json'), $json, [System.Text.UTF8Encoding]::new($false))
    return $rows
}

function Verify-Zip {
    param([string]$Archive, [object[]]$Rows, [string[]]$RequiredEntries)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $expected = @{}
        foreach ($row in $Rows) { $expected[$row.path] = $row }
        $seen = @{}
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ([string]::IsNullOrEmpty($entry.Name)) { continue }
            if ($name -match '(^|/)(\.git|\.godot)(/|$)' -or $name -match '(^|/)\.\.(/|$)' -or $name.StartsWith('/')) { throw "Forbidden archive path: $name" }
            if ($seen.ContainsKey($name)) { throw "Duplicate archive entry: $name" }
            $seen[$name] = $true
            if ($name -eq 'PACKAGE_MANIFEST.json') { continue }
            if (-not $expected.ContainsKey($name)) { throw "Unmanifested archive entry: $name" }
            if ($entry.Length -ne $expected[$name].bytes) { throw "Archive size mismatch: $name" }
            $stream = $entry.Open()
            $algorithm = [System.Security.Cryptography.SHA256]::Create()
            try {
                $digest = [System.BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-', '').ToLowerInvariant()
            } finally {
                $algorithm.Dispose()
                $stream.Dispose()
            }
            if ($digest -ne $expected[$name].sha256) { throw "Archive SHA256 mismatch: $name" }
        }
        foreach ($name in @($RequiredEntries) + @('PACKAGE_MANIFEST.json')) {
            if (-not $seen.ContainsKey($name)) { throw "Required ZIP path is absent: $name" }
        }
        if ($seen.Count -ne $Rows.Count + 1) { throw 'Archive/manifest file count mismatch' }
    } finally { $zip.Dispose() }
}

function Publish-Archive {
    param([string]$Staging, [string]$Name, [object[]]$Rows, [string[]]$RequiredEntries)
    $temporary = Join-Path $stageRoot ($Name + '.tmp.zip')
    [System.IO.Compression.ZipFile]::CreateFromDirectory($Staging, $temporary, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    Verify-Zip -Archive $temporary -Rows $Rows -RequiredEntries $RequiredEntries
    $destination = Join-Path $deliveryRoot $Name
    Assert-WithinDirectory -Path $temporary -Base $deliveryRoot
    Assert-WithinDirectory -Path $destination -Base $deliveryRoot
    if (Test-Path -LiteralPath $destination -PathType Leaf) {
        $previous = Join-Path $deliveryRoot ($Name + '.previous-' + $stamp + '-' + [guid]::NewGuid().ToString('N').Substring(0, 6))
        Assert-WithinDirectory -Path $previous -Base $deliveryRoot
        Move-Item -LiteralPath $destination -Destination $previous
    }
    Move-Item -LiteralPath $temporary -Destination $destination
    return [ordered]@{ path = $Name; bytes = (Get-Item -LiteralPath $destination).Length; sha256 = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant(); verified = 'all non-manifest entries match staging SHA256 and required paths present' }
}

$required = @(
    'README.md', 'DEMO_AGENT_PROMPT.txt', 'docs\VALIDATION.md', 'docs\REPRODUCTION.md',
    'game\project.godot', 'game\data\acceptance_midgame.json', 'game\data\acceptance_success.json',
    'build\ColonyCharter.exe', 'build\ColonyCharter.pck', 'build\GODOT_LICENSE.txt', 'build\GODOT_COPYRIGHT.txt', 'build\OFL.txt'
)
foreach ($relative in $required) { Require-File -Relative $relative }
New-Item -ItemType Directory -Path $deliveryRoot -Force | Out-Null
New-Item -ItemType Directory -Path $sourceStage, $windowsStage -Force | Out-Null

try {
    # Source ZIP root retains README's relative game/, docs/, saves/, tools/ paths.
    Copy-CleanTree -Source (Join-Path $packageRoot 'game') -Destination (Join-Path $sourceStage 'game')
    Copy-CleanTree -Source (Join-Path $packageRoot 'docs') -Destination (Join-Path $sourceStage 'docs')
    foreach ($file in @('README.md', 'DEMO_AGENT_PROMPT.txt')) {
        Copy-One -Source (Join-Path $packageRoot $file) -Destination (Join-Path $sourceStage $file)
    }
    # Include only small human-readable tool scripts/metadata, never engine or template downloads.
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'tools') -File) {
        if ($file.Extension -in @('.ps1', '.py', '.gd', '.md', '.json', '.txt') -and $file.Length -lt 2097152) {
            Copy-One -Source $file.FullName -Destination (Join-Path $sourceStage ('tools\' + $file.Name))
        }
    }
    Copy-CleanTree -Source (Join-Path $packageRoot 'build') -Destination (Join-Path $windowsStage 'build')
    Copy-One -Source (Join-Path $packageRoot 'README.md') -Destination (Join-Path $windowsStage 'README.md')
    $windowsReports = @('VALIDATION.md', 'VALIDATION_V1_4.md', 'REPRODUCTION.md', 'ASSETS.md', 'ENVIRONMENT.md', 'SIM_REPORT.md', 'WORLD_REPORT.md', 'SEED_DIVERSITY.md', 'HYDROLOGY_REPORT.md', 'FLAT_MAP_V15_QA.md', 'VISUAL_QA.md', 'VISUAL_RELEASE_QA.md', 'REVIEW.md', 'REQUIREMENT_MATRIX.md', 'GODOT_LICENSE.txt', 'GODOT_COPYRIGHT.txt')
    foreach ($name in $windowsReports) {
        Require-File -Relative ('docs\' + $name)
        Copy-One -Source (Join-Path $packageRoot ('docs\' + $name)) -Destination (Join-Path $windowsStage ('docs\' + $name))
    }
    foreach ($report in Get-ChildItem -LiteralPath (Join-Path $packageRoot 'docs') -File -Filter 'VISUAL*.md') {
        Copy-One -Source $report.FullName -Destination (Join-Path $windowsStage ('docs\' + $report.Name))
    }
    $docEvidence = Join-Path $packageRoot 'docs\evidence'
    if (Test-Path -LiteralPath $docEvidence -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $docEvidence -File) {
            if ($file.Extension -in @('.json', '.log', '.md', '.txt') -and $file.Length -lt 2097152) {
                Copy-One -Source $file.FullName -Destination (Join-Path $windowsStage ('docs\evidence\' + $file.Name))
            }
        }
    }
    foreach ($stage in @($sourceStage, $windowsStage)) {
        $saveSource = Join-Path $packageRoot 'saves'
        if (Test-Path -LiteralPath $saveSource -PathType Container) { Copy-CleanTree -Source $saveSource -Destination (Join-Path $stage 'saves') }
        foreach ($saveName in @('acceptance_midgame.json', 'acceptance_success.json')) {
            Copy-One -Source (Join-Path $packageRoot ('game\data\' + $saveName)) -Destination (Join-Path $stage ('saves\' + $saveName))
        }
        Add-FinalEvidence -TargetRoot $stage
    }
    $sourceRows = @(New-Manifest -Directory $sourceStage -Kind 'ColonyCharter_Source')
    $windowsRows = @(New-Manifest -Directory $windowsStage -Kind 'ColonyCharter_Windows')
    $sourceResult = Publish-Archive -Staging $sourceStage -Name 'ColonyCharter_Source.zip' -Rows $sourceRows -RequiredEntries @('README.md', 'game/project.godot', 'game/world/world_gen.gd', 'game/tests/sim_tests.gd', 'game/assets/fonts/main_medium.ttf', 'tools/build.ps1', 'tools/package.ps1', 'docs/VALIDATION.md')
    $windowsResult = Publish-Archive -Staging $windowsStage -Name 'ColonyCharter_Windows.zip' -Rows $windowsRows -RequiredEntries @('README.md', 'build/ColonyCharter.exe', 'build/ColonyCharter.pck', 'build/OFL.txt', 'saves/acceptance_midgame.json', 'saves/acceptance_success.json', 'docs/VALIDATION.md')
    $results = [ordered]@{ generated_utc = (Get-Date).ToUniversalTime().ToString('o'); scope = 'PACKAGING_VERIFIED only, not a runtime acceptance verdict'; archives = @($sourceResult, $windowsResult) }
    [System.IO.File]::WriteAllText((Join-Path $deliveryRoot 'PACKAGE_HASHES.json'), ($results | ConvertTo-Json -Depth 6), [System.Text.UTF8Encoding]::new($false))
    $results | ConvertTo-Json -Depth 6
    # This is the only recursive deletion: an explicitly verified, unique staging
    # child of delivery. Original game/build/docs/saves/tools trees are untouched.
    Assert-WithinDirectory -Path $stageRoot -Base $deliveryRoot
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
} catch {
    Write-Warning "Packaging did not complete. Staging evidence retained at: $stageRoot"
    throw
}
