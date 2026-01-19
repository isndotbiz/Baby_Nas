# Get detailed system configuration from both TrueNAS systems

$BabyNasIP = "172.21.203.18"
$BareMetalIP = "10.0.0.89"

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║          Getting Detailed System Configuration             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Function to run command on a system
function Get-SystemInfo {
    param([string]$IP, [string]$User, [string]$Name)

    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host "  $Name ($IP)" -ForegroundColor Yellow
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Yellow
    Write-Host ""

    # Commands as individual strings (bash will handle them)
    $cmds = @{
        "Hostname" = "hostname"
        "Memory" = "free -h | grep Mem"
        "CPU Cores" = "nproc"
        "ZFS Pools" = "zpool list 2>/dev/null | head -5"
        "Docker Version" = "docker --version 2>/dev/null"
        "Docker Containers" = "docker ps --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null"
        "Samba Service" = "systemctl is-active smbd 2>/dev/null"
        "SMB Shares" = "testparm -s 2>/dev/null | grep '^\\[' | head -10"
        "Disks" = "lsblk -d -o NAME,SIZE 2>/dev/null | tail -n +2"
    }

    foreach ($label in $cmds.Keys) {
        $cmd = $cmds[$label]
        Write-Host "$label:" -ForegroundColor Cyan -NoNewline
        Write-Host ""

        # Run the command via SSH
        $result = ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 "$User@$IP" $cmd 2>$null

        if ($result) {
            foreach ($line in $result) {
                Write-Host "  $line" -ForegroundColor Gray
            }
        } else {
            Write-Host "  (no output)" -ForegroundColor Gray
        }

        Write-Host ""
    }
}

# Get info from both systems
Get-SystemInfo -IP $BabyNasIP -User "admin" -Name "Baby NAS (VM)"
Get-SystemInfo -IP $BareMetalIP -User "root" -Name "Bare Metal TrueNAS"

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  Summary and Recommendations" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review the configuration above" -ForegroundColor White
Write-Host "  2. Based on findings, we'll:" -ForegroundColor White
Write-Host "     - Separate scripts (baby-nas-scripts vs bare-metal-scripts)" -ForegroundColor White
Write-Host "     - Fix security issues" -ForegroundColor White
Write-Host "     - Deploy services to correct system" -ForegroundColor White
Write-Host ""
