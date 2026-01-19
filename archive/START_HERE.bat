@echo off
REM TrueNAS API Tools - Quick Start Script
REM This script helps you get started with the TrueNAS API tools

echo.
echo ========================================
echo   TrueNAS API Tools - Quick Start
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8 or higher from https://www.python.org/
    pause
    exit /b 1
)

echo [1/4] Python is installed
python --version

REM Check if requirements are installed
echo.
echo [2/4] Checking dependencies...
pip show requests >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo ERROR: Failed to install dependencies
        pause
        exit /b 1
    )
) else (
    echo Dependencies are already installed
)

REM Check if configuration exists
echo.
echo [3/4] Checking configuration...
if not exist "%USERPROFILE%\.truenas\config.json" (
    echo Configuration not found. Running setup...
    python truenas-api-setup.py --setup
    if errorlevel 1 (
        echo ERROR: Setup failed
        pause
        exit /b 1
    )
) else (
    echo Configuration found
)

REM Run test
echo.
echo [4/4] Testing installation...
python test-truenas-tools.py
if errorlevel 1 (
    echo.
    echo Some tests failed. Please review the output above.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Setup Complete!
echo ========================================
echo.
echo You can now use the TrueNAS API tools:
echo.
echo   Dashboard:  python truenas-dashboard.py
echo   Manager:    python truenas-manager.py health system
echo   Snapshots:  python truenas-snapshot-manager.py list
echo   Examples:   python truenas-api-examples.py
echo.
echo See TRUENAS_API_TOOLS_README.md for complete documentation
echo See QUICK_REFERENCE.md for command reference
echo.
pause
