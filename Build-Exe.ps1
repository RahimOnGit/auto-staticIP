# Build-Exe.ps1 — Run once to compile AutoStaticIP.ps1 into AutoStaticIP.exe
# Requires ps2exe: Install-Module ps2exe -Scope CurrentUser

if (-not (Get-Module -ListAvailable -Name ps2exe)) {
    Write-Host "Installing ps2exe..." -ForegroundColor Cyan
    Install-Module ps2exe -Scope CurrentUser -Force
}

Import-Module ps2exe

Invoke-ps2exe `
    -InputFile  "$PSScriptRoot\AutoStaticIP.ps1" `
    -OutputFile "$PSScriptRoot\AutoStaticIP.exe" `
    -NoConsole `
    -RequireAdmin `
    -Title      "Auto Static IP" `
    -Description "Auto Static IP Manager" `
    -Version    "2.0.0"

Write-Host ""
Write-Host "Done! AutoStaticIP.exe created." -ForegroundColor Green
Write-Host "Place it in the same folder as Set-StaticIP.ps1 and config.json." -ForegroundColor Cyan