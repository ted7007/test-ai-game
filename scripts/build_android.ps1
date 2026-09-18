[CmdletBinding()]
param(
    [ValidateSet("debug", "release")]
    [string]$Mode = "debug",

    [string]$Output = "",

    [string]$Godot = "",

    [string]$CommitSha = "local",

    [string]$BuildTimestamp = "",

    [switch]$SkipValidation
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$presetName = "Android"
$metadataPath = Join-Path $projectRoot "debug/build_metadata.gd"

if ([string]::IsNullOrWhiteSpace($Godot)) {
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $Godot = $env:GODOT_BIN
    } else {
        $command = Get-Command godot -ErrorAction SilentlyContinue
        if ($null -eq $command) {
            $command = Get-Command godot4 -ErrorAction SilentlyContinue
        }
        if ($null -eq $command) {
            throw "Godot was not found. Pass -Godot <path> or set GODOT_BIN."
        }
        $Godot = $command.Source
    }
}

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot executable does not exist: $Godot"
}

if ([string]::IsNullOrWhiteSpace($Output)) {
    $Output = Join-Path $projectRoot "build/badland-prototype-$Mode.apk"
} elseif (-not [System.IO.Path]::IsPathRooted($Output)) {
    $Output = Join-Path $projectRoot $Output
}
$Output = [System.IO.Path]::GetFullPath($Output)

$outputDirectory = Split-Path -Parent $Output
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null

function Invoke-Godot {
    param([string[]]$Arguments)

    if ($IsWindows) {
        $process = Start-Process -FilePath $Godot -ArgumentList $Arguments -Wait -PassThru -NoNewWindow
        # Godot 4.0's Windows GUI binary commonly returns 1 after a successful
        # headless run. Linux CI uses the console binary and remains strict.
        if ($process.ExitCode -notin @(0, 1)) {
            throw "Godot exited with code $($process.ExitCode)."
        }
        if ($process.ExitCode -eq 1) {
            Write-Warning "Godot 4.0 for Windows returned its known headless exit code 1; output checks still apply."
        }
    } else {
        & $Godot @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Godot exited with code $LASTEXITCODE."
        }
    }
}

if ($IsWindows) {
    $version = (Get-Item -LiteralPath $Godot).VersionInfo.ProductVersion
} else {
    $versionOutput = @(& $Godot --version 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Could not determine the Godot version."
    }
    $version = (($versionOutput | ForEach-Object { $_.ToString() }) -join "`n").Trim()
}
if ([string]::IsNullOrWhiteSpace($version) -or -not $version.StartsWith("4.0")) {
    throw "This project is pinned to Godot 4.0.stable; found '$version'."
}
Write-Host "Using Godot $version"

$presetPath = Join-Path $projectRoot "export_presets.cfg"
$presetContent = Get-Content -LiteralPath $presetPath -Raw
if ($presetContent -notmatch '(?m)^version/name="([^"]+)"$') {
    throw "Android version/name was not found in export_presets.cfg."
}
$baseVersion = $Matches[1] -replace '-dev\+.*$', '' -replace '-dev$', ''
$metadataVersion = if ($Mode -eq "debug") { "$baseVersion-dev" } else { $baseVersion }
$metadataBuildType = if ($Mode -eq "debug") { "dev" } else { "release" }

if (-not (Test-Path -LiteralPath $metadataPath -PathType Leaf)) {
    throw "Build metadata source was not found: $metadataPath"
}
$originalMetadata = Get-Content -LiteralPath $metadataPath -Raw
$safeCommitSha = $CommitSha -replace '[^0-9A-Za-z._-]', ''
if ([string]::IsNullOrWhiteSpace($safeCommitSha)) {
    $safeCommitSha = "local"
}
$safeTimestamp = $BuildTimestamp -replace '[^0-9A-Za-z: ._+-]', ''
$generatedMetadata = @"
## Generated temporarily by scripts/build_android.ps1; restored when the export finishes.
extends RefCounted

const VERSION := "$metadataVersion"
const BUILD_TYPE := "$metadataBuildType"
const COMMIT_SHA := "$safeCommitSha"
const BUILD_TIMESTAMP := "$safeTimestamp"
"@

Set-Content -LiteralPath $metadataPath -Value $generatedMetadata -NoNewline

try {
    if (-not $SkipValidation) {
        Write-Host "Validating and importing project headlessly..."
        Invoke-Godot @("--headless", "--path", $projectRoot, "--editor", "--quit")
    }

    $exportFlag = if ($Mode -eq "release") { "--export-release" } else { "--export-debug" }
    Write-Host "Building $Mode APK: $Output"
    Invoke-Godot @("--headless", "--path", $projectRoot, $exportFlag, $presetName, $Output)

    if (-not (Test-Path -LiteralPath $Output -PathType Leaf)) {
        throw "Godot reported success but did not create $Output"
    }

    $apk = Get-Item -LiteralPath $Output
    Write-Host "APK created: $($apk.FullName) ($($apk.Length) bytes)"
} finally {
    Set-Content -LiteralPath $metadataPath -Value $originalMetadata -NoNewline
}
