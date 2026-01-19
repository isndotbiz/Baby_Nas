@echo off
REM ============================================================================
REM Baby NAS Full Automation - Quick Launcher
REM ============================================================================

echo.
echo ╔═══════════════════════════════════════════════════════════════════╗
echo ║                                                                   ║
echo ║           BABY NAS FULL AUTOMATION LAUNCHER                       ║
echo ║                                                                   ║
echo ╚═══════════════════════════════════════════════════════════════════╝
echo.

REM Check for administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo.
    echo Right-click this file and select "Run as Administrator"
    echo.
    pause
    exit /b 1
)

echo Administrator privileges confirmed.
echo.

REM Change to script directory
cd /d "%~dp0"

echo Starting Full Automation...
echo.
echo This will configure Baby NAS completely from start to finish.
echo.
echo Press Ctrl+C to cancel, or
pause

REM Execute PowerShell script
PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FULL-AUTOMATION.ps1"

echo.
echo ═══════════════════════════════════════════════════════════════════
echo.

if %errorLevel% equ 0 (
    echo ✓ Automation completed successfully!
    echo.
    echo Check the log file for details:
    echo   D:\workspace\True_Nas\logs\full-automation-*.log
) else (
    echo ✗ Automation failed or was cancelled.
    echo.
    echo Check the log file for error details:
    echo   D:\workspace\True_Nas\logs\full-automation-*.log
)

echo.
pause
