# Simple system info gathering

$BabyNasIP = "172.21.203.18"
$BareMetalIP = "10.0.0.89"

Write-Host ""
Write-Host "════════════ Baby NAS ($BabyNasIP) ════════════" -ForegroundColor Yellow

Write-Host "Hostname:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$BabyNasIP" hostname 2>$null

Write-Host "Memory:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$BabyNasIP" "free -h | grep Mem" 2>$null

Write-Host "CPUs:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$BabyNasIP" nproc 2>$null

Write-Host "ZFS Pools:" -ForegroundColor Cyan
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$BabyNasIP" "zpool list 2>/dev/null" 2>$null

Write-Host "Docker:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$BabyNasIP" "docker --version" 2>$null

Write-Host "Samba Status:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "admin@$BabyNasIP" "systemctl is-active smbd" 2>$null

Write-Host ""
Write-Host "════════════ Bare Metal ($BareMetalIP) ════════════" -ForegroundColor Yellow

Write-Host "Hostname:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$BareMetalIP" hostname 2>$null

Write-Host "Memory:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$BareMetalIP" "free -h | grep Mem" 2>$null

Write-Host "CPUs:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$BareMetalIP" nproc 2>$null

Write-Host "ZFS Pools:" -ForegroundColor Cyan
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$BareMetalIP" "zpool list 2>/dev/null" 2>$null

Write-Host "Docker:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$BareMetalIP" "docker --version" 2>$null

Write-Host "Samba Status:" -ForegroundColor Cyan -NoNewline
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$BareMetalIP" "systemctl is-active smbd" 2>$null

Write-Host ""
