# ---------------- CONFIG ----------------
$watchPath  = "C:\Users\OSVHo\Documents\OSV Template\Incoming"
$exePath    = "C:\Users\OSVHo\Documents\OSV Template\TestResultValidator_v1.2.exe"
$logPath    = "C:\Users\OSVHo\Documents\OSV Template\watcher.log"
$statePath  = "C:\Users\OSVHo\Documents\OSV Template\processed_files.txt"
# ----------------------------------------

# --- Simple logger ---
function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp | $Message" | Out-File -Append -FilePath $logPath -Encoding UTF8
}

# --- Load previously processed files (for duplicate protection) ---
$processed = @{}
if (Test-Path $statePath) {
    Get-Content $statePath | ForEach-Object {
        $processed[$_] = $true
    }
}

Write-Log "Watcher started."

# --- FileSystemWatcher ---
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $watchPath
$watcher.Filter = "*.7z"
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName'
$watcher.EnableRaisingEvents = $true

$onCreatedAction = {
    $filePath = $Event.SourceEventArgs.FullPath
    $fileName = [System.IO.Path]::GetFileName($filePath)

    # --- Duplicate protection ---
    if ($processed.ContainsKey($filePath)) {
        Write-Log "Skipped duplicate file: $fileName"
        return
    }

    Write-Log "Detected new file: $fileName"

    # --- Wait until file is fully written ---
    while ($true) {
        try {
            $stream = [System.IO.File]::Open($filePath, 'Open', 'Read', 'None')
            $stream.Close()
            break
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }

    Write-Log "File ready: $fileName"

    # --- Execute program ---
    try {
        $exeDir = [System.IO.Path]::GetDirectoryName($exePath)
        Start-Process `
            -FilePath $exePath `
            -ArgumentList "`"$filePath`"" `
            -WorkingDirectory $exeDir

        Write-Log "Executed validator for $fileName (from $exeDir)"

        # --- Mark as processed ---
        $processed[$filePath] = $true
        $filePath | Out-File -Append -FilePath $statePath

    } catch {
        Write-Log "ERROR running validator for $fileName : $_"
    }
}

Register-ObjectEvent $watcher Created -Action $onCreatedAction

# --- Keep script alive ---
while ($true) {
    Start-Sleep 1
}