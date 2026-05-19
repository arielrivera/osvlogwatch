#requires -Version 5.1

<#
.SYNOPSIS
    OSV Log Watcher - Monitors a folder for .7z files and executes a validator.

.DESCRIPTION
    This script watches a configured folder for new .7z files and automatically
    runs a validator executable when files are detected. Configuration is loaded
    from config.json file.

.NOTES
    Configuration file (config.json) must exist in the same directory as this script.
    See config.example.json for the required format.
#>

# --- Configuration Loading and Validation ---
$scriptDir = $PSScriptRoot
if (-not $scriptDir) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if (-not $scriptDir) {
    $scriptDir = (Get-Location).Path
}
$configPath = Join-Path $scriptDir "config.json"
$exampleConfigPath = Join-Path $scriptDir "config.example.json"

# Check if config file exists
if (-not (Test-Path $configPath)) {
    Write-Host "ERROR: Configuration file not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Expected config file: $configPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To fix this:" -ForegroundColor Cyan
    Write-Host "1. Copy config.example.json to config.json" -ForegroundColor White
    Write-Host "2. Edit config.json with your actual paths" -ForegroundColor White
    Write-Host ""
    
    if (Test-Path $exampleConfigPath) {
        Write-Host "Example config exists at: $exampleConfigPath" -ForegroundColor Green
    }
    
    exit 1
}

# Load configuration
try {
    $configContent = Get-Content $configPath -Raw -ErrorAction Stop
    $config = $configContent | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-Host "ERROR: Failed to parse config.json!" -ForegroundColor Red
    Write-Host "Details: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please ensure config.json contains valid JSON." -ForegroundColor Yellow
    exit 1
}

# Validate required configuration properties
$requiredProperties = @('watchPath', 'exePath', 'logPath', 'statePath', 'fileFilter')
$missingProperties = @()

foreach ($prop in $requiredProperties) {
    if (-not $config.PSObject.Properties.Name -contains $prop -or [string]::IsNullOrWhiteSpace($config.$prop)) {
        $missingProperties += $prop
    }
}

if ($missingProperties.Count -gt 0) {
    Write-Host "ERROR: Missing required configuration properties!" -ForegroundColor Red
    Write-Host "Missing: $($missingProperties -join ', ')" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please check your config.json file." -ForegroundColor Cyan
    exit 1
}

# Assign configuration values
$watchPath = $config.watchPath
$exePath = $config.exePath
$logPath = $config.logPath
$statePath = $config.statePath
$fileFilter = $config.fileFilter

# --- Validation of Paths and Files ---
$validationErrors = @()
$validationWarnings = @()

Write-Host "Validating configuration..." -ForegroundColor Cyan

# Validate watch path
if (-not (Test-Path $watchPath)) {
    $validationErrors += "Watch path does not exist: $watchPath"
} else {
    $item = Get-Item $watchPath
    if (-not $item.PSIsContainer) {
        $validationErrors += "Watch path is not a directory: $watchPath"
    }
}

# Validate executable
if (-not (Test-Path $exePath)) {
    $validationErrors += "Executable not found: $exePath"
} else {
    try {
        $exeItem = Get-Item $exePath -ErrorAction Stop
        if ($exeItem.PSIsContainer) {
            $validationErrors += "Executable path is a directory, not a file: $exePath"
        }
    } catch {
        $validationErrors += "Cannot access executable: $exePath"
    }
}

# Validate log directory
$logDir = Split-Path -Parent $logPath
if (-not (Test-Path $logDir)) {
    try {
        New-Item -ItemType Directory -Path $logDir -Force -ErrorAction Stop | Out-Null
        $validationWarnings += "Created log directory: $logDir"
    } catch {
        $validationErrors += "Cannot create log directory: $logDir"
    }
}

# Validate state file directory
$stateDir = Split-Path -Parent $statePath
if (-not (Test-Path $stateDir)) {
    try {
        New-Item -ItemType Directory -Path $stateDir -Force -ErrorAction Stop | Out-Null
        $validationWarnings += "Created state directory: $stateDir"
    } catch {
        $validationErrors += "Cannot create state file directory: $stateDir"
    }
}

# Display validation results
if ($validationWarnings.Count -gt 0) {
    foreach ($warning in $validationWarnings) {
        Write-Host "WARNING: $warning" -ForegroundColor Yellow
    }
}

if ($validationErrors.Count -gt 0) {
    Write-Host ""
    Write-Host "VALIDATION FAILED!" -ForegroundColor Red
    Write-Host "The following errors must be fixed before starting:" -ForegroundColor Red
    Write-Host ""
    foreach ($err in $validationErrors) {
        Write-Host "  X $err" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Please update your config.json file with correct paths." -ForegroundColor Cyan
    exit 1
}

Write-Host "  [OK] Watch path: $watchPath" -ForegroundColor Green
Write-Host "  [OK] Executable: $exePath" -ForegroundColor Green
Write-Host "  [OK] Log file: $logPath" -ForegroundColor Green
Write-Host "  [OK] State file: $statePath" -ForegroundColor Green
Write-Host "  [OK] File filter: $fileFilter" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration validated successfully!" -ForegroundColor Green
Write-Host ""

# --- Simple logger ---
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    try {
        $logEntry | Out-File -Append -FilePath $logPath -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {
        Write-Host "LOG ERROR: $logEntry" -ForegroundColor Red
    }
}

# --- Load previously processed files ---
$processed = @{}
if (Test-Path $statePath) {
    try {
        Get-Content $statePath -ErrorAction SilentlyContinue | ForEach-Object {
            if (-not [string]::IsNullOrWhiteSpace($_)) {
                $processed[$_] = $true
            }
        }
    } catch {
        Write-Log "WARNING: Could not load processed files list: $_"
    }
}

Write-Log "Watcher started."
Write-Log "Configuration: Watch=$watchPath, Exe=$exePath, Filter=$fileFilter"

# --- FileSystemWatcher ---
try {
    $watcher = New-Object System.IO.FileSystemWatcher -ErrorAction Stop
    $watcher.Path = $watchPath
    $watcher.Filter = $fileFilter
    $watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName'
    $watcher.EnableRaisingEvents = $true
} catch {
    Write-Log "ERROR: Failed to create FileSystemWatcher: $_"
    Write-Host "ERROR: Failed to create FileSystemWatcher: $_" -ForegroundColor Red
    exit 1
}

$onCreatedAction = {
    $filePath = $Event.SourceEventArgs.FullPath
    $fileName = [System.IO.Path]::GetFileName($filePath)

    # Duplicate protection
    if ($processed.ContainsKey($filePath)) {
        Write-Log "Skipped duplicate file: $fileName"
        return
    }

    Write-Log "Detected new file: $fileName"

    # Wait until file is fully written
    $maxWaitTime = 60
    $waited = 0
    while ($waited -lt $maxWaitTime) {
        try {
            $stream = [System.IO.File]::Open($filePath, 'Open', 'Read', 'None')
            $stream.Close()
            break
        } catch {
            Start-Sleep -Milliseconds 500
            $waited += 0.5
        }
    }

    if ($waited -ge $maxWaitTime) {
        Write-Log "ERROR: Timeout waiting for file to be ready: $fileName"
        return
    }

    Write-Log "File ready: $fileName"

    # Execute program
    try {
        $exeDir = [System.IO.Path]::GetDirectoryName($exePath)
        $process = Start-Process `
            -FilePath $exePath `
            -ArgumentList "`"$filePath`"" `
            -WorkingDirectory $exeDir `
            -PassThru `
            -ErrorAction Stop

        Write-Log "Executed validator for $fileName (PID: $($process.Id), from $exeDir)"

        # Mark as processed
        $processed[$filePath] = $true
        $filePath | Out-File -Append -FilePath $statePath -ErrorAction SilentlyContinue

    } catch {
        Write-Log "ERROR running validator for $fileName : $_"
    }
}

try {
    Register-ObjectEvent $watcher Created -Action $onCreatedAction -ErrorAction Stop | Out-Null
    Write-Log "FileSystemWatcher registered successfully"
} catch {
    Write-Log "ERROR: Failed to register FileSystemWatcher event: $_"
    Write-Host "ERROR: Failed to register FileSystemWatcher event: $_" -ForegroundColor Red
    exit 1
}

Write-Host "Watcher is now monitoring for $fileFilter files in: $watchPath" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host ""

# Keep script alive
while ($true) {
    Start-Sleep 1
}