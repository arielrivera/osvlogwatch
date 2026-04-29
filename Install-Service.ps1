#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs OSVLogWatcher as a Windows Scheduled Task that runs at startup.

.DESCRIPTION
    This script creates a scheduled task that runs the OSVLogWatcher PowerShell script
    at system startup. The task runs as the current interactive user with highest 
    privileges and will auto-restart if it fails. This allows the validator executable
    to display windows on the user's desktop.

.NOTES
    Run this script as Administrator.
#>

$TaskName = "OSVLogWatcher"
$ScriptPath = "C:\XXXX\XXXXXX\Documents\XXXXXXX\osvlogwatch.ps1"
$WorkingDir = "C:\XXXX\XXXXXX\Documents\XXXXXXX"

Write-Host "Installing OSVLogWatcher Scheduled Task..." -ForegroundColor Cyan
Write-Host ""

# Check if script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Error "Script not found at: $ScriptPath"
    Write-Host "Please update the `$ScriptPath variable in this installer." -ForegroundColor Yellow
    exit 1
}

# Remove existing task if present
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing existing task '$TaskName'..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create task action
$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`"" `
    -WorkingDirectory $WorkingDir

# Create trigger (at startup)
$Trigger = New-ScheduledTaskTrigger -AtStartup

# Create principal (run as current user)
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$Principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType Interactive `
    -RunLevel Highest

# Create settings
$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

# Register the task
try {
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $Action `
        -Trigger $Trigger `
        -Principal $Principal `
        -Settings $Settings `
        -Description "Monitors C:\XXXX\XXXXXX\Documents\XXXXXXX\Folder for .7z files and runs TestResultValidator_v1.2.exe" `
        -ErrorAction Stop

    Write-Host "SUCCESS: Task '$TaskName' created!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  Name: $TaskName"
    Write-Host "  Script: $ScriptPath"
    Write-Host "  Trigger: At system startup"
    Write-Host "  User: $currentUser"
    Write-Host ""
    Write-Host "Management Commands:" -ForegroundColor Cyan
    Write-Host "  Start:   Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
    Write-Host "  Stop:    Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
    Write-Host "  Status:  Get-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
    Write-Host "  Remove:  Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Logs are written to: C:\XXXX\XXXXXX\Documents\XXXXXXX\watcher.log" -ForegroundColor Gray
    
    # Start the task now
    Write-Host ""
    $startNow = Read-Host "Start the watcher now? (Y/N)"
    if ($startNow -eq 'Y' -or $startNow -eq 'y') {
        Start-ScheduledTask -TaskName $TaskName
        Write-Host "Task started!" -ForegroundColor Green
        Start-Sleep 2
        $task = Get-ScheduledTask -TaskName $TaskName
        Write-Host "Current state: $($task.State)" -ForegroundColor Cyan
    }

} catch {
    Write-Error "Failed to create task: $_"
    exit 1
}