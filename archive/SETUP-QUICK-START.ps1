#Requires -Version 5.0
# Quick Setup for BabyNAS Snapshots & Replication
# Updated with detected IP: 172.31.246.136

Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║      BabyNAS SNAPSHOTS & REPLICATION - QUICK SETUP        ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Configuration
$BabyNasIP = "172.31.246.136"
$BabyNasHostname = "babynas.isndotbiz.com"
$BabyNasWebUI = "https://$BabyNasIP"
$MainNasIP = "10.0.0.89"
$MainNasWebUI = "https://$MainNasIP"

Write-Host "📋 Configuration Summary:" -ForegroundColor Yellow
Write-Host "   BabyNAS IP:        $BabyNasIP" -ForegroundColor Green
Write-Host "   BabyNAS Hostname:  $BabyNasHostname"
Write-Host "   Main NAS IP:       $MainNasIP"
Write-Host "   Replication User:  baby-nas"
Write-Host "   Target Dataset:    tank/rag-system"
Write-Host ""

# Test connectivity
Write-Host "🔌 Testing Connectivity..." -ForegroundColor Yellow
Write-Host ""

Write-Host "   Testing BabyNAS ($BabyNasIP)..." -ForegroundColor Gray
$ping_baby = Test-Connection -ComputerName $BabyNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($ping_baby) {
    Write-Host "   [OK] BabyNAS is reachable" -ForegroundColor Green
} else {
    Write-Host "   [WARNING] Cannot ping BabyNAS (check network/firewall)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "   Testing Main NAS ($MainNasIP)..." -ForegroundColor Gray
$ping_main = Test-Connection -ComputerName $MainNasIP -Count 1 -Quiet -ErrorAction SilentlyContinue
if ($ping_main) {
    Write-Host "   [OK] Main NAS is reachable" -ForegroundColor Green
} else {
    Write-Host "   [ERROR] Cannot reach Main NAS" -ForegroundColor Red
    Write-Host "   Note: Replication will fail if Main NAS is unreachable"
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✨ NEXT STEPS:" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "1️⃣  OPEN BABYNAS WEB UI AND CREATE SNAPSHOT TASKS" -ForegroundColor Yellow
Write-Host ""
Write-Host "   URL: $BabyNasWebUI" -ForegroundColor Cyan
Write-Host "   Path: System → Tasks → Periodic Snapshot Tasks" -ForegroundColor Gray
Write-Host ""
Write-Host "   Create 3 tasks:" -ForegroundColor White
Write-Host ""
Write-Host "   📌 TASK 1: Hourly Snapshots" -ForegroundColor Magenta
Write-Host "      • Datasets: tank/backups, tank/veeam, tank/wsl-backups, tank/media"
Write-Host "      • Schedule: Every hour (0 * * * *)"
Write-Host "      • Snapshot Name: auto-{pool}-{dataset}-hourly-{year}{month}{day}-{hour}00"
Write-Host "      • Keep: 24 snapshots"
Write-Host "      • Recursive: YES"
Write-Host "      • Enabled: YES"
Write-Host ""
Write-Host "   📌 TASK 2: Daily Snapshots" -ForegroundColor Magenta
Write-Host "      • Datasets: (same as above)"
Write-Host "      • Schedule: Every day at 02:00 AM (0 2 * * *)"
Write-Host "      • Snapshot Name: auto-{pool}-{dataset}-daily-{year}{month}{day}"
Write-Host "      • Keep: 7 snapshots"
Write-Host "      • Recursive: YES"
Write-Host "      • Enabled: YES"
Write-Host ""
Write-Host "   📌 TASK 3: Weekly Snapshots" -ForegroundColor Magenta
Write-Host "      • Datasets: (same as above)"
Write-Host "      • Schedule: Every Sunday at 03:00 AM (0 3 * * 0)"
Write-Host "      • Snapshot Name: auto-{pool}-{dataset}-weekly-{year}-w{week}"
Write-Host "      • Keep: 4 snapshots"
Write-Host "      • Recursive: YES"
Write-Host "      • Enabled: YES"
Write-Host ""

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "2️⃣  CREATE REPLICATION TASK" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   URL: $BabyNasWebUI" -ForegroundColor Cyan
Write-Host "   Path: Tasks → Replication Tasks → Add" -ForegroundColor Gray
Write-Host ""
Write-Host "   Configuration:" -ForegroundColor White
Write-Host "   • Name:               BabyNAS to Main NAS - Hourly"
Write-Host "   • Description:        Automatic hourly replication to Main NAS"
Write-Host "   • Direction:          PUSH (BabyNAS → Main NAS)"
Write-Host "   • Transport:          SSH"
Write-Host ""
Write-Host "   SSH Credentials:" -ForegroundColor White
Write-Host "   • Hostname:           $MainNasIP"
Write-Host "   • Username:           baby-nas"
Write-Host "   • Port:               22"
Write-Host "   • Connect using:      SSH Public Key (leave blank)"
Write-Host ""
Write-Host "   Source Datasets:" -ForegroundColor White
Write-Host "   • tank/backups"
Write-Host "   • tank/veeam"
Write-Host "   • tank/wsl-backups"
Write-Host "   • tank/media"
Write-Host ""
Write-Host "   Target Dataset:       tank/rag-system" -ForegroundColor White
Write-Host "   Recursive:            YES"
Write-Host "   Include Properties:   YES"
Write-Host ""
Write-Host "   Schedule:             Hourly" -ForegroundColor White
Write-Host "   • Minute:             0"
Write-Host "   • Hour:               * (every hour)"
Write-Host ""
Write-Host "   Advanced:" -ForegroundColor White
Write-Host "   • Enable:             YES"
Write-Host "   • Replicate Snapshots: YES"
Write-Host "   • Allow from Scratch:  YES"
Write-Host "   • Hold Pending:        NO"
Write-Host ""
Write-Host "   Then click: SAVE"
Write-Host ""

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "⏱️  WHAT HAPPENS NEXT:" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   +1 hour     → First hourly snapshot created" -ForegroundColor Gray
Write-Host "   +2 hours    → First replication run starts" -ForegroundColor Gray
Write-Host "   +4-6 hours  → Full initial sync completes (4-5 TB)" -ForegroundColor Gray
Write-Host "   +24 hours   → Daily snapshots + incremental working" -ForegroundColor Gray
Write-Host "   +7 days     → Full rotation complete" -ForegroundColor Gray
Write-Host ""

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "🔍 MONITOR PROGRESS AT:" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   BabyNAS:   $BabyNasWebUI" -ForegroundColor Cyan
Write-Host "   • System → Tasks → Periodic Snapshot Tasks (snapshots)" -ForegroundColor Gray
Write-Host "   • Tasks → Replication Tasks (replication status)" -ForegroundColor Gray
Write-Host ""
Write-Host "   Main NAS:  $MainNasWebUI" -ForegroundColor Cyan
Write-Host "   • Storage → Pools → tank → rag-system (data receiving)" -ForegroundColor Gray
Write-Host "   • System → Logs → Services (error checking)" -ForegroundColor Gray
Write-Host ""

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✅ SUCCESS CRITERIA:" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   ✓ Snapshots appearing hourly in BabyNAS"
Write-Host "   ✓ Replication task shows recent runs"
Write-Host "   ✓ Space increasing on Main NAS (tank/rag-system)"
Write-Host "   ✓ No errors in Main NAS logs"
Write-Host ""

Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "📞 NEED HELP?" -ForegroundColor Yellow
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "   See: DEPLOYMENT-STATUS-AND-NEXT-STEPS.md" -ForegroundColor Gray
Write-Host "   Or:  SNAPSHOT-REPLICATION-GUIDE.md" -ForegroundColor Gray
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ready to proceed! Open TrueNAS at: $BabyNasWebUI" -ForegroundColor Green
Write-Host ""
