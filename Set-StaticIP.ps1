# Set-StaticIP.ps1 — worker, called by scheduled task (runs as current user, elevated)

# ── Admin check ────────────────────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { exit 1 }

# ── Paths ──────────────────────────────────────────────────────────────────────
$configPath = "$env:APPDATA\AutoStaticIP\config.json"
$logPath    = "$env:APPDATA\AutoStaticIP\app.log"

function Write-Log($msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Add-Content -Path $logPath -Value $line
}

# ── Load config ────────────────────────────────────────────────────────────────
if (-not (Test-Path $configPath)) { Write-Log "Config not found."; exit 1 }

$CONFIG = Get-Content $configPath -Raw | ConvertFrom-Json

if (-not $CONFIG.Enabled) {
    $iface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }).Name
    if ($iface) {
        Set-NetIPInterface -InterfaceAlias $iface -Dhcp Enabled -ErrorAction SilentlyContinue
        Set-DnsClientServerAddress -InterfaceAlias $iface -ResetServerAddresses -ErrorAction SilentlyContinue
        Write-Log "Disabled — adapter '$iface' reset to DHCP."
    }
    exit
}

# ── Get current SSID ───────────────────────────────────────────────────────────
$ssidLine    = netsh wlan show interfaces | Select-String "^\s+SSID\s+:" | Select-Object -First 1
$currentSSID = if ($ssidLine) { ($ssidLine -replace ".*SSID\s+:\s+","").Trim() } else { "" }

if (-not $currentSSID) { Write-Log "No WiFi connection detected."; exit }

# ── Match profile ──────────────────────────────────────────────────────────────
$profile = $CONFIG.Profiles | Where-Object { $_.SSID -eq $currentSSID } | Select-Object -First 1

if (-not $profile) {
    $iface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }).Name
    if ($iface) {
        Set-NetIPInterface -InterfaceAlias $iface -Dhcp Enabled -ErrorAction SilentlyContinue
        Set-DnsClientServerAddress -InterfaceAlias $iface -ResetServerAddresses -ErrorAction SilentlyContinue
        Write-Log "SSID '$currentSSID' has no matching profile — reset to DHCP."
    }
    exit
}

Write-Log "Matched profile '$($profile.Name)' for SSID '$currentSSID'."

# ── Find adapter ───────────────────────────────────────────────────────────────
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and ($_.Name -like "*Wi-Fi*" -or $_.InterfaceDescription -like "*Wireless*") } | Select-Object -First 1

if (-not $adapter) { Write-Log "No active WiFi adapter found."; exit 1 }

# ── Skip if already correctly configured ──────────────────────────────────────
$existingIP = (Get-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -eq $profile.StaticIP })
if ($existingIP -and $existingIP.PrefixLength -eq $profile.PrefixLength) {
    Write-Log "IP $($profile.StaticIP) already applied — skipping."
    exit
}

# ── Apply static IP ────────────────────────────────────────────────────────────
try {
    # Disable DHCP first
    Set-NetIPInterface -InterfaceAlias $adapter.Name -Dhcp Disabled -ErrorAction SilentlyContinue

    # Remove existing IPs
    Get-NetIPAddress -InterfaceAlias $adapter.Name -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

    # Remove ONLY default gateway route (preserve VPN/secondary routes)
    Get-NetRoute -InterfaceAlias $adapter.Name -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue

    New-NetIPAddress `
        -InterfaceAlias $adapter.Name `
        -IPAddress      $profile.StaticIP `
        -PrefixLength   $profile.PrefixLength `
        -DefaultGateway $profile.Gateway `
        -ErrorAction Stop | Out-Null

    Set-DnsClientServerAddress `
        -InterfaceAlias $adapter.Name `
        -ServerAddresses $profile.DNS `
        -ErrorAction Stop

    Write-Log "SUCCESS — $($profile.StaticIP)/$($profile.PrefixLength) via $($profile.Gateway) on '$($adapter.Name)'."
} catch {
    Write-Log "FAILED — $_"
}