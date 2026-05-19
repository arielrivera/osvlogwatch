# OSV Log Watcher

A PowerShell-based file system watcher that monitors a folder for `.7z` files and automatically runs a validator executable when new files are detected.

## What It Does

- **Monitors** a configured folder for new `.7z` files
- **Detects** when files are fully written (waits for file to be ready)
- **Executes** your validator executable with the detected file path
- **Runs from correct directory** - validator executes from its own folder
- **Prevents duplicates** - tracks processed files to avoid re-processing
- **Validates configuration** at startup with helpful error messages
- **Logs all activity** to a configured log file

## Files

| File | Description |
|------|-------------|
| `osvlogwatch.ps1` | Main watcher script with config validation |
| `config.json` | **Local configuration** (user-specific paths) |
| `config.example.json` | Example configuration template |
| `Install-Service.ps1` | Creates Windows Scheduled Task |
| `reinstall.bat` | **Easy installer** - removes old task and installs new one |
| `.gitignore` | Excludes local config and logs from Git |
| `README.md` | This documentation |

## Quick Start

### Step 1: Configure

1. Copy the example configuration:
   ```powershell
   Copy-Item config.example.json config.json
   ```

2. Edit `config.json` with your actual paths:
   ```json
   {
     "watchPath": "C:\\Path\\To\\Your\\Incoming\\Folder",
     "exePath": "C:\\Path\\To\\Your\\Validator.exe",
     "logPath": "C:\\Path\\To\\Your\\watcher.log",
     "statePath": "C:\\Path\\To\\Your\\processed_files.txt",
     "fileFilter": "*.7z"
   }
   ```

### Step 2: Install (Run as Administrator)

#### Option A: Easy Install (Recommended)

Right-click `reinstall.bat` and select **"Run as administrator"**.

This will:
1. Remove any existing OSVLogWatcher task
2. Install the new task with current settings
3. Start the watcher immediately

#### Option B: Manual Install

**From an elevated (Administrator) PowerShell session:**
```powershell
.\Install-Service.ps1
```

**From a regular PowerShell session (auto-elevate):**
```powershell
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File \"C:\Path\To\Install-Service.ps1\"'"
```

The installed task will:
- Start automatically at system boot
- Run as your user account (allows validator window to be visible)
- Auto-restart if it fails
- Run silently in background

### Step 3: Test

Run manually to verify configuration:
```powershell
powershell -ExecutionPolicy Bypass -File osvlogwatch.ps1
```

You'll see validation output like:
```
Validating configuration...
  [OK] Watch path: C:\Path\To\Your\Incoming\Folder
  [OK] Executable: C:\Path\To\Your\Validator.exe
  [OK] Log file: C:\Path\To\Your\watcher.log
  [OK] State file: C:\Path\To\Your\processed_files.txt
  [OK] File filter: *.7z

Configuration validated successfully!

Watcher is now monitoring for *.7z files in: C:\Path\To\Your\Incoming\Folder
Press Ctrl+C to stop.
```

Press `Ctrl+C` to stop.

## Configuration

All settings are stored in `config.json` (excluded from Git via `.gitignore`):

| Property | Description | Example |
|----------|-------------|---------|
| `watchPath` | Folder to monitor for new files | `C:\Data\Incoming` |
| `exePath` | Full path to validator executable | `C:\Tools\Validator.exe` |
| `logPath` | Where to write activity logs | `C:\Logs\watcher.log` |
| `statePath` | Tracks processed files (duplicate protection) | `C:\Logs\processed.txt` |
| `fileFilter` | File pattern to watch | `*.7z` |

**Note:** `config.json` is git-ignored to protect your local paths. Use `config.example.json` as a template for other environments.

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

## Logs

All activity is logged to the path specified in `config.json` (default: `watcher.log`).

Example log output:
```
2026-05-19 13:26:09 - Watcher started.
2026-05-19 13:26:09 - Configuration: Watch=C:\Data\Incoming, Exe=C:\Tools\Validator.exe, Filter=*.7z
2026-05-19 13:26:09 - FileSystemWatcher registered successfully
2026-05-19 13:30:15 - Detected new file: test.7z
2026-05-19 13:30:15 - File ready: test.7z
2026-05-19 13:30:16 - Executed validator for test.7z (PID: 12345, from C:\Tools)
```

## How It Works

1. **Startup Validation**: Script validates all configuration paths and files
2. **FileSystemWatcher**: Monitors the configured folder for new files
3. When a matching file is created:
   - Checks if already processed (duplicate protection)
   - Waits for file to be fully written (file lock detection)
   - Runs validator from its own directory (working directory fix)
   - Captures process ID for tracking
   - Marks file as processed
4. Runs indefinitely until stopped

## Troubleshooting

### Configuration file not found
```
ERROR: Configuration file not found!
Expected config file: C:\...\config.json

To fix this:
1. Copy config.example.json to config.json
2. Edit config.json with your actual paths
```

### Validation errors
```
VALIDATION FAILED!
The following errors must be fixed before starting:
  X Watch path does not exist: C:\Bad\Path
  X Executable not found: C:\Bad\Path\exe.exe
```

**Fix**: Update `config.json` with correct paths.

### Files not being detected
- Ensure files match the `fileFilter` pattern (default: `*.7z`)
- Check that `watchPath` folder exists
- Look at the configured log file for errors
- Verify the scheduled task is Running: `Get-ScheduledTask -TaskName "OSVLogWatcher"`

### Validator not working
- Verify validator runs manually from its folder
- Check validator's own logs
- Ensure file paths don't contain special characters
- Check Windows Event Viewer for errors

## For Developers / Other Environments

1. Clone the repository
2. Copy `config.example.json` to `config.json`
3. Edit `config.json` with your local paths
4. Run `.\Install-Service.ps1` as Administrator
5. The validation system will guide you if anything is misconfigured

Your local `config.json` will not be pushed to GitHub (it's in `.gitignore`), keeping your paths private.

## Requirements

- Windows PowerShell 5.1 or later
- Administrator rights (to install as scheduled task)
- .NET Framework (for FileSystemWatcher)

## Notes

- The script runs **hidden** (no console window) when installed as a service
- Processed files are tracked in the configured state file to prevent re-processing
- The script auto-restarts up to 3 times if it crashes
- Uses `Start-Sleep 1` in main loop (minimal CPU usage)
- Configuration validation prevents startup with invalid paths