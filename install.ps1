param (
    [string]$InstallDir = "C:\Program Files\hackatime-doctor"
)

$Target = "hackatime-doctor.exe"
$BinPath = "$InstallDir\$Target"

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir | Out-Null
}

Copy-Item "bin\$Target" -Destination $BinPath -Force

$Path = [Environment]::GetEnvironmentVariable("PATH", "User")
if ($Path -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable("PATH", "$Path;$InstallDir", "User")
    Write-Host "Added to PATH. You may need to restart your terminal."
}

Write-Host "Installed to $BinPath"
