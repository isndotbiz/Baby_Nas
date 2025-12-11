#Requires -RunAsAdministrator
###############################################################################
# System State Inventory - Check Both TrueNAS Systems
# Determines what's currently configured on each system
###############################################################################

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$BareMetalIP = "10.0.0.89",
    [string]$BabyUser = "admin",
    [string]$BareMetalUser = "root"
)

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                   ║" -ForegroundColor Cyan
Write-Host "║          TrueNAS Systems Inventory Check                          ║" -ForegroundColor Cyan
Write-Host "║                                                                   ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$results = @{
    BabyNAS = @{}
    BareMetal = @{}
}

###############################################################################
# Function to check a TrueNAS system
###############################################################################
function Check-TrueNASSystem {
    param(
        [string]$SystemName,
        [string]$IP,
        [string]$Username
    )

    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  Checking: $SystemName ($IP)" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""

    $systemInfo = @{
        Online = $false
        SSHAccessible = $false
        ZFSPools = @()
        Datasets = @()
        DockerInstalled = $false
        DockerContainers = @()
        SMBShares = @()
        Services = @()
        DiskInfo = @()
        MemoryGB = 0
        CPUCount = 0
    }

    # Test connectivity
    Write-Host "  [1/10] Network Connectivity..." -ForegroundColor Cyan -NoNewline
    if (Test-Connection -ComputerName $IP -Count 2 -Quiet) {
        Write-Host " ✓" -ForegroundColor Green
        $systemInfo.Online = $true
    } else {
        Write-Host " ✗ OFFLINE" -ForegroundColor Red
        return $systemInfo
    }

    # Test SSH
    Write-Host "  [2/10] SSH Access..." -ForegroundColor Cyan -NoNewline
    $sshTest = Test-NetConnection -ComputerName $IP -Port 22 -WarningAction SilentlyContinue -InformationLevel Quiet
    if ($sshTest) {
        Write-Host " ✓" -ForegroundColor Green
        $systemInfo.SSHAccessible = $true
    } else {
        Write-Host " ✗ SSH NOT ACCESSIBLE" -ForegroundColor Red
        return $systemInfo
    }

    # Check ZFS pools
    Write-Host "  [3/10] ZFS Pools..." -ForegroundColor Cyan -NoNewline
    try {
        $pools = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 "${Username}@${IP}" "zpool list -H" 2>$null
        if ($LASTEXITCODE -eq 0 -and $pools) {
            $poolLines = $pools -split "`n" | Where-Object { $_ }
            $systemInfo.ZFSPools = $poolLines
            Write-Host " ✓ ($($poolLines.Count) pool(s))" -ForegroundColor Green
            foreach ($pool in $poolLines) {
                $poolName = ($pool -split "\s+")[0]
                Write-Host "      • $pool" -ForegroundColor Gray
            }
        } else {
            Write-Host " No pools" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " Error checking" -ForegroundColor Red
    }

    # Check datasets
    Write-Host "  [4/10] ZFS Datasets..." -ForegroundColor Cyan -NoNewline
    try {
        $datasets = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${IP}" "zfs list -H -o name" 2>$null
        if ($LASTEXITCODE -eq 0 -and $datasets) {
            $datasetLines = $datasets -split "`n" | Where-Object { $_ }
            $systemInfo.Datasets = $datasetLines
            Write-Host " ✓ ($($datasetLines.Count) dataset(s))" -ForegroundColor Green
        } else {
            Write-Host " None" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " Error checking" -ForegroundColor Red
    }

    # Check Docker
    Write-Host "  [5/10] Docker..." -ForegroundColor Cyan -NoNewline
    try {
        $dockerCheck = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${IP}" "docker --version 2>/dev/null" 2>$null
        if ($LASTEXITCODE -eq 0 -and $dockerCheck) {
            $systemInfo.DockerInstalled = $true
            Write-Host " ✓ INSTALLED" -ForegroundColor Green
            Write-Host "      • $dockerCheck" -ForegroundColor Gray

            # Check running containers
            $containers = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${IP}" "docker ps --format '{{.Names}}:{{.Status}}'" 2>$null
            if ($LASTEXITCODE -eq 0 -and $containers) {
                $containerLines = $containers -split "`n" | Where-Object { $_ }
                $systemInfo.DockerContainers = $containerLines
                Write-Host "      • Running containers: $($containerLines.Count)" -ForegroundColor Gray
                foreach ($container in $containerLines) {
                    Write-Host "        - $container" -ForegroundColor DarkGray
                }
            }
        } else {
            Write-Host " Not installed" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " Error checking" -ForegroundColor Red
    }

    # Check SMB shares
    Write-Host "  [6/10] SMB Shares..." -ForegroundColor Cyan -NoNewline
    try {
        $smbCheck = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${IP}" "testparm -s 2>/dev/null | grep -A1 '^\[' | grep -v '^--$' | grep -v '^\[global\]' | grep '^\['" 2>$null
        if ($LASTEXITCODE -eq 0 -and $smbCheck) {
            $shares = $smbCheck -split "`n" | Where-Object { $_ -match '^\[' }
            $systemInfo.SMBShares = $shares
            Write-Host " ✓ ($($shares.Count) share(s))" -ForegroundColor Green
            foreach ($share in $shares) {
                Write-Host "      • $share" -ForegroundColor Gray
            }
        } else {
            Write-Host " None configured" -ForegroundColor Yellow
        }
    } catch {
        Write-Host " Error checking" -ForegroundColor Red
    }

    # Check key services
    Write-Host "  [7/10] Services..." -ForegroundColor Cyan -NoNewline
    try {
        $services = @("sshd", "smbd", "docker")
        $runningServices = @()
        foreach ($service in $services) {
            $status = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${IP}" "systemctl is-active $service 2>/dev/null" 2>$null
            if ($status -eq "active") {
                $runningServices += $service
            }
        }
        $systemInfo.Services = $runningServices
        Write-Host " ✓ ($($runningServices.Count) active)" -ForegroundColor Green
        foreach ($svc in $runningServices) {
            Write-Host "      • $svc" -ForegroundColor Gray
        }
    } catch {
        Write-Host " Error checking" -ForegroundColor Red
    }

    # Check disk info
    Write-Host "  [8/10] Disks..." -ForegroundColor Cyan -NoNewline
    try {
        $disks = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${IP}" "lsblk -d -o NAME,SIZE,TYPE | grep disk" 2>$null
        if ($LASTEXITCODE -eq 0 -and $disks) {
            $diskLines = $disks -split "`n" | Where-Object { $_ }
            $systemInfo.DiskInfo = $diskLines
            Write-Host " ✓ ($($diskLines.Count) disk(s))" -ForegroundColor Green
            foreach ($disk in $diskLines) {
                Write-Host "      • $disk" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host " Error checking" -ForegroundColor Red
    }

    # Check memory
    Write-Host "  [9/10] Memory..." -ForegroundColor Cyan -NoNewline
    try {
        $memInfo = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${IP}" "free -g | grep Mem | awk '{print `$2}'" 2>$null
        if ($LASTEXITCODE -eq 0 -and $memInfo) {
            $systemInfo.MemoryGB = [int]$memInfo
            Write-Host " ✓ ${memInfo}GB" -ForegroundColor Green
        }
    } catch {
        Write-Host " Error checking" -ForegroundColor Red
    }

    # Check CPUs
    Write-Host "  [10/10] CPUs..." -ForegroundColor Cyan -NoNewline
    try {
        $cpuInfo = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${Username}@${IP}" "nproc" 2>$null
        if ($LASTEXITCODE -eq 0 -and $cpuInfo) {
            $systemInfo.CPUCount = [int]$cpuInfo
            Write-Host " ✓ ${cpuInfo} cores" -ForegroundColor Green
        }
    } catch {
        Write-Host " Error checking" -ForegroundColor Red
    }

    Write-Host ""
    return $systemInfo
}

###############################################################################
# Check both systems
###############################################################################

Write-Host "Starting inventory of both TrueNAS systems..." -ForegroundColor Cyan
Write-Host ""

# Check Baby NAS
$results.BabyNAS = Check-TrueNASSystem -SystemName "Baby NAS (Hyper-V VM)" -IP $BabyNasIP -Username $BabyUser

# Check Bare Metal
$results.BareMetal = Check-TrueNASSystem -SystemName "Bare Metal TrueNAS" -IP $BareMetalIP -Username $BareMetalUser

###############################################################################
# Summary and Recommendations
###############################################################################

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                   ║" -ForegroundColor Green
Write-Host "║                    INVENTORY SUMMARY                              ║" -ForegroundColor Green
Write-Host "║                                                                   ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Baby NAS Summary
Write-Host "Baby NAS (VM) - $BabyNasIP" -ForegroundColor Cyan
Write-Host "  Status: $(if ($results.BabyNAS.Online) { 'ONLINE' } else { 'OFFLINE' })" -ForegroundColor $(if ($results.BabyNAS.Online) { 'Green' } else { 'Red' })
if ($results.BabyNAS.Online) {
    Write-Host "  Hardware: $($results.BabyNAS.MemoryGB)GB RAM, $($results.BabyNAS.CPUCount) CPUs" -ForegroundColor White
    Write-Host "  ZFS Pools: $($results.BabyNAS.ZFSPools.Count)" -ForegroundColor White
    Write-Host "  Datasets: $($results.BabyNAS.Datasets.Count)" -ForegroundColor White
    Write-Host "  Docker: $(if ($results.BabyNAS.DockerInstalled) { 'INSTALLED ⚠️ SHOULD BE REMOVED' } else { 'Not installed ✓' })" -ForegroundColor $(if ($results.BabyNAS.DockerInstalled) { 'Yellow' } else { 'Green' })
    Write-Host "  Docker Containers: $($results.BabyNAS.DockerContainers.Count)" -ForegroundColor White
    Write-Host "  SMB Shares: $($results.BabyNAS.SMBShares.Count)" -ForegroundColor White
    Write-Host "  Disks: $($results.BabyNAS.DiskInfo.Count)" -ForegroundColor White
}
Write-Host ""

# Bare Metal Summary
Write-Host "Bare Metal TrueNAS - $BareMetalIP" -ForegroundColor Cyan
Write-Host "  Status: $(if ($results.BareMetal.Online) { 'ONLINE' } else { 'OFFLINE' })" -ForegroundColor $(if ($results.BareMetal.Online) { 'Green' } else { 'Red' })
if ($results.BareMetal.Online) {
    Write-Host "  Hardware: $($results.BareMetal.MemoryGB)GB RAM, $($results.BareMetal.CPUCount) CPUs" -ForegroundColor White
    Write-Host "  ZFS Pools: $($results.BareMetal.ZFSPools.Count)" -ForegroundColor White
    Write-Host "  Datasets: $($results.BareMetal.Datasets.Count)" -ForegroundColor White
    Write-Host "  Docker: $(if ($results.BareMetal.DockerInstalled) { 'INSTALLED ✓' } else { 'Not installed - NEEDS INSTALLATION' })" -ForegroundColor $(if ($results.BareMetal.DockerInstalled) { 'Green' } else { 'Yellow' })
    Write-Host "  Docker Containers: $($results.BareMetal.DockerContainers.Count)" -ForegroundColor White
    Write-Host "  SMB Shares: $($results.BareMetal.SMBShares.Count)" -ForegroundColor White
    Write-Host "  Disks: $($results.BareMetal.DiskInfo.Count)" -ForegroundColor White
}
Write-Host ""

###############################################################################
# Recommendations
###############################################################################

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "  RECOMMENDATIONS" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""

$recommendations = @()

# Baby NAS recommendations
if ($results.BabyNAS.Online) {
    if ($results.BabyNAS.DockerInstalled) {
        $recommendations += @{
            System = "Baby NAS"
            Priority = "HIGH"
            Action = "Remove Docker and migrate containers to Bare Metal"
            Reason = "Baby NAS should be storage-only (SMB/NFS)"
        }
    }

    if ($results.BabyNAS.ZFSPools.Count -eq 0) {
        $recommendations += @{
            System = "Baby NAS"
            Priority = "HIGH"
            Action = "Create ZFS pool with RAIDZ1 + SLOG + L2ARC"
            Reason = "Storage pool not configured"
        }
    }

    if ($results.BabyNAS.SMBShares.Count -eq 0) {
        $recommendations += @{
            System = "Baby NAS"
            Priority = "MEDIUM"
            Action = "Configure SMB shares for Windows access"
            Reason = "No shares configured"
        }
    }
}

# Bare Metal recommendations
if ($results.BareMetal.Online) {
    if (-not $results.BareMetal.DockerInstalled) {
        $recommendations += @{
            System = "Bare Metal"
            Priority = "HIGH"
            Action = "Install Docker and deploy services"
            Reason = "Services host needs Docker"
        }
    }

    if ($results.BareMetal.DockerContainers.Count -eq 0 -and $results.BareMetal.DockerInstalled) {
        $recommendations += @{
            System = "Bare Metal"
            Priority = "HIGH"
            Action = "Deploy development services (Gitea, n8n, VS Code, etc.)"
            Reason = "Docker installed but no services running"
        }
    }
} else {
    $recommendations += @{
        System = "Bare Metal"
        Priority = "CRITICAL"
        Action = "Bring Bare Metal TrueNAS online"
        Reason = "Cannot deploy services while offline"
    }
}

# Display recommendations
if ($recommendations.Count -gt 0) {
    foreach ($rec in $recommendations) {
        $color = switch ($rec.Priority) {
            "CRITICAL" { "Red" }
            "HIGH" { "Yellow" }
            "MEDIUM" { "Cyan" }
            default { "White" }
        }

        Write-Host "[$($rec.Priority)]" -ForegroundColor $color -NoNewline
        Write-Host " $($rec.System): $($rec.Action)" -ForegroundColor White
        Write-Host "    Reason: $($rec.Reason)" -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "  ✓ No immediate actions required" -ForegroundColor Green
    Write-Host ""
}

###############################################################################
# Next Steps
###############################################################################

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  NEXT STEPS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Based on this inventory:" -ForegroundColor White
Write-Host ""

if ($results.BareMetal.Online) {
    Write-Host "1. Review D:\workspace\True_Nas\ARCHITECTURE-CLARIFICATION.md" -ForegroundColor White
    Write-Host "2. Separate scripts into baby-nas-scripts/ and bare-metal-scripts/" -ForegroundColor White
    Write-Host "3. Deploy storage configuration to Baby NAS" -ForegroundColor White
    Write-Host "4. Deploy services to Bare Metal TrueNAS" -ForegroundColor White
} else {
    Write-Host "1. Bring Bare Metal TrueNAS (10.0.0.89) online" -ForegroundColor Yellow
    Write-Host "2. Re-run this inventory script" -ForegroundColor White
    Write-Host "3. Review ARCHITECTURE-CLARIFICATION.md" -ForegroundColor White
    Write-Host "4. Proceed with deployment plan" -ForegroundColor White
}

Write-Host ""

# Save results to file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportFile = "D:\workspace\True_Nas\logs\inventory-$timestamp.json"

if (-not (Test-Path "D:\workspace\True_Nas\logs")) {
    New-Item -ItemType Directory -Path "D:\workspace\True_Nas\logs" -Force | Out-Null
}

$results | ConvertTo-Json -Depth 10 | Out-File $reportFile
Write-Host "Detailed inventory saved to: $reportFile" -ForegroundColor Gray
Write-Host ""
