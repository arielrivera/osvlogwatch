@echo off
echo ==========================================
echo   OSVLogWatcher Service Reinstaller
echo ==========================================
echo.

:: Check for admin privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please right-click and select "Run as administrator"
    pause
    exit /b 1
)

echo Step 1: Stopping and removing existing task...
powershell.exe -Command "Unregister-ScheduledTask -TaskName 'OSVLogWatcher' -Confirm:$false -ErrorAction SilentlyContinue" 2>nul
if %errorLevel% equ 0 (
    echo         Existing task removed successfully.
) else (
    echo         No existing task found or already removed.
)

echo.
echo Step 2: Installing new task...
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Install-Service.ps1"

echo.
echo ==========================================
echo   Reinstallation Complete!
echo ==========================================
echo.
echo Press any key to exit...
pause >nul