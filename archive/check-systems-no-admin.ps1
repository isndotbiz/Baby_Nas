# Quick system check without admin requirements
param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$BareMetalIP = "10.0.0.89",
    [string]$BabyUser = "admin",
    [string]$BareMetalUser = "root"
)

Write-Host ""
Write-Host "=== TrueNAS Systems Quick Check ===" -ForegroundColor Cyan
Write-Host ""

# Baby NAS
Write-Host "Baby NAS (VM) - $BabyNasIP" -ForegroundColor Yellow
Write-Host "  Testing connectivity..." -ForegroundColor Gray -NoNewline
if (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet) {
    Write-Host " ONLINE" -ForegroundColor Green

    Write-Host "  Testing SSH..." -ForegroundColor Gray -NoNewline
    $sshTest = Test-NetConnection -ComputerName $BabyNasIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($sshTest) {
        Write-Host " OK" -ForegroundColor Green

        # Check ZFS pools
        Write-Host "  Checking ZFS pools..." -ForegroundColor Gray
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BabyUser}@${BabyNasIP}" "zpool list" 2>$null

        # Check Docker
        Write-Host "  Checking Docker..." -ForegroundColor Gray
        $dockerResult = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BabyUser}@${BabyNasIP}" "docker --version 2>/dev/null" 2>$null
        if ($dockerResult) {
            Write-Host "  Docker: INSTALLED (should be removed)" -ForegroundColor Yellow
        } else {
            Write-Host "  Docker: Not installed (correct)" -ForegroundColor Green
        }

        # Check disks
        Write-Host "  Checking disks..." -ForegroundColor Gray
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BabyUser}@${BabyNasIP}" "lsblk -d -o NAME,SIZE,TYPE | grep disk" 2>$null
    } else {
        Write-Host " SSH NOT ACCESSIBLE" -ForegroundColor Red
    }
} else {
    Write-Host " OFFLINE" -ForegroundColor Red
}

Write-Host ""
Write-Host "Bare Metal TrueNAS - $BareMetalIP" -ForegroundColor Yellow
Write-Host "  Testing connectivity..." -ForegroundColor Gray -NoNewline
if (Test-Connection -ComputerName $BareMetalIP -Count 2 -Quiet) {
    Write-Host " ONLINE" -ForegroundColor Green

    Write-Host "  Testing SSH..." -ForegroundColor Gray -NoNewline
    $sshTest = Test-NetConnection -ComputerName $BareMetalIP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($sshTest) {
        Write-Host " OK" -ForegroundColor Green

        # Check ZFS pools
        Write-Host "  Checking ZFS pools..." -ForegroundColor Gray
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BareMetalUser}@${BareMetalIP}" "zpool list" 2>$null

        # Check Docker
        Write-Host "  Checking Docker..." -ForegroundColor Gray
        $dockerResult = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BareMetalUser}@${BareMetalIP}" "docker --version 2>/dev/null" 2>$null
        if ($dockerResult) {
            Write-Host "  Docker: INSTALLED (correct)" -ForegroundColor Green

            # Check containers
            Write-Host "  Checking Docker containers..." -ForegroundColor Gray
            ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BareMetalUser}@${BareMetalIP}" "docker ps --format 'table {{.Names}}\t{{.Status}}'" 2>$null
        } else {
            Write-Host "  Docker: Not installed (needs installation)" -ForegroundColor Yellow
        }

        # Check disks
        Write-Host "  Checking disks..." -ForegroundColor Gray
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BareMetalUser}@${BareMetalIP}" "lsblk -d -o NAME,SIZE,TYPE | grep disk" 2>$null

        # Check memory
        Write-Host "  Checking memory..." -ForegroundColor Gray
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BareMetalUser}@${BareMetalIP}" "free -h | grep Mem" 2>$null
    } else {
        Write-Host " SSH NOT ACCESSIBLE" -ForegroundColor Red
    }
} else {
    Write-Host " OFFLINE" -ForegroundColor Red
}

Write-Host ""
