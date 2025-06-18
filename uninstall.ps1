param (
    [string]$InstallDir = "C:\Program Files\hackatime-doctor"
)

$Target = "hackatime-doctor.exe"
$BinPath = "$InstallDir\$Target"

if (Test-Path $BinPath) {
    Remove-Item $BinPath -Force
    Write-Host "Removed $BinPath"
}

if ((Get-ChildItem $InstallDir -ErrorAction SilentlyContinue).Count -eq 0) {
    Remove-Item $InstallDir -Force
    Write-Host "Removed empty directory $InstallDir"
}

$Path = [Environment]::GetEnvironmentVariable("PATH", "User") -replace [regex]::Escape($InstallDir), ""
[Environment]::SetEnvironmentVariable("PATH", $Path, "User")
Write-Host "Removed from PATH. Restart your terminal to apply changes."
