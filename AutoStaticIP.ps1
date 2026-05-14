# AutoStaticIP.ps1 - GUI App, Run as Administrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$scriptDir  = Split-Path ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
$configPath = "$scriptDir\config.json"
$workerPath  = "$scriptDir\Set-StaticIP.ps1"
$taskName    = "AutoStaticIP_WiFiConnect"

# ── Helpers ────────────────────────────────────────────────────────────────────

function Get-Config {
    $j = Get-Content $configPath -Raw | ConvertFrom-Json
    return @{
        TargetSSID   = $j.TargetSSID
        DeviceType   = $j.DeviceType
        StaticIP     = $j.StaticIP
        PrefixLength = $j.PrefixLength
        Gateway      = $j.Gateway
        DNS          = $j.DNS
        Enabled      = [bool]$j.Enabled
    }
}

function Save-Config($cfg) {
    $cfg | ConvertTo-Json | Out-File $configPath -Encoding UTF8
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

function Get-CurrentSSID {
    $line = netsh wlan show interfaces | Select-String "^\s+SSID\s+:" | Select-Object -First 1
    if ($line) { return ($line -replace ".*SSID\s+:\s+", "").Trim() }
    return ""
}

# ── Colors & Fonts ─────────────────────────────────────────────────────────────

$BG       = [System.Drawing.Color]::FromArgb(18,  18,  24 )
$SURFACE  = [System.Drawing.Color]::FromArgb(28,  28,  38 )
$BORDER   = [System.Drawing.Color]::FromArgb(55,  55,  75 )
$GREEN    = [System.Drawing.Color]::FromArgb(29, 185, 120 )
$GREEN_DK = [System.Drawing.Color]::FromArgb(18, 120,  75 )
$RED      = [System.Drawing.Color]::FromArgb(220,  60,  60 )
$RED_DK   = [System.Drawing.Color]::FromArgb(140,  35,  35 )
$MUTED    = [System.Drawing.Color]::FromArgb(120, 120, 145 )
$WHITE    = [System.Drawing.Color]::White
$YELLOW   = [System.Drawing.Color]::FromArgb(255, 200,  60 )

$FontMono  = New-Object System.Drawing.Font("Consolas",       9,  [System.Drawing.FontStyle]::Regular)
$FontUI    = New-Object System.Drawing.Font("Segoe UI",       9,  [System.Drawing.FontStyle]::Regular)
$FontUIB   = New-Object System.Drawing.Font("Segoe UI",       9,  [System.Drawing.FontStyle]::Bold)
$FontBig   = New-Object System.Drawing.Font("Segoe UI",      13,  [System.Drawing.FontStyle]::Bold)
$FontTitle = New-Object System.Drawing.Font("Segoe UI Light", 11, [System.Drawing.FontStyle]::Regular)

# ── Form ───────────────────────────────────────────────────────────────────────

$form = New-Object System.Windows.Forms.Form
$form.Text            = "Auto Static IP"
$form.Size            = New-Object System.Drawing.Size(400, 490)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = $BG
$form.ForeColor       = $WHITE
$form.Font            = $FontUI

# ── Title bar label ────────────────────────────────────────────────────────────

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text      = "AUTO STATIC IP"
$lblTitle.Font      = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $MUTED
$lblTitle.Location  = New-Object System.Drawing.Point(20, 16)
$lblTitle.AutoSize  = $true
$form.Controls.Add($lblTitle)

# ── Status panel ───────────────────────────────────────────────────────────────

$pnlStatus = New-Object System.Windows.Forms.Panel
$pnlStatus.Location  = New-Object System.Drawing.Point(16, 46)
$pnlStatus.Size      = New-Object System.Drawing.Size(352, 90)
$pnlStatus.BackColor = $SURFACE
$form.Controls.Add($pnlStatus)

$lblStatusVal = New-Object System.Windows.Forms.Label
$lblStatusVal.Text      = "OFF"
$lblStatusVal.Font      = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$lblStatusVal.ForeColor = $RED
$lblStatusVal.Location  = New-Object System.Drawing.Point(16, 14)
$lblStatusVal.AutoSize  = $true
$pnlStatus.Controls.Add($lblStatusVal)

$lblSSID = New-Object System.Windows.Forms.Label
$lblSSID.Font      = $FontMono
$lblSSID.ForeColor = $MUTED
$lblSSID.Location  = New-Object System.Drawing.Point(16, 54)
$lblSSID.AutoSize  = $true
$pnlStatus.Controls.Add($lblSSID)

$lblIP = New-Object System.Windows.Forms.Label
$lblIP.Font      = $FontMono
$lblIP.ForeColor = $MUTED
$lblIP.Location  = New-Object System.Drawing.Point(16, 70)
$lblIP.AutoSize  = $true
$pnlStatus.Controls.Add($lblIP)

# ── ON / OFF buttons ───────────────────────────────────────────────────────────

$btnOn = New-Object System.Windows.Forms.Button
$btnOn.Text      = "Turn ON"
$btnOn.Font      = $FontBig
$btnOn.Location  = New-Object System.Drawing.Point(16, 152)
$btnOn.Size      = New-Object System.Drawing.Size(168, 56)
$btnOn.BackColor = $GREEN_DK
$btnOn.ForeColor = $WHITE
$btnOn.FlatStyle = "Flat"
$btnOn.FlatAppearance.BorderColor = $GREEN
$btnOn.FlatAppearance.BorderSize  = 1
$btnOn.Cursor    = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnOn)

$btnOff = New-Object System.Windows.Forms.Button
$btnOff.Text      = "Turn OFF"
$btnOff.Font      = $FontBig
$btnOff.Location  = New-Object System.Drawing.Point(200, 152)
$btnOff.Size      = New-Object System.Drawing.Size(168, 56)
$btnOff.BackColor = $RED_DK
$btnOff.ForeColor = $WHITE
$btnOff.FlatStyle = "Flat"
$btnOff.FlatAppearance.BorderColor = $RED
$btnOff.FlatAppearance.BorderSize  = 1
$btnOff.Cursor    = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnOff)

# ── Divider ────────────────────────────────────────────────────────────────────

$div1 = New-Object System.Windows.Forms.Panel
$div1.Location  = New-Object System.Drawing.Point(16, 224)
$div1.Size      = New-Object System.Drawing.Size(352, 1)
$div1.BackColor = $BORDER
$form.Controls.Add($div1)

# ── URL reachability ───────────────────────────────────────────────────────────

$lblUrlHead = New-Object System.Windows.Forms.Label
$lblUrlHead.Text      = "REACHABILITY CHECK"
$lblUrlHead.Font      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblUrlHead.ForeColor = $MUTED
$lblUrlHead.Location  = New-Object System.Drawing.Point(16, 238)
$lblUrlHead.AutoSize  = $true
$form.Controls.Add($lblUrlHead)

$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Font        = $FontMono
$txtUrl.Location    = New-Object System.Drawing.Point(16, 260)
$txtUrl.Size        = New-Object System.Drawing.Size(252, 24)
$txtUrl.BackColor   = $SURFACE
$txtUrl.ForeColor   = $WHITE
$txtUrl.BorderStyle = "FixedSingle"
$txtUrl.Text        = "https://"
$form.Controls.Add($txtUrl)

$btnCheck = New-Object System.Windows.Forms.Button
$btnCheck.Text      = "Check"
$btnCheck.Font      = $FontUIB
$btnCheck.Location  = New-Object System.Drawing.Point(278, 258)
$btnCheck.Size      = New-Object System.Drawing.Size(90, 28)
$btnCheck.BackColor = $SURFACE
$btnCheck.ForeColor = $WHITE
$btnCheck.FlatStyle = "Flat"
$btnCheck.FlatAppearance.BorderColor = $BORDER
$btnCheck.Cursor    = [System.Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnCheck)

$lblResult = New-Object System.Windows.Forms.Label
$lblResult.Font      = $FontMono
$lblResult.ForeColor = $MUTED
$lblResult.Location  = New-Object System.Drawing.Point(16, 296)
$lblResult.Size      = New-Object System.Drawing.Size(352, 18)
$form.Controls.Add($lblResult)

# ── Divider ────────────────────────────────────────────────────────────────────

$div2 = New-Object System.Windows.Forms.Panel
$div2.Location  = New-Object System.Drawing.Point(16, 325)
$div2.Size      = New-Object System.Drawing.Size(352, 1)
$div2.BackColor = $BORDER
$form.Controls.Add($div2)

# ── Log box ────────────────────────────────────────────────────────────────────

$lblLogHead = New-Object System.Windows.Forms.Label
$lblLogHead.Text      = "LOG"
$lblLogHead.Font      = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$lblLogHead.ForeColor = $MUTED
$lblLogHead.Location  = New-Object System.Drawing.Point(16, 338)
$lblLogHead.AutoSize  = $true
$form.Controls.Add($lblLogHead)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline   = $true
$txtLog.ScrollBars  = "Vertical"
$txtLog.ReadOnly    = $true
$txtLog.Font        = $FontMono
$txtLog.BackColor   = $SURFACE
$txtLog.ForeColor   = [System.Drawing.Color]::FromArgb(180, 180, 200)
$txtLog.BorderStyle = "None"
$txtLog.Location    = New-Object System.Drawing.Point(16, 358)
$txtLog.Size        = New-Object System.Drawing.Size(352, 82)
$form.Controls.Add($txtLog)

# ── Helpers ────────────────────────────────────────────────────────────────────

function Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$ts] $msg`r`n")
    $txtLog.ScrollToCaret()
}

function Refresh-Status {
    $cfg = Get-Config
    if ($cfg.Enabled) {
        $lblStatusVal.Text      = "ON"
        $lblStatusVal.ForeColor = $GREEN
    } else {
        $lblStatusVal.Text      = "OFF"
        $lblStatusVal.ForeColor = $RED
    }
    $lblSSID.Text = "SSID  $($cfg.TargetSSID)  ($($cfg.DeviceType))"
    $lblIP.Text   = "IP    $($cfg.StaticIP)/$($cfg.PrefixLength)   GW $($cfg.Gateway)"
}

# ── Button logic ───────────────────────────────────────────────────────────────

$btnOn.Add_Click({
    try {
        Log "Registering task..."
        Register-WifiTask
        $cfg = Get-Config
        $cfg.Enabled = $true
        Save-Config $cfg
        Log "Task registered. Enabled = true"

        $ssid = Get-CurrentSSID
        if ($ssid -eq $cfg.TargetSSID) {
            Log "Already on target network — applying static IP..."
            & $workerPath
            Log "Static IP applied."
        }
        Refresh-Status
        Log "Automation is ON."
    } catch {
        Log "ERROR: $_"
    }
})

$btnOff.Add_Click({
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        $cfg = Get-Config
        $cfg.Enabled = $false
        Save-Config $cfg
        Log "Task removed. Enabled = false"

        $iface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }).Name
        if ($iface) {
            Set-NetIPInterface -InterfaceAlias $iface -Dhcp Enabled -ErrorAction SilentlyContinue
            Set-DnsClientServerAddress -InterfaceAlias $iface -ResetServerAddresses -ErrorAction SilentlyContinue
            Log "Adapter '$iface' reset to DHCP."
        }
        Refresh-Status
        Log "Automation is OFF."
    } catch {
        Log "ERROR: $_"
    }
})

$btnCheck.Add_Click({
    $url = $txtUrl.Text.Trim()
    if ($url -notmatch "^https?://") { $url = "https://$url" }
    $lblResult.ForeColor = $MUTED
    $lblResult.Text      = "Checking..."
    $form.Refresh()
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 7 -ErrorAction Stop
        $lblResult.ForeColor = $GREEN
        $lblResult.Text      = "Reachable — HTTP $($r.StatusCode)"
        Log "CHECK $url -> HTTP $($r.StatusCode)"
    } catch {
        $lblResult.ForeColor = $RED
        $lblResult.Text      = "Unreachable — $($_.Exception.Message.Split('.')[0])"
        Log "CHECK $url -> FAIL: $($_.Exception.Message)"
    }
})

$txtUrl.Add_KeyDown({
    if ($_.KeyCode -eq "Return") { $btnCheck.PerformClick() }
})

# ── Init ───────────────────────────────────────────────────────────────────────

Refresh-Status
Log "App started."

[System.Windows.Forms.Application]::Run($form)