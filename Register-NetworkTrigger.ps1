# Register-NetworkTrigger.ps1
# Run as Administrator — registers a Task Scheduler job that fires on WiFi connect
# Place at: E:\Projects\Register-NetworkTrigger.ps1

$scriptPath = Join-Path $PSScriptRoot "Set-StaticIP.ps1"
$taskName = "AutoStaticIP_WiFiConnect"
# ✅ Fixed: embed current user so the task runs under the right account
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
      <Arguments>-NonInteractive -ExecutionPolicy Bypass -File "$scriptPath"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

$xmlPath = "$env:TEMP\wifi-trigger-task.xml"
$XML | Out-File $xmlPath -Encoding Unicode

Register-ScheduledTask -TaskName $taskName -Xml (Get-Content $xmlPath -Raw) -Force

Write-Host ""
Write-Host "✅ Task '$taskName' registered successfully." -ForegroundColor Green
Write-Host "   Fires on: WiFi connect (Event ID 10000)" -ForegroundColor Cyan
Write-Host "   Runs as:  $currentUser" -ForegroundColor Cyan
Write-Host "   Script:   $scriptPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test manually, run:" -ForegroundColor Yellow
Write-Host "   powershell -ExecutionPolicy Bypass -File `"$scriptPath`"" -ForegroundColor White