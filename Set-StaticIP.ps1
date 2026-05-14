# Set-StaticIP.ps1
$configPath = "$PSScriptRoot\config.json"
if (-not (Test-Path $configPath)) { exit }
$CONFIG = Get-Content $configPath | ConvertFrom-Json

# --- FIX 1: Define the Log Function FIRST ---
function Write-Log($msg) {
    $logFile = $CONFIG.LogFile
    if (-not $logFile) { $logFile = "$env:USERPROFILE\set-static-ip.log" }
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

# --- FIX 2: Get the SSID BEFORE checking it ---
$wifiInfo = netsh wlan show interfaces
$ssidLine = $wifiInfo | Select-String "^\s+SSID\s+:" | Select-Object -First 1
$currentSSID = ($ssidLine -replace ".*SSID\s+:\s+", "").Trim()

$iface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }).Name

# --- FIX 3: Logic Checks ---
if ($CONFIG.Enabled -ne $true) {
    if ($iface) {
        Set-NetIPInterface -InterfaceAlias $iface -Dhcp Enabled -ErrorAction SilentlyContinue
        Set-DnsClientServerAddress -InterfaceAlias $iface -ResetServerAddresses -ErrorAction SilentlyContinue
    }
    exit
}

if ($currentSSID -ne $CONFIG.TargetSSID) {
    if ($iface) {
        # Reset to DHCP if we leave the hotspot
        Set-NetIPInterface -InterfaceAlias $iface -Dhcp Enabled -ErrorAction SilentlyContinue
        Set-DnsClientServerAddress -InterfaceAlias $iface -ResetServerAddresses -ErrorAction SilentlyContinue
    }
    exit 0
}

# --- FIX 4: Apply Static IP ---
Write-Log "Target Network '$currentSSID' detected. Configuring for $($CONFIG.DeviceType)..."

$adapter = Get-NetAdapter | Where-Object {
    $_.Status -eq "Up" -and ($_.Name -like "*Wi-Fi*" -or $_.InterfaceDescription -like "*Wireless*")
} | Select-Object -First 1

if (-not $adapter) {
    Write-Log "ERROR: No active WiFi adapter found."
    exit 1
}

try {
    # Full reset: clear IP, routes, DNS before applying static config
    Set-NetIPInterface -InterfaceAlias $adapter.Name -Dhcp Disabled -ErrorAction SilentlyContinue
    Get-NetIPAddress -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
    Get-NetRoute     -InterfaceAlias $adapter.Name -ErrorAction SilentlyContinue | Remove-NetRoute     -Confirm:$false -ErrorAction SilentlyContinue

    New-NetIPAddress -InterfaceAlias $adapter.Name -IPAddress $CONFIG.StaticIP -PrefixLength $CONFIG.PrefixLength -DefaultGateway $CONFIG.Gateway -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses $CONFIG.DNS -ErrorAction Stop
    Write-Log "✅ Success! Static IP applied."
} catch {
    Write-Log "❌ FAILED: $_"
}