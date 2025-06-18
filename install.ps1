param (
    [string]$InstallDir = "$env:ProgramFiles\hackatime-doctor"
)

$ErrorActionPreference = "Stop"
$Target = "hackatime-doctor.exe"

$BinPath = $null
$PossiblePaths = @(
    ".\$Target",
    ".\bin\$Target",
    "$PSScriptRoot\$Target",
    "$PSScriptRoot\bin\$Target"
)

foreach ($path in $PossiblePaths) {
    if (Test-Path $path -PathType Leaf) {
        $BinPath = $path
        break
    }
}

if (-not $BinPath) {
    Write-Host "Error: Could not find $Target in any of these locations:"
    $PossiblePaths | ForEach-Object { Write-Host "  $_" }
    Write-Host "Please run this script from your extracted release package directory"
    exit 1
}

if (-not (Test-Path $InstallDir -PathType Container)) {
    try {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        Write-Host "Created installation directory: $InstallDir"
    } catch {
        Write-Host "Error: Failed to create installation directory: $_"
        exit 1
    }
}

try {
    Copy-Item $BinPath -Destination "$InstallDir\$Target" -Force
    Write-Host "✅ Successfully installed to: $InstallDir\$Target"
} catch {
    Write-Host "Error: Failed to copy binary: $_"
    exit 1
}

$CurrentPath = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($CurrentPath -notlike "*$InstallDir*") {
    try {
        if (([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
            $SystemPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
            if ($SystemPath -notlike "*$InstallDir*") {
                [Environment]::SetEnvironmentVariable("PATH", "$SystemPath;$InstallDir", "Machine")
                Write-Host "✔️ Added to system PATH (machine-wide)"
            }
        } else {
            [Environment]::SetEnvironmentVariable("PATH", "$CurrentPath;$InstallDir", "User")
            Write-Host "✔️ Added to user PATH"
        }
        Write-Host "Note: You may need to restart your terminal for PATH changes to take effect"
    } catch {
        Write-Host "⚠️ Warning: Could not update PATH: $_"
        Write-Host "You may need to manually add $InstallDir to your PATH"
    }
} else {
    Write-Host "ℹ️ Install directory is already in your PATH"
}

try {
    $Version = & "$InstallDir\$Target" --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✔️ Verification successful: $Version"
   
