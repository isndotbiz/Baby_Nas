# Ultra-quick connectivity check (no SSH)
$BabyNasIP = "172.21.203.18"
$BareMetalIP = "10.0.0.89"

Write-Host ""
Write-Host "=== Quick System Connectivity Check ===" -ForegroundColor Cyan
Write-Host ""

# Baby NAS
Write-Host "Baby NAS (VM) - $BabyNasIP" -ForegroundColor Yellow
$babyPing = Test-Connection -ComputerName $BabyNasIP -Count 1 -Quiet
Write-Host "  Ping..." -ForegroundColor Gray -NoNewline
if ($babyPing) {
    Write-Host " ONLINE `u{2713}" -ForegroundColor Green

    Write-Host "  SSH port 22..." -ForegroundColor Gray -NoNewline
    if (Test-NetConnection -ComputerName $BabyNasIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet) {
        Write-Host " OPEN `u{2713}" -ForegroundColor Green
    } else {
        Write-Host " CLOSED" -ForegroundColor Gray
    }

    Write-Host "  Web UI port 443..." -ForegroundColor Gray -NoNewline
    if (Test-NetConnection -ComputerName $BabyNasIP -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet) {
        Write-Host " OPEN `u{2713}" -ForegroundColor Green
    } else {
        Write-Host " CLOSED" -ForegroundColor Gray
    }

    Write-Host "  SMB port 445..." -ForegroundColor Gray -NoNewline
    if (Test-NetConnection -ComputerName $BabyNasIP -Port 445 -WarningAction SilentlyContinue -InformationLevel Quiet) {
        Write-Host " OPEN `u{2713}" -ForegroundColor Green
    } else {
        Write-Host " CLOSED" -ForegroundColor Gray
    }
} else {
    Write-Host " OFFLINE `u{2717}" -ForegroundColor Red
}

Write-Host ""

# Bare Metal
Write-Host "Bare Metal TrueNAS - $BareMetalIP" -ForegroundColor Yellow
$barePing = Test-Connection -ComputerName $BareMetalIP -Count 1 -Quiet
Write-Host "  Ping..." -ForegroundColor Gray -NoNewline
if ($barePing) {
    Write-Host " ONLINE `u{2713}" -ForegroundColor Green

    Write-Host "  SSH port 22..." -ForegroundColor Gray -NoNewline
    if (Test-NetConnection -ComputerName $BareMetalIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet) {
        Write-Host " OPEN `u{2713}" -ForegroundColor Green
    } else {
        Write-Host " CLOSED" -ForegroundColor Gray
    }

    Write-Host "  Web UI port 443..." -ForegroundColor Gray -NoNewline
    if (Test-NetConnection -ComputerName $BareMetalIP -Port 443 -WarningAction SilentlyContinue -InformationLevel Quiet) {
        Write-Host " OPEN `u{2713}" -ForegroundColor Green
    } else {
        Write-Host " CLOSED" -ForegroundColor Gray
    }

    Write-Host "  SMB port 445..." -ForegroundColor Gray -NoNewline
    if (Test-NetConnection -ComputerName $BareMetalIP -Port 445 -WarningAction SilentlyContinue -InformationLevel Quiet) {
        Write-Host " OPEN `u{2713}" -ForegroundColor Green
    } else {
        Write-Host " CLOSED" -ForegroundColor Gray
    }

    Write-Host "  Docker port 2375..." -ForegroundColor Gray -NoNewline
    if (Test-NetConnection -ComputerName $BareMetalIP -Port 2375 -WarningAction SilentlyContinue -InformationLevel Quiet) {
        Write-Host " OPEN `u{2713}" -ForegroundColor Green
    } else {
        Write-Host " CLOSED" -ForegroundColor Gray
    }
} else {
    Write-Host " OFFLINE `u{2717}" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host ""

if ($babyPing -and $barePing) {
    Write-Host "`u{2713} Both systems ONLINE" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: SSH into each system to check configuration" -ForegroundColor Cyan
    Write-Host "  ssh admin@$BabyNasIP          # Baby NAS" -ForegroundColor White
    Write-Host "  ssh root@$BareMetalIP        # Bare Metal" -ForegroundColor White
} elseif ($babyPing) {
    Write-Host "`u{26A0} Baby NAS ONLINE, but Bare Metal OFFLINE" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Action: Bring Bare Metal (10.0.0.89) online first" -ForegroundColor Yellow
} elseif ($barePing) {
    Write-Host "`u{26A0} Bare Metal ONLINE, but Baby NAS OFFLINE" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Action: Start Baby NAS VM" -ForegroundColor Yellow
} else {
    Write-Host "`u{2717} Both systems OFFLINE" -ForegroundColor Red
    Write-Host ""
    Write-Host "Action: Bring both systems online" -ForegroundColor Red
}

Write-Host ""
