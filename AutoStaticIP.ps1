# AutoStaticIP.ps1 — GUI App, Run as Administrator
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ── Admin check ────────────────────────────────────────────────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    [Windows.Forms.MessageBox]::Show("Please right-click and run as Administrator.", "Admin Required", "OK", "Warning") | Out-Null
    exit
}

# ── Paths ──────────────────────────────────────────────────────────────────────
$exeDir     = Split-Path ([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
$workerPath = "$exeDir\Set-StaticIP.ps1"
$configDir  = "$env:APPDATA\AutoStaticIP"
$configPath = "$configDir\config.json"
$taskName   = "AutoStaticIP_WiFiConnect"

if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir | Out-Null }

# ── Config ─────────────────────────────────────────────────────────────────────
function Get-Config {
    if (-not (Test-Path $configPath)) {
        return @{ Enabled = $false; Profiles = @() }
    }
    $j = Get-Content $configPath -Raw | ConvertFrom-Json
    $profiles = @($j.Profiles | ForEach-Object {
        @{
            Name         = $_.Name
            SSID         = $_.SSID
            StaticIP     = $_.StaticIP
            PrefixLength = [int]$_.PrefixLength
            Gateway      = $_.Gateway
            DNS          = @($_.DNS)
        }
    })
    @{ Enabled = [bool]$j.Enabled; Profiles = $profiles }
}

function Save-Config($cfg) {
    $cfg | ConvertTo-Json -Depth 5 | Out-File $configPath -Encoding UTF8
}

function Scan-SSIDs {
    @(netsh wlan show networks mode=bssid 2>$null |
        Select-String "^SSID\s+\d+\s*:" |
        ForEach-Object { ($_ -replace "^SSID\s+\d+\s*:\s*","").Trim() } |
        Where-Object { $_ } |
        Sort-Object -Unique)
}

function Get-CurrentSSID {
    $line = netsh wlan show interfaces | Select-String "^\s+SSID\s+:" | Select-Object -First 1
    if ($line) { return ($line -replace ".*SSID\s+:\s+","").Trim() }
    ""
}

function Register-WifiTask {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    $XML = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[EventID=10000]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$user</UserId>
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

# ── Device presets ─────────────────────────────────────────────────────────────
$PRESETS = @{
    "iPhone"  = @{ IP = "172.20.10.6";   Prefix = 28; GW = "172.20.10.1";  DNS = "8.8.8.8,1.1.1.1" }
    "Android" = @{ IP = "192.168.43.10"; Prefix = 24; GW = "192.168.43.1"; DNS = "8.8.8.8,1.1.1.1" }
    "Router"  = @{ IP = "192.168.1.100"; Prefix = 24; GW = "192.168.1.1";  DNS = "8.8.8.8,1.1.1.1" }
    "Custom"  = @{ IP = "";              Prefix = 24; GW = "";             DNS = "8.8.8.8,1.1.1.1" }
}

# ── Colors & Fonts ─────────────────────────────────────────────────────────────
$BG       = [Drawing.Color]::FromArgb(18,18,24)
$SURFACE  = [Drawing.Color]::FromArgb(28,28,38)
$BORDER   = [Drawing.Color]::FromArgb(55,55,75)
$GREEN    = [Drawing.Color]::FromArgb(29,185,120)
$GREEN_DK = [Drawing.Color]::FromArgb(18,100,65)
$RED      = [Drawing.Color]::FromArgb(220,60,60)
$RED_DK   = [Drawing.Color]::FromArgb(120,30,30)
$MUTED    = [Drawing.Color]::FromArgb(110,110,140)
$WHITE    = [Drawing.Color]::White
$BLUE     = [Drawing.Color]::FromArgb(80,130,220)
$BLUE_DK  = [Drawing.Color]::FromArgb(35,60,130)
$YELLOW   = [Drawing.Color]::FromArgb(255,200,60)

$fUI  = New-Object Drawing.Font("Segoe UI", 9)
$fUIB = New-Object Drawing.Font("Segoe UI", 9,  [Drawing.FontStyle]::Bold)
$fMono= New-Object Drawing.Font("Consolas", 9)
$fBig = New-Object Drawing.Font("Segoe UI", 13, [Drawing.FontStyle]::Bold)
$fSm  = New-Object Drawing.Font("Segoe UI", 8,  [Drawing.FontStyle]::Bold)

# ── Add Profile Dialog ─────────────────────────────────────────────────────────
function Show-AddProfileDialog($owner) {
    $dlg = New-Object Windows.Forms.Form
    $dlg.Text            = "Add Profile"
    $dlg.Size            = New-Object Drawing.Size(400, 400)
    $dlg.StartPosition   = "CenterParent"
    $dlg.FormBorderStyle = "FixedDialog"
    $dlg.MaximizeBox     = $false
    $dlg.MinimizeBox     = $false
    $dlg.BackColor       = $BG
    $dlg.ForeColor       = $WHITE
    $dlg.Font            = $fUI

    function Lbl($text, $x, $y) {
        $l = New-Object Windows.Forms.Label
        $l.Text = $text; $l.Font = $fSm; $l.ForeColor = $MUTED
        $l.Location = New-Object Drawing.Point($x,$y); $l.AutoSize = $true
        $dlg.Controls.Add($l)
    }
    function Txt($x,$y,$w,$val="") {
        $t = New-Object Windows.Forms.TextBox
        $t.Location = New-Object Drawing.Point($x,$y); $t.Size = New-Object Drawing.Size($w,24)
        $t.BackColor = $SURFACE; $t.ForeColor = $WHITE; $t.BorderStyle = "FixedSingle"
        $t.Font = $fMono; $t.Text = $val
        $dlg.Controls.Add($t); return $t
    }

    Lbl "SSID" 16 14
    $cmbSSID = New-Object Windows.Forms.ComboBox
    $cmbSSID.Location = New-Object Drawing.Point(16,34)
    $cmbSSID.Size = New-Object Drawing.Size(280,24)
    $cmbSSID.BackColor = $SURFACE; $cmbSSID.ForeColor = $WHITE
    $cmbSSID.FlatStyle = "Flat"; $cmbSSID.Font = $fMono
    $dlg.Controls.Add($cmbSSID)

    $btnScan = New-Object Windows.Forms.Button
    $btnScan.Text = "Scan"; $btnScan.Font = $fUIB
    $btnScan.Location = New-Object Drawing.Point(306,32)
    $btnScan.Size = New-Object Drawing.Size(68,26)
    $btnScan.BackColor = $SURFACE; $btnScan.ForeColor = $WHITE
    $btnScan.FlatStyle = "Flat"; $btnScan.FlatAppearance.BorderColor = $BORDER
    $btnScan.Cursor = [Windows.Forms.Cursors]::Hand
    $dlg.Controls.Add($btnScan)

    Lbl "PROFILE NAME" 16 70
    $txtName = Txt 16 90 356

    Lbl "DEVICE TYPE" 16 126
    $cmbType = New-Object Windows.Forms.ComboBox
    $cmbType.Location = New-Object Drawing.Point(16,146)
    $cmbType.Size = New-Object Drawing.Size(180,24)
    $cmbType.BackColor = $SURFACE; $cmbType.ForeColor = $WHITE
    $cmbType.FlatStyle = "Flat"; $cmbType.Font = $fUI
    $cmbType.DropDownStyle = "DropDownList"
    @("iPhone","Android","Router","Custom") | ForEach-Object { [void]$cmbType.Items.Add($_) }
    $cmbType.SelectedIndex = 0
    $dlg.Controls.Add($cmbType)

    Lbl "STATIC IP" 16 182
    $txtIP = Txt 16 202 160
    Lbl "PREFIX" 190 182
    $txtPrefix = Txt 190 202 60 "28"
    Lbl "GATEWAY" 268 182
    $txtGW = Txt 268 202 104

    Lbl "DNS (comma separated)" 16 238
    $txtDNS = Txt 16 258 356 "8.8.8.8,1.1.1.1"

    # Scan on open
    $doScan = {
        $btnScan.Text = "..."
        $dlg.Refresh()
        $ssids = Scan-SSIDs
        $current = Get-CurrentSSID
        $cmbSSID.Items.Clear()
        if ($current) { [void]$cmbSSID.Items.Add($current) }
        $ssids | Where-Object { $_ -ne $current } | ForEach-Object { [void]$cmbSSID.Items.Add($_) }
        if ($cmbSSID.Items.Count -gt 0) { $cmbSSID.SelectedIndex = 0 }
        $btnScan.Text = "Scan"
    }
    & $doScan
    $btnScan.Add_Click($doScan)

    # Auto-fill name from SSID
    $cmbSSID.Add_SelectedIndexChanged({
        if ($txtName.Text -eq "" -or $txtName.Tag -eq "auto") {
            $txtName.Text = $cmbSSID.Text
            $txtName.Tag  = "auto"
        }
    })
    $txtName.Add_TextChanged({ $txtName.Tag = "manual" })

    # Auto-fill IP fields from device type
    $cmbType.Add_SelectedIndexChanged({
        $p = $PRESETS[$cmbType.Text]
        if ($p) {
            $txtIP.Text     = $p.IP
            $txtPrefix.Text = $p.Prefix
            $txtGW.Text     = $p.GW
            $txtDNS.Text    = $p.DNS
        }
    })
    # Apply initial preset
    $p = $PRESETS["iPhone"]
    $txtIP.Text = $p.IP; $txtPrefix.Text = $p.Prefix; $txtGW.Text = $p.GW

    $btnSave = New-Object Windows.Forms.Button
    $btnSave.Text = "Save Profile"; $btnSave.Font = $fUIB
    $btnSave.Location = New-Object Drawing.Point(16,308)
    $btnSave.Size = New-Object Drawing.Size(170,34)
    $btnSave.BackColor = $GREEN_DK; $btnSave.ForeColor = $WHITE
    $btnSave.FlatStyle = "Flat"; $btnSave.FlatAppearance.BorderColor = $GREEN
    $btnSave.Cursor = [Windows.Forms.Cursors]::Hand
    $btnSave.DialogResult = "OK"
    $dlg.AcceptButton = $btnSave
    $dlg.Controls.Add($btnSave)

    $btnCancel = New-Object Windows.Forms.Button
    $btnCancel.Text = "Cancel"; $btnCancel.Font = $fUI
    $btnCancel.Location = New-Object Drawing.Point(202,308)
    $btnCancel.Size = New-Object Drawing.Size(170,34)
    $btnCancel.BackColor = $SURFACE; $btnCancel.ForeColor = $MUTED
    $btnCancel.FlatStyle = "Flat"; $btnCancel.FlatAppearance.BorderColor = $BORDER
    $btnCancel.DialogResult = "Cancel"
    $dlg.CancelButton = $btnCancel
    $dlg.Controls.Add($btnCancel)

    $result = $dlg.ShowDialog($owner)
    if ($result -ne "OK") { return $null }

    $ssid = if ($cmbSSID.Text.Trim()) { $cmbSSID.Text.Trim() } else { return $null }
    $name = if ($txtName.Text.Trim()) { $txtName.Text.Trim() } else { $ssid }
    $dns  = @($txtDNS.Text -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })

    return @{
        Name         = $name
        SSID         = $ssid
        StaticIP     = $txtIP.Text.Trim()
        PrefixLength = [int]$txtPrefix.Text.Trim()
        Gateway      = $txtGW.Text.Trim()
        DNS          = $dns
    }
}

# ── Main Form ──────────────────────────────────────────────────────────────────
$form = New-Object Windows.Forms.Form
$form.Text            = "Auto Static IP"
$form.Size            = New-Object Drawing.Size(460, 630)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.BackColor       = $BG
$form.ForeColor       = $WHITE
$form.Font            = $fUI

# Title
$lblTitle = New-Object Windows.Forms.Label
$lblTitle.Text = "AUTO STATIC IP"
$lblTitle.Font = New-Object Drawing.Font("Segoe UI",10,[Drawing.FontStyle]::Bold)
$lblTitle.ForeColor = $MUTED
$lblTitle.Location = New-Object Drawing.Point(16,14)
$lblTitle.AutoSize = $true
$form.Controls.Add($lblTitle)

# Status panel
$pnlStatus = New-Object Windows.Forms.Panel
$pnlStatus.Location = New-Object Drawing.Point(16,42)
$pnlStatus.Size     = New-Object Drawing.Size(416,78)
$pnlStatus.BackColor= $SURFACE
$form.Controls.Add($pnlStatus)

$lblStatusVal = New-Object Windows.Forms.Label
$lblStatusVal.Text = "OFF"
$lblStatusVal.Font = New-Object Drawing.Font("Segoe UI",20,[Drawing.FontStyle]::Bold)
$lblStatusVal.ForeColor = $RED
$lblStatusVal.Location = New-Object Drawing.Point(16,10)
$lblStatusVal.AutoSize = $true
$pnlStatus.Controls.Add($lblStatusVal)

$lblCurSSID = New-Object Windows.Forms.Label
$lblCurSSID.Font = $fMono; $lblCurSSID.ForeColor = $MUTED
$lblCurSSID.Location = New-Object Drawing.Point(16,48)
$lblCurSSID.Size = New-Object Drawing.Size(384,16)
$pnlStatus.Controls.Add($lblCurSSID)

$lblCurMatch = New-Object Windows.Forms.Label
$lblCurMatch.Font = $fMono; $lblCurMatch.ForeColor = $MUTED
$lblCurMatch.Location = New-Object Drawing.Point(16,62)
$lblCurMatch.Size = New-Object Drawing.Size(384,16)
$pnlStatus.Controls.Add($lblCurMatch)

# Profiles header
$lblProfHead = New-Object Windows.Forms.Label
$lblProfHead.Text = "PROFILES"; $lblProfHead.Font = $fSm; $lblProfHead.ForeColor = $MUTED
$lblProfHead.Location = New-Object Drawing.Point(16,134); $lblProfHead.AutoSize = $true
$form.Controls.Add($lblProfHead)

$btnAdd = New-Object Windows.Forms.Button
$btnAdd.Text = "+ Add"; $btnAdd.Font = $fUIB
$btnAdd.Location = New-Object Drawing.Point(290,128); $btnAdd.Size = New-Object Drawing.Size(68,26)
$btnAdd.BackColor = $BLUE_DK; $btnAdd.ForeColor = $WHITE
$btnAdd.FlatStyle = "Flat"; $btnAdd.FlatAppearance.BorderColor = $BLUE
$btnAdd.Cursor = [Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnAdd)

$btnRemove = New-Object Windows.Forms.Button
$btnRemove.Text = "Remove"; $btnRemove.Font = $fUIB
$btnRemove.Location = New-Object Drawing.Point(366,128); $btnRemove.Size = New-Object Drawing.Size(66,26)
$btnRemove.BackColor = $SURFACE; $btnRemove.ForeColor = $MUTED
$btnRemove.FlatStyle = "Flat"; $btnRemove.FlatAppearance.BorderColor = $BORDER
$btnRemove.Cursor = [Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnRemove)

# Profiles ListView
$lv = New-Object Windows.Forms.ListView
$lv.Location = New-Object Drawing.Point(16,160)
$lv.Size     = New-Object Drawing.Size(416,118)
$lv.View = "Details"; $lv.FullRowSelect = $true
$lv.MultiSelect = $false; $lv.BackColor = $SURFACE
$lv.ForeColor = $WHITE; $lv.BorderStyle = "None"
$lv.Font = $fMono; $lv.GridLines = $false
[void]$lv.Columns.Add("Name",  118)
[void]$lv.Columns.Add("SSID",  150)
[void]$lv.Columns.Add("IP",     90)
[void]$lv.Columns.Add("GW",     50)
$form.Controls.Add($lv)

# ON / OFF buttons
$btnOn = New-Object Windows.Forms.Button
$btnOn.Text = "Turn ON"; $btnOn.Font = $fBig
$btnOn.Location = New-Object Drawing.Point(16,292); $btnOn.Size = New-Object Drawing.Size(200,52)
$btnOn.BackColor = $GREEN_DK; $btnOn.ForeColor = $WHITE
$btnOn.FlatStyle = "Flat"; $btnOn.FlatAppearance.BorderColor = $GREEN
$btnOn.Cursor = [Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnOn)

$btnOff = New-Object Windows.Forms.Button
$btnOff.Text = "Turn OFF"; $btnOff.Font = $fBig
$btnOff.Location = New-Object Drawing.Point(232,292); $btnOff.Size = New-Object Drawing.Size(200,52)
$btnOff.BackColor = $RED_DK; $btnOff.ForeColor = $WHITE
$btnOff.FlatStyle = "Flat"; $btnOff.FlatAppearance.BorderColor = $RED
$btnOff.Cursor = [Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnOff)

# Apply Now button
$btnApply = New-Object Windows.Forms.Button
$btnApply.Text = "Apply Now (current network)"; $btnApply.Font = $fUI
$btnApply.Location = New-Object Drawing.Point(16,352); $btnApply.Size = New-Object Drawing.Size(416,28)
$btnApply.BackColor = $SURFACE; $btnApply.ForeColor = $MUTED
$btnApply.FlatStyle = "Flat"; $btnApply.FlatAppearance.BorderColor = $BORDER
$btnApply.Cursor = [Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnApply)

# Divider
$div1 = New-Object Windows.Forms.Panel
$div1.Location = New-Object Drawing.Point(16,392); $div1.Size = New-Object Drawing.Size(416,1); $div1.BackColor = $BORDER
$form.Controls.Add($div1)

# URL checker
$lblUrlH = New-Object Windows.Forms.Label
$lblUrlH.Text = "REACHABILITY CHECK"; $lblUrlH.Font = $fSm; $lblUrlH.ForeColor = $MUTED
$lblUrlH.Location = New-Object Drawing.Point(16,404); $lblUrlH.AutoSize = $true
$form.Controls.Add($lblUrlH)

$txtUrl = New-Object Windows.Forms.TextBox
$txtUrl.Font = $fMono; $txtUrl.Location = New-Object Drawing.Point(16,424)
$txtUrl.Size = New-Object Drawing.Size(296,24); $txtUrl.BackColor = $SURFACE
$txtUrl.ForeColor = $WHITE; $txtUrl.BorderStyle = "FixedSingle"; $txtUrl.Text = "https://"
$form.Controls.Add($txtUrl)

$btnCheck = New-Object Windows.Forms.Button
$btnCheck.Text = "Check"; $btnCheck.Font = $fUIB
$btnCheck.Location = New-Object Drawing.Point(322,422); $btnCheck.Size = New-Object Drawing.Size(110,28)
$btnCheck.BackColor = $SURFACE; $btnCheck.ForeColor = $WHITE
$btnCheck.FlatStyle = "Flat"; $btnCheck.FlatAppearance.BorderColor = $BORDER
$btnCheck.Cursor = [Windows.Forms.Cursors]::Hand
$form.Controls.Add($btnCheck)

$lblResult = New-Object Windows.Forms.Label
$lblResult.Font = $fMono; $lblResult.ForeColor = $MUTED
$lblResult.Location = New-Object Drawing.Point(16,458); $lblResult.Size = New-Object Drawing.Size(416,18)
$form.Controls.Add($lblResult)

# Divider
$div2 = New-Object Windows.Forms.Panel
$div2.Location = New-Object Drawing.Point(16,484); $div2.Size = New-Object Drawing.Size(416,1); $div2.BackColor = $BORDER
$form.Controls.Add($div2)

# Log
$lblLogH = New-Object Windows.Forms.Label
$lblLogH.Text = "LOG"; $lblLogH.Font = $fSm; $lblLogH.ForeColor = $MUTED
$lblLogH.Location = New-Object Drawing.Point(16,494); $lblLogH.AutoSize = $true
$form.Controls.Add($lblLogH)

$txtLog = New-Object Windows.Forms.TextBox
$txtLog.Multiline = $true; $txtLog.ScrollBars = "Vertical"; $txtLog.ReadOnly = $true
$txtLog.Font = $fMono; $txtLog.BackColor = $SURFACE
$txtLog.ForeColor = [Drawing.Color]::FromArgb(160,160,190); $txtLog.BorderStyle = "None"
$txtLog.Location = New-Object Drawing.Point(16,514); $txtLog.Size = New-Object Drawing.Size(416,80)
$form.Controls.Add($txtLog)

# ── Logic ──────────────────────────────────────────────────────────────────────
function Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    $txtLog.AppendText("[$ts] $msg`r`n")
    $txtLog.ScrollToCaret()
}

function Refresh-UI {
    $cfg  = Get-Config
    $ssid = Get-CurrentSSID
    $match= $cfg.Profiles | Where-Object { $_.SSID -eq $ssid } | Select-Object -First 1

    # Status
    if ($cfg.Enabled) {
        $lblStatusVal.Text = "ON"; $lblStatusVal.ForeColor = $GREEN
    } else {
        $lblStatusVal.Text = "OFF"; $lblStatusVal.ForeColor = $RED
    }

    # Current SSID + match info
    if ($ssid) {
        $lblCurSSID.Text = "Connected: $ssid"
        if ($match) {
            $lblCurMatch.Text     = "Profile: $($match.Name)  →  $($match.StaticIP)"
            $lblCurMatch.ForeColor = $GREEN
        } else {
            $lblCurMatch.Text      = "No profile for this network"
            $lblCurMatch.ForeColor = $MUTED
        }
    } else {
        $lblCurSSID.Text       = "Not connected to WiFi"
        $lblCurMatch.Text      = ""
    }

    # ListView
    $lv.Items.Clear()
    foreach ($p in $cfg.Profiles) {
        $item = New-Object Windows.Forms.ListViewItem($p.Name)
        [void]$item.SubItems.Add($p.SSID)
        [void]$item.SubItems.Add($p.StaticIP)
        [void]$item.SubItems.Add($p.Gateway)
        if ($p.SSID -eq $ssid) { $item.ForeColor = $GREEN }
        [void]$lv.Items.Add($item)
    }
}

$btnAdd.Add_Click({
    $newProfile = Show-AddProfileDialog $form
    if ($newProfile) {
        $cfg = Get-Config
        # Replace if SSID already exists
        $cfg.Profiles = @($cfg.Profiles | Where-Object { $_.SSID -ne $newProfile.SSID })
        $cfg.Profiles += $newProfile
        Save-Config $cfg
        Refresh-UI
        Log "Profile '$($newProfile.Name)' saved for SSID '$($newProfile.SSID)'."
    }
})

$btnRemove.Add_Click({
    if ($lv.SelectedItems.Count -eq 0) { return }
    $name = $lv.SelectedItems[0].Text
    $cfg  = Get-Config
    $cfg.Profiles = @($cfg.Profiles | Where-Object { $_.Name -ne $name })
    Save-Config $cfg
    Refresh-UI
    Log "Profile '$name' removed."
})

$btnOn.Add_Click({
    $cfg = Get-Config
    if ($cfg.Profiles.Count -eq 0) {
        Log "No profiles configured. Add one first."
        return
    }
    try {
        Register-WifiTask
        $cfg.Enabled = $true
        Save-Config $cfg
        Refresh-UI
        Log "Automation ON — task registered."
        Log "Use 'Apply Now' if already connected, or reconnect to trigger automatically."
    } catch { Log "ERROR: $_" }
})

$btnOff.Add_Click({
    try {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        $cfg = Get-Config; $cfg.Enabled = $false; Save-Config $cfg
        $iface = (Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.Name -like "*Wi-Fi*" }).Name
        if ($iface) {
            Set-NetIPInterface -InterfaceAlias $iface -Dhcp Enabled -ErrorAction SilentlyContinue
            Set-DnsClientServerAddress -InterfaceAlias $iface -ResetServerAddresses -ErrorAction SilentlyContinue
            Log "Adapter '$iface' reset to DHCP."
        }
        Refresh-UI
        Log "Automation OFF."
    } catch { Log "ERROR: $_" }
})

$btnApply.Add_Click({
    Log "Applying static IP for current network..."
    & powershell.exe -NonInteractive -ExecutionPolicy Bypass -File $workerPath
    Start-Sleep -Seconds 1
    Refresh-UI
    Log "Done."
})

$btnCheck.Add_Click({
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = $txtUrl.Text.Trim()
    if ($url -notmatch "^https?://") { $url = "https://$url" }
    $lblResult.ForeColor = $MUTED; $lblResult.Text = "Checking..."
    $form.Refresh()
    try {
        $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 7 -ErrorAction Stop
        $lblResult.ForeColor = $GREEN; $lblResult.Text = "Reachable — HTTP $($r.StatusCode)"
        Log "CHECK $url → HTTP $($r.StatusCode)"
    } catch {
        $lblResult.ForeColor = $RED
        $lblResult.Text = "Unreachable — $($_.Exception.Message.Split('.')[0])"
        Log "CHECK $url → FAIL"
    }
})

$txtUrl.Add_KeyDown({ if ($_.KeyCode -eq "Return") { $btnCheck.PerformClick() } })

Refresh-UI
Log "App started."

[Windows.Forms.Application]::Run($form)