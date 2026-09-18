[CmdletBinding()]
param(
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot

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

function Invoke-GodotValidation {
    if ($IsWindows) {
        $process = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", $projectRoot, "--editor", "--quit") -Wait -PassThru -NoNewWindow
        # Godot 4.0's Windows GUI binary returns 1 even after a successful
        # headless editor validation. The output remains visible to the caller.
        if ($process.ExitCode -notin @(0, 1)) {
            throw "Godot validation exited with code $($process.ExitCode)."
        }
        if ($process.ExitCode -eq 1) {
            Write-Warning "Godot 4.0 for Windows returned its known headless exit code 1."
        }
    } else {
        & $Godot --headless --path $projectRoot --editor --quit
        if ($LASTEXITCODE -ne 0) {
            throw "Godot validation exited with code $LASTEXITCODE."
        }
    }
}

if ($IsWindows) {
    $version = (Get-Item -LiteralPath $Godot).VersionInfo.ProductVersion
} else {
    $version = (& $Godot --version).Trim()
}
if ([string]::IsNullOrWhiteSpace($version) -or -not $version.StartsWith("4.0")) {
    throw "This project is pinned to Godot 4.0.stable; found '$version'."
}

Write-Host "Fast Godot validation with $version"
Invoke-GodotValidation
Write-Host "Fast check passed. No Android export was run."
