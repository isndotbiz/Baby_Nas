<#
.SYNOPSIS
Quick start guide for running Baby NAS VM headless and automatically at startup.

.DESCRIPTION
Interactive menu to:
1. Start the VM now (headless mode)
2. Setup auto-start on system boot
3. Check VM status
4. Open VM console

.EXAMPLE
.\quick-start-headless.ps1

.NOTES
Requires: Administrator privileges
#>

#Requires -RunAsAdministrator

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║ $Title" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Header "Baby NAS Headless Startup - Quick Start"

    Write-Host "What would you like to do?" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1) Start Baby NAS now (headless, no console)" -ForegroundColor White
    Write-Host "  2) Setup auto-start on system boot" -ForegroundColor White
    Write-Host "  3) Start + Setup auto-start (recommended)" -ForegroundColor Green
    Write-Host "  4) Check VM status" -ForegroundColor White
    Write-Host "  5) Open VM console (interactive)" -ForegroundColor White
    Write-Host "  6) Disable auto-start" -ForegroundColor Yellow
    Write-Host "  0) Exit" -ForegroundColor Gray
    Write-Host ""
}

function Start-VMHeadless {
    Write-Header "Starting Baby NAS VM (Headless)"

    $scriptPath = Join-Path $PSScriptRoot "start-baby-nas-headless.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: start-baby-nas-headless.ps1 not found" -ForegroundColor Red
        return $false
    }

    & $scriptPath -Wait
    return $?
}

function Setup-AutoStart {
    Write-Header "Setting Up Auto-Start on Boot"

    $scriptPath = Join-Path $PSScriptRoot "setup-baby-nas-auto-start.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: setup-baby-nas-auto-start.ps1 not found" -ForegroundColor Red
        return $false
    }

    & $scriptPath -Action Setup
    return $?
}

function Check-VMStatus {
    Write-Header "Baby NAS VM Status"

    try {
        $vm = Get-VM -Name "TrueNAS-BabyNAS" -ErrorAction Stop

        Write-Host "VM Name:       $($vm.Name)" -ForegroundColor White
        Write-Host "State:         $($vm.State)" -ForegroundColor $(if ($vm.State -eq "Running") { "Green" } else { "Yellow" })
        Write-Host "Status:        $($vm.Status)" -ForegroundColor White
        Write-Host "CPU Usage:     $($vm.CPUUsage)%" -ForegroundColor White
        Write-Host "Memory:        $([math]::Round($vm.MemoryAssigned / 1GB, 2)) GB" -ForegroundColor White
        Write-Host "Uptime:        $($vm.Uptime)" -ForegroundColor Gray

        if ($vm.State -eq "Running") {
            Write-Host ""
            Write-Host "Testing network connectivity to 172.21.203.18..." -ForegroundColor Gray
            $ping = Test-Connection -ComputerName "172.21.203.18" -Count 1 -Quiet -ErrorAction SilentlyContinue

            if ($ping) {
                Write-Host "Network:       ✓ Online (172.21.203.18)" -ForegroundColor Green
            } else {
                Write-Host "Network:       ⏳ Still booting..." -ForegroundColor Yellow
            }
        }

        Write-Host ""
        return $true
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Open-VMConsole {
    Write-Header "Opening VM Console"

    $scriptPath = Join-Path $PSScriptRoot "open-vm-console.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: open-vm-console.ps1 not found" -ForegroundColor Red
        return $false
    }

    & $scriptPath
    return $?
}

function Disable-AutoStart {
    Write-Header "Disabling Auto-Start"

    $scriptPath = Join-Path $PSScriptRoot "setup-baby-nas-auto-start.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: setup-baby-nas-auto-start.ps1 not found" -ForegroundColor Red
        return $false
    }

    & $scriptPath -Action Remove
    return $?
}

function Show-Summary {
    Write-Header "Quick Start Summary"

    Write-Host "What we've set up:" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ✓ start-baby-nas-headless.ps1" -ForegroundColor White
    Write-Host "    Starts the VM in headless mode (no console window)" -ForegroundColor Gray
    Write-Host "    Usage: .\start-baby-nas-headless.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ✓ setup-baby-nas-auto-start.ps1" -ForegroundColor White
    Write-Host "    Creates a Windows Task Scheduler job" -ForegroundColor Gray
    Write-Host "    Auto-starts the VM at system boot" -ForegroundColor Gray
    Write-Host "    Usage: .\setup-baby-nas-auto-start.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ✓ open-vm-console.ps1" -ForegroundColor White
    Write-Host "    Opens the Hyper-V console window (existing script)" -ForegroundColor Gray
    Write-Host "    Usage: .\open-vm-console.ps1" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Commands to remember:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Start VM now, headless:" -ForegroundColor Gray
    Write-Host "  .\start-baby-nas-headless.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Enable auto-start on boot:" -ForegroundColor Gray
    Write-Host "  .\setup-baby-nas-auto-start.ps1 -Action Setup" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Check what's scheduled:" -ForegroundColor Gray
    Write-Host "  .\setup-baby-nas-auto-start.ps1 -Action View" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Open console window (interactive):" -ForegroundColor Gray
    Write-Host "  .\open-vm-console.ps1" -ForegroundColor White
    Write-Host ""
}

# ============================================================================
# MAIN LOOP
# ============================================================================

while ($true) {
    Show-Menu

    $choice = Read-Host "Enter your choice (0-6)"

    switch ($choice) {
        "1" {
            Start-VMHeadless
            Read-Host "Press Enter to continue"
        }
        "2" {
            Setup-AutoStart
            Read-Host "Press Enter to continue"
        }
        "3" {
            Start-VMHeadless
            Write-Host ""
            Write-Host "Now setting up auto-start..." -ForegroundColor Cyan
            Start-Sleep -Seconds 2
            Setup-AutoStart
            Read-Host "Press Enter to continue"
        }
        "4" {
            Check-VMStatus
            Read-Host "Press Enter to continue"
        }
        "5" {
            Open-VMConsole
            # Console closes, user returns to menu
        }
        "6" {
            Disable-AutoStart
            Read-Host "Press Enter to continue"
        }
        "0" {
            Write-Host "Goodbye!" -ForegroundColor Green
            exit 0
        }
        default {
            Write-Host "Invalid choice. Please try again." -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }

    Clear-Host
}
