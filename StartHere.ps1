#requires -Version 5.1

<#
.SYNOPSIS
    OSV Log Watcher - Start Here GUI
    A user-friendly graphical interface for configuring and managing the OSV Log Watcher service.

.DESCRIPTION
    This script provides a complete GUI for:
    - First-time setup wizard
    - Service status monitoring and control
    - Configuration management
    - Live log viewing
    - Testing and diagnostics
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ============================================
# GLOBAL VARIABLES
# ============================================
$script:ConfigPath = Join-Path $PSScriptRoot "config.json"
$script:ExampleConfigPath = Join-Path $PSScriptRoot "config.example.json"
$script:Config = $null
$script:ServiceName = "OSVLogWatcher"
$script:LogRefreshTimer = $null

# ============================================
# CONFIGURATION FUNCTIONS
# ============================================

function Load-Configuration {
    param([switch]$Silent)
    
    if (-not (Test-Path $script:ConfigPath)) {
        return $null
    }
    
    try {
        $content = Get-Content $script:ConfigPath -Raw -ErrorAction Stop
        $config = $content | ConvertFrom-Json -ErrorAction Stop
        $script:Config = $config
        return $config
    } catch {
        return $null
    }
}

function Save-Configuration {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Settings
    )
    
    try {
        $json = $Settings | ConvertTo-Json -Depth 3
        $json | Out-File -FilePath $script:ConfigPath -Encoding UTF8 -Force
        $script:Config = Load-Configuration -Silent
        return $true
    } catch {
        return $false
    }
}

function Test-ConfigurationValid {
    $results = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }
    
    if (-not $script:Config) {
        $results.IsValid = $false
        $results.Errors += "No configuration loaded"
        return $results
    }
    
    if (-not (Test-Path $script:Config.watchPath)) {
        $results.IsValid = $false
        $results.Errors += "Watch folder does not exist"
    }
    
    if (-not (Test-Path $script:Config.exePath)) {
        $results.IsValid = $false
        $results.Errors += "Validator executable not found"
    }
    
    return $results
}

# ============================================
# SERVICE FUNCTIONS
# ============================================

function Get-ServiceStatus {
    try {
        $task = Get-ScheduledTask -TaskName $script:ServiceName -ErrorAction SilentlyContinue
        if (-not $task) {
            return @{ Status = "NotInstalled"; State = "Not Installed" }
        }
        return @{ Status = $task.State; State = $task.State }
    } catch {
        return @{ Status = "Error"; State = "Error" }
    }
}

# ============================================
# MAIN FORM
# ============================================

$form = New-Object System.Windows.Forms.Form
$form.Text = "OSV Log Watcher - Start Here"
$form.Size = New-Object System.Drawing.Size(900, 700)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = New-Object System.Drawing.Size(800, 600)

# Tab Control
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(860, 640)
$tabControl.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($tabControl)

# ============================================
# TAB 1: SETUP WIZARD
# ============================================

$tabSetup = New-Object System.Windows.Forms.TabPage
$tabSetup.Text = "Setup Wizard"
$tabControl.TabPages.Add($tabSetup)

$y = 20

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Welcome to OSV Log Watcher"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(20, $y)
$lblTitle.Size = New-Object System.Drawing.Size(400, 30)
$tabSetup.Controls.Add($lblTitle)

$y += 50

$lblDesc = New-Object System.Windows.Forms.Label
$lblDesc.Text = "This wizard will help you configure the log watcher service.`n`nThe watcher monitors a folder for .7z files and automatically runs your validator when new files arrive."
$lblDesc.Location = New-Object System.Drawing.Point(20, $y)
$lblDesc.Size = New-Object System.Drawing.Size(800, 50)
$lblDesc.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$tabSetup.Controls.Add($lblDesc)

$y += 70

# Watch Folder
$grpWatch = New-Object System.Windows.Forms.GroupBox
$grpWatch.Text = "Step 1: Select Folder to Watch"
$grpWatch.Location = New-Object System.Drawing.Point(20, $y)
$grpWatch.Size = New-Object System.Drawing.Size(800, 70)
$tabSetup.Controls.Add($grpWatch)

$txtWatchPath = New-Object System.Windows.Forms.TextBox
$txtWatchPath.Location = New-Object System.Drawing.Point(10, 30)
$txtWatchPath.Size = New-Object System.Drawing.Size(680, 25)
$txtWatchPath.Font = New-Object System.Drawing.Font("Consolas", 10)
$grpWatch.Controls.Add($txtWatchPath)

$btnBrowseWatch = New-Object System.Windows.Forms.Button
$btnBrowseWatch.Text = "Browse..."
$btnBrowseWatch.Location = New-Object System.Drawing.Point(700, 28)
$btnBrowseWatch.Size = New-Object System.Drawing.Size(90, 28)
$btnBrowseWatch.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the folder to watch for .7z files"
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtWatchPath.Text = $folderBrowser.SelectedPath
    }
})
$grpWatch.Controls.Add($btnBrowseWatch)

$y += 90

# Validator Executable
$grpExe = New-Object System.Windows.Forms.GroupBox
$grpExe.Text = "Step 2: Select Validator Executable"
$grpExe.Location = New-Object System.Drawing.Point(20, $y)
$grpExe.Size = New-Object System.Drawing.Size(800, 70)
$tabSetup.Controls.Add($grpExe)

$txtExePath = New-Object System.Windows.Forms.TextBox
$txtExePath.Location = New-Object System.Drawing.Point(10, 30)
$txtExePath.Size = New-Object System.Drawing.Size(680, 25)
$txtExePath.Font = New-Object System.Drawing.Font("Consolas", 10)
$grpExe.Controls.Add($txtExePath)

$btnBrowseExe = New-Object System.Windows.Forms.Button
$btnBrowseExe.Text = "Browse..."
$btnBrowseExe.Location = New-Object System.Drawing.Point(700, 28)
$btnBrowseExe.Size = New-Object System.Drawing.Size(90, 28)
$btnBrowseExe.Add_Click({
    $fileBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $fileBrowser.Filter = "Executable Files (*.exe)|*.exe|All Files (*.*)|*.*"
    $fileBrowser.Title = "Select Validator Executable"
    if ($fileBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtExePath.Text = $fileBrowser.FileName
    }
})
$grpExe.Controls.Add($btnBrowseExe)

$y += 90

# Log and State Files
$grpLog = New-Object System.Windows.Forms.GroupBox
$grpLog.Text = "Step 3: Log and State File Locations (Optional - will use defaults if not set)"
$grpLog.Location = New-Object System.Drawing.Point(20, $y)
$grpLog.Size = New-Object System.Drawing.Size(800, 120)
$tabSetup.Controls.Add($grpLog)

$lblLog = New-Object System.Windows.Forms.Label
$lblLog.Text = "Log File:"
$lblLog.Location = New-Object System.Drawing.Point(10, 25)
$lblLog.Size = New-Object System.Drawing.Size(100, 20)
$grpLog.Controls.Add($lblLog)

$txtLogPath = New-Object System.Windows.Forms.TextBox
$txtLogPath.Location = New-Object System.Drawing.Point(110, 22)
$txtLogPath.Size = New-Object System.Drawing.Size(580, 25)
$txtLogPath.Font = New-Object System.Drawing.Font("Consolas", 10)
$grpLog.Controls.Add($txtLogPath)

$btnBrowseLog = New-Object System.Windows.Forms.Button
$btnBrowseLog.Text = "Browse..."
$btnBrowseLog.Location = New-Object System.Drawing.Point(700, 20)
$btnBrowseLog.Size = New-Object System.Drawing.Size(90, 28)
$btnBrowseLog.Add_Click({
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Log Files (*.log)|*.log|All Files (*.*)|*.*"
    $saveDialog.FileName = "watcher.log"
    if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtLogPath.Text = $saveDialog.FileName
    }
})
$grpLog.Controls.Add($btnBrowseLog)

$lblState = New-Object System.Windows.Forms.Label
$lblState.Text = "State File:"
$lblState.Location = New-Object System.Drawing.Point(10, 65)
$lblState.Size = New-Object System.Drawing.Size(100, 20)
$grpLog.Controls.Add($lblState)

$txtStatePath = New-Object System.Windows.Forms.TextBox
$txtStatePath.Location = New-Object System.Drawing.Point(110, 62)
$txtStatePath.Size = New-Object System.Drawing.Size(580, 25)
$txtStatePath.Font = New-Object System.Drawing.Font("Consolas", 10)
$grpLog.Controls.Add($txtStatePath)

$btnBrowseState = New-Object System.Windows.Forms.Button
$btnBrowseState.Text = "Browse..."
$btnBrowseState.Location = New-Object System.Drawing.Point(700, 60)
$btnBrowseState.Size = New-Object System.Drawing.Size(90, 28)
$btnBrowseState.Add_Click({
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $saveDialog.FileName = "processed_files.txt"
    if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtStatePath.Text = $saveDialog.FileName
    }
})
$grpLog.Controls.Add($btnBrowseState)

$y += 140

# Validation Status
$lblValidation = New-Object System.Windows.Forms.Label
$lblValidation.Text = "Click 'Test Configuration' to validate your settings"
$lblValidation.Location = New-Object System.Drawing.Point(20, $y)
$lblValidation.Size = New-Object System.Drawing.Size(800, 25)
$lblValidation.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$lblValidation.ForeColor = [System.Drawing.Color]::Gray
$tabSetup.Controls.Add($lblValidation)

$y += 40

# Buttons
$btnTest = New-Object System.Windows.Forms.Button
$btnTest.Text = "Test Configuration"
$btnTest.Location = New-Object System.Drawing.Point(20, $y)
$btnTest.Size = New-Object System.Drawing.Size(150, 35)
$btnTest.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnTest.Add_Click({
    $errors = @()
    
    if (-not (Test-Path $txtWatchPath.Text)) {
        $errors += "Watch folder does not exist"
    }
    
    if (-not (Test-Path $txtExePath.Text)) {
        $errors += "Validator executable not found"
    }
    
    if ($errors.Count -eq 0) {
        $lblValidation.Text = "Configuration is valid!"
        $lblValidation.ForeColor = [System.Drawing.Color]::Green
    } else {
        $lblValidation.Text = "Errors: " + ($errors -join "; ")
        $lblValidation.ForeColor = [System.Drawing.Color]::Red
    }
})
$tabSetup.Controls.Add($btnTest)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Configuration"
$btnSave.Location = New-Object System.Drawing.Point(180, $y)
$btnSave.Size = New-Object System.Drawing.Size(150, 35)
$btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.Add_Click({
    # Set defaults if not provided
    $logPath = $txtLogPath.Text
    if ([string]::IsNullOrWhiteSpace($logPath)) {
        $logPath = Join-Path $PSScriptRoot "watcher.log"
    }
    
    $statePath = $txtStatePath.Text
    if ([string]::IsNullOrWhiteSpace($statePath)) {
        $statePath = Join-Path $PSScriptRoot "processed_files.txt"
    }
    
    $settings = @{
        watchPath = $txtWatchPath.Text
        exePath = $txtExePath.Text
        logPath = $logPath
        statePath = $statePath
        fileFilter = "*.7z"
    }
    
    if (Save-Configuration -Settings $settings) {
        $lblValidation.Text = "Configuration saved successfully!"
        $lblValidation.ForeColor = [System.Drawing.Color]::Green
        [System.Windows.Forms.MessageBox]::Show("Configuration saved successfully!", "Success", "OK", "Information")
    } else {
        [System.Windows.Forms.MessageBox]::Show("Failed to save configuration.", "Error", "OK", "Error")
    }
})
$tabSetup.Controls.Add($btnSave)

$btnInstall = New-Object System.Windows.Forms.Button
$btnInstall.Text = "Install Service"
$btnInstall.Location = New-Object System.Drawing.Point(340, $y)
$btnInstall.Size = New-Object System.Drawing.Size(150, 35)
$btnInstall.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnInstall.Add_Click({
    $installScript = Join-Path $PSScriptRoot "Install-Service.ps1"
    if (Test-Path $installScript) {
        try {
            & $installScript
            [System.Windows.Forms.MessageBox]::Show("Service installed successfully!", "Success", "OK", "Information")
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to install service: $_", "Error", "OK", "Error")
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Install-Service.ps1 not found.", "Error", "OK", "Error")
    }
})
$tabSetup.Controls.Add($btnInstall)

# ============================================
# TAB 2: DASHBOARD
# ============================================

$tabDashboard = New-Object System.Windows.Forms.TabPage
$tabDashboard.Text = "Dashboard"
$tabControl.TabPages.Add($tabDashboard)

# Status Panel
$grpStatus = New-Object System.Windows.Forms.GroupBox
$grpStatus.Text = "Service Status"
$grpStatus.Location = New-Object System.Drawing.Point(20, 20)
$grpStatus.Size = New-Object System.Drawing.Size(400, 150)
$tabDashboard.Controls.Add($grpStatus)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Checking..."
$lblStatus.Location = New-Object System.Drawing.Point(20, 30)
$lblStatus.Size = New-Object System.Drawing.Size(360, 40)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$lblStatus.ForeColor = [System.Drawing.Color]::Gray
$grpStatus.Controls.Add($lblStatus)

$lblStatusDetail = New-Object System.Windows.Forms.Label
$lblStatusDetail.Text = ""
$lblStatusDetail.Location = New-Object System.Drawing.Point(20, 80)
$lblStatusDetail.Size = New-Object System.Drawing.Size(360, 20)
$lblStatusDetail.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$grpStatus.Controls.Add($lblStatusDetail)

# Control Buttons
$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start Service"
$btnStart.Location = New-Object System.Drawing.Point(20, 110)
$btnStart.Size = New-Object System.Drawing.Size(100, 30)
$btnStart.Add_Click({
    try {
        Start-ScheduledTask -TaskName $script:ServiceName
        Start-Sleep -Seconds 2
        Update-Dashboard
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to start service: $_", "Error", "OK", "Error")
    }
})
$grpStatus.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop Service"
$btnStop.Location = New-Object System.Drawing.Point(130, 110)
$btnStop.Size = New-Object System.Drawing.Size(100, 30)
$btnStop.Add_Click({
    try {
        Stop-ScheduledTask -TaskName $script:ServiceName
        Start-Sleep -Seconds 2
        Update-Dashboard
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to stop service: $_", "Error", "OK", "Error")
    }
})
$grpStatus.Controls.Add($btnStop)

$btnRestart = New-Object System.Windows.Forms.Button
$btnRestart.Text = "Restart"
$btnRestart.Location = New-Object System.Drawing.Point(240, 110)
$btnRestart.Size = New-Object System.Drawing.Size(100, 30)
$btnRestart.Add_Click({
    try {
        Stop-ScheduledTask -TaskName $script:ServiceName
        Start-Sleep -Seconds 2
        Start-ScheduledTask -TaskName $script:ServiceName
        Start-Sleep -Seconds 2
        Update-Dashboard
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to restart service: $_", "Error", "OK", "Error")
    }
})
$grpStatus.Controls.Add($btnRestart)

# Quick Actions
$grpActions = New-Object System.Windows.Forms.GroupBox
$grpActions.Text = "Quick Actions"
$grpActions.Location = New-Object System.Drawing.Point(440, 20)
$grpActions.Size = New-Object System.Drawing.Size(380, 150)
$tabDashboard.Controls.Add($grpActions)

$btnOpenWatch = New-Object System.Windows.Forms.Button
$btnOpenWatch.Text = "Open Watch Folder"
$btnOpenWatch.Location = New-Object System.Drawing.Point(20, 30)
$btnOpenWatch.Size = New-Object System.Drawing.Size(150, 30)
$btnOpenWatch.Add_Click({
    if ($script:Config -and (Test-Path $script:Config.watchPath)) {
        Start-Process explorer.exe -ArgumentList "`"$($script:Config.watchPath)`""
    } else {
        [System.Windows.Forms.MessageBox]::Show("Watch folder not configured.", "Error", "OK", "Error")
    }
})
$grpActions.Controls.Add($btnOpenWatch)

$btnOpenLog = New-Object System.Windows.Forms.Button
$btnOpenLog.Text = "Open Log Folder"
$btnOpenLog.Location = New-Object System.Drawing.Point(180, 30)
$btnOpenLog.Size = New-Object System.Drawing.Size(150, 30)
$btnOpenLog.Add_Click({
    if ($script:Config -and (Test-Path (Split-Path $script:Config.logPath))) {
        Start-Process explorer.exe -ArgumentList "`"$(Split-Path $script:Config.logPath)`""
    } else {
        [System.Windows.Forms.MessageBox]::Show("Log folder not configured.", "Error", "OK", "Error")
    }
})
$grpActions.Controls.Add($btnOpenLog)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh Status"
$btnRefresh.Location = New-Object System.Drawing.Point(20, 70)
$btnRefresh.Size = New-Object System.Drawing.Size(150, 30)
$btnRefresh.Add_Click({
    Update-Dashboard
})
$grpActions.Controls.Add($btnRefresh)

# Configuration Summary
$grpSummary = New-Object System.Windows.Forms.GroupBox
$grpSummary.Text = "Current Configuration"
$grpSummary.Location = New-Object System.Drawing.Point(20, 190)
$grpSummary.Size = New-Object System.Drawing.Size(800, 200)
$tabDashboard.Controls.Add($grpSummary)

$txtSummary = New-Object System.Windows.Forms.TextBox
$txtSummary.Multiline = $true
$txtSummary.ReadOnly = $true
$txtSummary.ScrollBars = "Vertical"
$txtSummary.Location = New-Object System.Drawing.Point(10, 20)
$txtSummary.Size = New-Object System.Drawing.Size(780, 170)
$txtSummary.Font = New-Object System.Drawing.Font("Consolas", 10)
$grpSummary.Controls.Add($txtSummary)

function Update-Dashboard {
    $status = Get-ServiceStatus
    
    switch ($status.Status) {
        "Running" {
            $lblStatus.Text = "Running"
            $lblStatus.ForeColor = [System.Drawing.Color]::Green
            $btnStart.Enabled = $false
            $btnStop.Enabled = $true
        }
        "Ready" {
            $lblStatus.Text = "Stopped"
            $lblStatus.ForeColor = [System.Drawing.Color]::Orange
            $btnStart.Enabled = $true
            $btnStop.Enabled = $false
        }
        "NotInstalled" {
            $lblStatus.Text = "Not Installed"
            $lblStatus.ForeColor = [System.Drawing.Color]::Red
            $btnStart.Enabled = $false
            $btnStop.Enabled = $false
        }
        default {
            $lblStatus.Text = $status.State
            $lblStatus.ForeColor = [System.Drawing.Color]::Gray
        }
    }
    
    $lblStatusDetail.Text = "State: $($status.State)"
    
    # Update summary
    Load-Configuration -Silent
    if ($script:Config) {
        $summary = @"
Watch Path: $($script:Config.watchPath)
Executable: $($script:Config.exePath)
Log File: $($script:Config.logPath)
State File: $($script:Config.statePath)
File Filter: $($script:Config.fileFilter)
"@
        $txtSummary.Text = $summary
    } else {
        $txtSummary.Text = "No configuration found. Please use the Setup Wizard to configure the watcher."
    }
}

# ============================================
# TAB 3: LOG VIEWER
# ============================================

$tabLogs = New-Object System.Windows.Forms.TabPage
$tabLogs.Text = "Log Viewer"
$tabControl.TabPages.Add($tabLogs)

$txtLogs = New-Object System.Windows.Forms.TextBox
$txtLogs.Multiline = $true
$txtLogs.ReadOnly = $true
$txtLogs.ScrollBars = "Both"
$txtLogs.Location = New-Object System.Drawing.Point(20, 20)
$txtLogs.Size = New-Object System.Drawing.Size(800, 500)
$txtLogs.Font = New-Object System.Drawing.Font("Consolas", 9)
$tabLogs.Controls.Add($txtLogs)

$chkAutoRefresh = New-Object System.Windows.Forms.CheckBox
$chkAutoRefresh.Text = "Auto-refresh every 5 seconds"
$chkAutoRefresh.Location = New-Object System.Drawing.Point(20, 530)
$chkAutoRefresh.Size = New-Object System.Drawing.Size(200, 20)
$chkAutoRefresh.Checked = $true
$tabLogs.Controls.Add($chkAutoRefresh)

$btnRefreshLogs = New-Object System.Windows.Forms.Button
$btnRefreshLogs.Text = "Refresh Now"
$btnRefreshLogs.Location = New-Object System.Drawing.Point(230, 525)
$btnRefreshLogs.Size = New-Object System.Drawing.Size(100, 30)
$btnRefreshLogs.Add_Click({
    Refresh-Logs
})
$tabLogs.Controls.Add($btnRefreshLogs)

$btnClearLogs = New-Object System.Windows.Forms.Button
$btnClearLogs.Text = "Clear Log"
$btnClearLogs.Location = New-Object System.Drawing.Point(340, 525)
$btnClearLogs.Size = New-Object System.Drawing.Size(100, 30)
$btnClearLogs.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to clear the log file?", "Confirm", "YesNo", "Warning")
    if ($result -eq "Yes") {
        if ($script:Config -and (Test-Path $script:Config.logPath)) {
            Clear-Content $script:Config.logPath
            Refresh-Logs
        }
    }
})
$tabLogs.Controls.Add($btnClearLogs)

$btnExportLogs = New-Object System.Windows.Forms.Button
$btnExportLogs.Text = "Export..."
$btnExportLogs.Location = New-Object System.Drawing.Point(450, 525)
$btnExportLogs.Size = New-Object System.Drawing.Size(100, 30)
$btnExportLogs.Add_Click({
    $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $saveDialog.Filter = "Log Files (*.log)|*.log|Text Files (*.txt)|*.txt|All Files (*.*)|*.*"
    $saveDialog.FileName = "watcher_export_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        if ($script:Config -and (Test-Path $script:Config.logPath)) {
            Copy-Item $script:Config.logPath $saveDialog.FileName
            [System.Windows.Forms.MessageBox]::Show("Log exported successfully!", "Success", "OK", "Information")
        }
    }
})
$tabLogs.Controls.Add($btnExportLogs)

function Refresh-Logs {
    if ($script:Config -and (Test-Path $script:Config.logPath)) {
        $content = Get-Content $script:Config.logPath -Tail 100 -ErrorAction SilentlyContinue
        $txtLogs.Text = $content -join "`r`n"
        $txtLogs.SelectionStart = $txtLogs.Text.Length
        $txtLogs.ScrollToCaret()
    } else {
        $txtLogs.Text = "Log file not found. The service may not have started yet."
    }
}

# Timer for auto-refresh
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    if ($chkAutoRefresh.Checked) {
        Refresh-Logs
    }
    Update-Dashboard
})
$timer.Start()

# ============================================
# TAB 4: TOOLS
# ============================================

$tabTools = New-Object System.Windows.Forms.TabPage
$tabTools.Text = "Tools"
$tabControl.TabPages.Add($tabTools)

$grpTest = New-Object System.Windows.Forms.GroupBox
$grpTest.Text = "Testing Tools"
$grpTest.Location = New-Object System.Drawing.Point(20, 20)
$grpTest.Size = New-Object System.Drawing.Size(380, 150)
$tabTools.Controls.Add($grpTest)

$btnCreateTest = New-Object System.Windows.Forms.Button
$btnCreateTest.Text = "Create Test .7z File"
$btnCreateTest.Location = New-Object System.Drawing.Point(20, 30)
$btnCreateTest.Size = New-Object System.Drawing.Size(150, 30)
$btnCreateTest.Add_Click({
    if ($script:Config -and (Test-Path $script:Config.watchPath)) {
        $testFile = Join-Path $script:Config.watchPath "test_$(Get-Date -Format 'yyyyMMdd_HHmmss').7z"
        "Test file" | Out-File -FilePath $testFile -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Test file created: $testFile", "Success", "OK", "Information")
    } else {
        [System.Windows.Forms.MessageBox]::Show("Watch folder not configured.", "Error", "OK", "Error")
    }
})
$grpTest.Controls.Add($btnCreateTest)

$btnValidate = New-Object System.Windows.Forms.Button
$btnValidate.Text = "Validate Configuration"
$btnValidate.Location = New-Object System.Drawing.Point(20, 70)
$btnValidate.Size = New-Object System.Drawing.Size(150, 30)
$btnValidate.Add_Click({
    Load-Configuration -Silent
    $results = Test-ConfigurationValid
    
    if ($results.IsValid) {
        [System.Windows.Forms.MessageBox]::Show("Configuration is valid!", "Validation Success", "OK", "Information")
    } else {
        [System.Windows.Forms.MessageBox]::Show("Configuration errors:`n`n" + ($results.Errors -join "`n"), "Validation Failed", "OK", "Error")
    }
})
$grpTest.Controls.Add($btnValidate)

$grpMaintenance = New-Object System.Windows.Forms.GroupBox
$grpMaintenance.Text = "Maintenance"
$grpMaintenance.Location = New-Object System.Drawing.Point(420, 20)
$grpMaintenance.Size = New-Object System.Drawing.Size(380, 150)
$tabTools.Controls.Add($grpMaintenance)

$btnClearState = New-Object System.Windows.Forms.Button
$btnClearState.Text = "Clear Processed History"
$btnClearState.Location = New-Object System.Drawing.Point(20, 30)
$btnClearState.Size = New-Object System.Drawing.Size(150, 30)
$btnClearState.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show("This will clear the processed files history. Files may be re-processed. Continue?", "Confirm", "YesNo", "Warning")
    if ($result -eq "Yes") {
        if ($script:Config -and (Test-Path $script:Config.statePath)) {
            Remove-Item $script:Config.statePath -Force
            [System.Windows.Forms.MessageBox]::Show("Processed files history cleared.", "Success", "OK", "Information")
        }
    }
})
$grpMaintenance.Controls.Add($btnClearState)

$btnRemoveService = New-Object System.Windows.Forms.Button
$btnRemoveService.Text = "Remove Service"
$btnRemoveService.Location = New-Object System.Drawing.Point(20, 70)
$btnRemoveService.Size = New-Object System.Drawing.Size(150, 30)
$btnRemoveService.BackColor = [System.Drawing.Color]::FromArgb(255, 200, 200)
$btnRemoveService.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show("This will remove the OSVLogWatcher scheduled task. Continue?", "Confirm Removal", "YesNo", "Warning")
    if ($result -eq "Yes") {
        try {
            $task = Get-ScheduledTask -TaskName $script:ServiceName -ErrorAction SilentlyContinue
            if ($task) {
                Stop-ScheduledTask -TaskName $script:ServiceName
                Start-Sleep -Seconds 1
                Unregister-ScheduledTask -TaskName $script:ServiceName -Confirm:$false
                [System.Windows.Forms.MessageBox]::Show("Service removed successfully.", "Success", "OK", "Information")
                Update-Dashboard
            } else {
                [System.Windows.Forms.MessageBox]::Show("Service is not installed.", "Information", "OK", "Information")
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to remove service: $_", "Error", "OK", "Error")
        }
    }
})
$grpMaintenance.Controls.Add($btnRemoveService)

# ============================================
# TAB 5: HELP
# ============================================

$tabHelp = New-Object System.Windows.Forms.TabPage
$tabHelp.Text = "Help"
$tabControl.TabPages.Add($tabHelp)

$txtHelp = New-Object System.Windows.Forms.TextBox
$txtHelp.Multiline = $true
$txtHelp.ReadOnly = $true
$txtHelp.ScrollBars = "Vertical"
$txtHelp.Location = New-Object System.Drawing.Point(20, 20)
$txtHelp.Size = New-Object System.Drawing.Size(800, 550)
$txtHelp.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$txtHelp.Text = @"
OSV Log Watcher - Quick Start Guide

GETTING STARTED:
1. Click on the 'Setup Wizard' tab
2. Select the folder you want to watch for .7z files
3. Select your validator executable
4. Click 'Test Configuration' to verify settings
5. Click 'Save Configuration' to save
6. Click 'Install Service' to install as Windows service

DASHBOARD:
- View real-time service status
- Start, stop, or restart the service
- View current configuration summary

LOG VIEWER:
- View the watcher log in real-time
- Auto-refresh keeps the log updated
- Export logs for troubleshooting

TOOLS:
- Create test .7z files to verify the watcher is working
- Validate configuration
- Clear processed files history
- Remove the service if needed

TROUBLESHOOTING:
- If the service won't start, check that all paths are valid
- Use 'Validate Configuration' in the Tools tab to check settings
- Check the Log Viewer for error messages
- Ensure the validator executable works when run manually

For more information, see the README.md file in the application folder.
"@
$tabHelp.Controls.Add($txtHelp)

# ============================================
# INITIALIZATION
# ============================================

# Load existing configuration
Load-Configuration -Silent

# Pre-populate setup fields if config exists
if ($script:Config) {
    $txtWatchPath.Text = $script:Config.watchPath
    $txtExePath.Text = $script:Config.exePath
    $txtLogPath.Text = $script:Config.logPath
    $txtStatePath.Text = $script:Config.statePath
}

# Initial dashboard update
Update-Dashboard
Refresh-Logs

# Show the form
$form.ShowDialog() | Out-Null

# Stop timer on exit
$timer.Stop()