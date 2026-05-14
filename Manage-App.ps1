# Manage-App.ps1 — Run as Administrator
$configPath = "$PSScriptRoot\config.json"
$workerPath = "$PSScriptRoot\Set-StaticIP.ps1"
$taskName   = "AutoStaticIP_WiFiConnect"

function Get-Config {
    Get-Content $configPath | ConvertFrom-Json
}

function Save-Config($config) {
    $config | ConvertTo-Json | Out-File $configPath -Encoding UTF8
}

function Register-WifiTask {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $XML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>
        &lt;QueryList&gt;
          &lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;
            &lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;
              *[System[EventID=10000]]
            &lt;/Select&gt;
          &lt;/Query&gt;
        &lt;/QueryList&gt;
      </Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$currentUser</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT1M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NonInteractive -ExecutionPolicy Bypass -File "$workerPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
    $xmlPath = "$env:TEMP\AutoStaticIP-task.xml"
    $XML | Out-File $xmlPath -Encoding Unicode
    Register-ScheduledTask -TaskName $taskName -Xml (Get-Content $xmlPath -Raw) -Force | Out-Null
}

function Show-Status {
    $config = Get-Config
    $state  = if ($config.Enabled) { "ON " } else { "OFF" }
    $color  = if ($config.Enabled) { "Green" } else { "Red" }
    Write-Host ""
    Write-Host "  Status : " -NoNewline; Write-Host $state -ForegroundColor $color
    Write-Host "  SSID   : $($config.TargetSSID)  ($($config.DeviceType))"
    Write-Host "  IP     : $($config.StaticIP)/$($config.PrefixLength)  GW $($config.Gateway)"
    Write-Host "  DNS    : $($config.DNS -join ', ')"
    Write-Host ""
}

while ($true) {
    Clear-Host
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "   Auto-StaticIP Manager" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Show-Status
    Write-Host "  1  Turn ON"
    Write-Host "  2  Turn OFF"
    Write-Host "  3  Test a URL"
    Write-Host "  4  Exit"
    Write-Host ""
    $choice = Read-Host "  Option"

    switch ($choice) {
        "1" {
            Register-WifiTask
            $config = Get-Config
            $config.Enabled = $true
            Save-Config $config
            $currentSSID = (netsh wlan show interfaces | Select-String "^\s+SSID\s+:" | Select-Object -First 1) -replace ".*SSID\s+:\s+", ""
            if ($currentSSID.Trim() -eq $config.TargetSSID) {
                Write-Host ""
                Write-Host "  Already on target network - applying static IP now..." -ForegroundColor Cyan
                & $workerPath
            }
            Write-Host ""
            Write-Host "  Automation is ON. Fires on every WiFi connect (Event 10000)." -ForegroundColor Green
            Pause
        }
        "2" {
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
            $config = Get-Config
            $config.Enabled = $false
            Save-Config $config
            $iface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }).Name
            if ($iface) {
                Set-NetIPInterface -InterfaceAlias $iface -Dhcp Enabled -ErrorAction SilentlyContinue
                Set-DnsClientServerAddress -InterfaceAlias $iface -ResetServerAddresses -ErrorAction SilentlyContinue
                Write-Host ""
                Write-Host "  Adapter reset to DHCP." -ForegroundColor Yellow
            }
            Write-Host "  Automation is OFF." -ForegroundColor Yellow
            Pause
        }
        "3" {
            Write-Host ""
            $url = Read-Host "  URL to test (e.g. https://example.com)"
            if ($url -notmatch "^https?://") { $url = "https://$url" }
            Write-Host "  Checking $url ..." -ForegroundColor Cyan
            try {
                $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 7 -ErrorAction Stop
                Write-Host "  Reachable - HTTP $($response.StatusCode)" -ForegroundColor Green
            } catch {
                Write-Host "  Unreachable - $($_.Exception.Message)" -ForegroundColor Red
            }
            Pause
        }
        "4" { exit }
    }
}