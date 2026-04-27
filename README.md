# OSV Log Watcher

A PowerShell-based file system watcher that monitors a folder for `.7z` files and automatically runs a validator executable when new files are detected.

## What It Does

- **Monitors** `C:\Users\OSVHo\Documents\OSV Template\Incoming` for new `.7z` files
- **Detects** when files are fully written (waits for file to be ready)
- **Executes** `TestResultValidator_v1.2.exe` with the detected file path
- **Runs from correct directory** - validator executes from its own folder
- **Prevents duplicates** - tracks processed files to avoid re-processing
- **Logs all activity** to `watcher.log`

## Files

| File | Description |
|------|-------------|
| `osvlogwatch.ps1` | Main watcher script (service-ready) |
| `Install-Service.ps1` | Creates Windows Scheduled Task |
| `reinstall.bat` | **Easy installer** - removes old task and installs new one |
| `README.md` | This documentation |

## Quick Start

### Option 1: Easy Install (Recommended)

Simply **right-click `reinstall.bat` and select "Run as administrator"**.

This will:
1. Remove any existing OSVLogWatcher task
2. Install the new task with current settings
3. Start the watcher immediately

### Option 2: Manual Install

**From an elevated (Administrator) PowerShell session:**

```powershell
.\Install-Service.ps1
```

**From a regular PowerShell session (auto-elevate):**

```powershell
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File \"C:\Users\OSVHo\Documents\osvlogwatch\Install-Service.ps1\"'"
```

This will trigger a UAC prompt and open a new elevated PowerShell window to run the installer.

The installed task will:
- Start automatically at system boot
- Run as your user account (allows validator window to be visible)
- Auto-restart if it fails
- Run silently in background

### Option 3: Run Manually (For Testing)

```powershell
powershell -ExecutionPolicy Bypass -File osvlogwatch.ps1
```

Press `Ctrl+C` to stop.

## Managing the Service

### Check Status
```powershell
Get-ScheduledTask -TaskName "OSVLogWatcher"
```

### Start
```powershell
Start-ScheduledTask -TaskName "OSVLogWatcher"
```

### Stop
```powershell
Stop-ScheduledTask -TaskName "OSVLogWatcher"
```

### Restart
```powershell
Stop-ScheduledTask -TaskName "OSVLogWatcher"
Start-Sleep 2
Start-ScheduledTask -TaskName "OSVLogWatcher"
```

### Remove Completely
```powershell
Unregister-ScheduledTask -TaskName "OSVLogWatcher" -Confirm:$false
```

## Configuration

Edit the CONFIG section at the top of `osvlogwatch.ps1`:

```powershell
# ---------------- CONFIG ----------------
$watchPath  = "C:\Users\OSVHo\Documents\OSV Template\Incoming"     # Folder to watch
$exePath    = "C:\Users\OSVHo\Documents\OSV Template\TestResultValidator_v1.2.exe"  # Validator
$logPath    = "C:\Users\OSVHo\Documents\OSV Template\watcher.log"  # Log file
$statePath  = "C:\Users\OSVHo\Documents\OSV Template\processed_files.txt"  # Processed tracking
# ----------------------------------------
```

## Logs

All activity is logged to:
```
C:\Users\OSVHo\Documents\OSV Template\watcher.log
```

Example log output:
```
2026-04-24 18:28:37 | Watcher started.
2026-04-24 18:29:27 | Detected new file: test.7z
2026-04-24 18:29:27 | File ready: test.7z
2026-04-24 18:29:28 | Executed validator for test.7z (from C:\Users\OSVHo\Documents\OSV Template)
```

## How It Works

1. **FileSystemWatcher** monitors the folder for new files
2. When a `.7z` file is created:
   - Checks if already processed (duplicate protection)
   - Waits for file to be fully written (file lock detection)
   - Runs validator from its own directory (working directory fix)
   - Marks file as processed
3. Runs indefinitely until stopped

## Troubleshooting

### Task won't start
- Check that paths in CONFIG section are correct
- Verify `TestResultValidator_v1.2.exe` exists
- Check Windows Event Viewer for errors

### Files not being detected
- Ensure files have `.7z` extension
- Check that `watchPath` folder exists
- Look at `watcher.log` for errors

### Validator not working
- Verify validator runs manually from its folder
- Check validator's own logs
- Ensure file paths don't contain special characters

## Requirements

- Windows PowerShell 5.1 or later
- Administrator rights (to install as scheduled task)
- .NET Framework (for FileSystemWatcher)

## Notes

- The script runs **hidden** (no console window) when installed as a service
- Processed files are tracked in `processed_files.txt` to prevent re-processing
- The script auto-restarts up to 3 times if it crashes
- Uses `Start-Sleep 1` in main loop (minimal CPU usage)