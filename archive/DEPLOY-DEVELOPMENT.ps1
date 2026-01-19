###############################################################################
# Development Environment Deployment Script (Windows PowerShell Wrapper)
# Deploys Gitea, n8n, VS Code Server, PostgreSQL, and Nginx Proxy on Baby NAS
###############################################################################

param(
    [Parameter(Mandatory=$false)]
    [string]$BabyNasIP = "",

    [Parameter(Mandatory=$false)]
    [string]$BabyNasUser = "truenas_admin",

    [Parameter(Mandatory=$false)]
    [switch]$SkipSSHCheck
)

$ErrorActionPreference = "Stop"

# ASCII Banner
Write-Host @"
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║       Development Environment Deployment for Baby NAS                   ║
║       Gitea + n8n + VS Code Server + PostgreSQL + Nginx                 ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "⚠ WARNING: Not running as Administrator. Some operations may fail." -ForegroundColor Yellow
    Write-Host ""
}

# Find Baby NAS IP if not provided
if ([string]::IsNullOrWhiteSpace($BabyNasIP)) {
    Write-Host "Step 1: Locating Baby NAS..." -ForegroundColor Green
    Write-Host ""

    # Try to find from Hyper-V VM
    try {
        $vm = Get-VM -Name "*Baby*NAS*" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($vm) {
            Write-Host "✓ Found Baby NAS VM: $($vm.Name)" -ForegroundColor Green

            # Get IP from VM network adapter
            $networkAdapter = Get-VMNetworkAdapter -VM $vm
            $ipAddress = $networkAdapter | ForEach-Object {
                Get-VMNetworkAdapterAcl -VMNetworkAdapter $_ -ErrorAction SilentlyContinue
            } | Select-Object -ExpandProperty IPAddress -ErrorAction SilentlyContinue

            if ($ipAddress) {
                $BabyNasIP = $ipAddress
                Write-Host "✓ Detected IP: $BabyNasIP" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "⚠ Could not auto-detect Baby NAS VM" -ForegroundColor Yellow
    }

    # If still not found, prompt user
    if ([string]::IsNullOrWhiteSpace($BabyNasIP)) {
        Write-Host ""
        $BabyNasIP = Read-Host "Enter Baby NAS IP address"
    }
    Write-Host ""
}

Write-Host "Target Baby NAS: $BabyNasIP" -ForegroundColor Cyan
Write-Host "SSH User: $BabyNasUser" -ForegroundColor Cyan
Write-Host ""

# Verify SSH connectivity
if (-not $SkipSSHCheck) {
    Write-Host "Step 2: Verifying SSH connectivity..." -ForegroundColor Green
    Write-Host ""

    $sshTest = ssh -o ConnectTimeout=5 -o BatchMode=yes "${BabyNasUser}@${BabyNasIP}" "echo 'OK'" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ SSH connection failed!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please ensure:" -ForegroundColor Yellow
        Write-Host "  1. Baby NAS is running and accessible" -ForegroundColor Yellow
        Write-Host "  2. SSH keys are configured" -ForegroundColor Yellow
        Write-Host "  3. User '$BabyNasUser' exists and has sudo privileges" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Run setup-ssh-keys-complete.ps1 first if needed." -ForegroundColor Yellow
        Write-Host ""
        exit 1
    }

    Write-Host "✓ SSH connection successful" -ForegroundColor Green
    Write-Host ""
}

# Prepare deployment script path
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$truenasScriptsDir = Join-Path (Split-Path -Parent $scriptDir) "truenas-scripts"
$setupScript = Join-Path $truenasScriptsDir "setup-development-services.sh"

if (-not (Test-Path $setupScript)) {
    Write-Host "✗ Setup script not found: $setupScript" -ForegroundColor Red
    exit 1
}

Write-Host "Step 3: Uploading deployment script to Baby NAS..." -ForegroundColor Green
Write-Host ""

# Upload script to Baby NAS
scp -o StrictHostKeyChecking=no "$setupScript" "${BabyNasUser}@${BabyNasIP}:/tmp/setup-development-services.sh"
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to upload script" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Script uploaded successfully" -ForegroundColor Green
Write-Host ""

# Make script executable
ssh "${BabyNasUser}@${BabyNasIP}" "chmod +x /tmp/setup-development-services.sh"

Write-Host "Step 4: Executing deployment on Baby NAS..." -ForegroundColor Green
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Execute deployment script
ssh -t "${BabyNasUser}@${BabyNasIP}" "sudo /tmp/setup-development-services.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "✗ Deployment encountered errors" -ForegroundColor Red
    Write-Host ""
    Write-Host "Check the logs on Baby NAS:" -ForegroundColor Yellow
    Write-Host "  ssh ${BabyNasUser}@${BabyNasIP}" -ForegroundColor White
    Write-Host "  sudo cat /var/log/dev-services-install.log" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "✓ Deployment completed successfully!" -ForegroundColor Green
Write-Host ""

# Display access information
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Development Services Access Information" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Service URLs:" -ForegroundColor Green
Write-Host "  Gitea (Git Server):       https://git.baby.isn.biz" -ForegroundColor White
Write-Host "                            http://${BabyNasIP}:3000" -ForegroundColor Gray
Write-Host ""
Write-Host "  n8n (Automation):         https://n8n.baby.isn.biz" -ForegroundColor White
Write-Host "                            http://${BabyNasIP}:5678" -ForegroundColor Gray
Write-Host ""
Write-Host "  VS Code Server:           https://code.baby.isn.biz" -ForegroundColor White
Write-Host "                            http://${BabyNasIP}:8080" -ForegroundColor Gray
Write-Host ""
Write-Host "  PostgreSQL:               ${BabyNasIP}:5432" -ForegroundColor White
Write-Host ""
Write-Host "  Nginx Proxy Dashboard:    https://proxy.baby.isn.biz" -ForegroundColor White
Write-Host "                            http://${BabyNasIP}:81" -ForegroundColor Gray
Write-Host ""

Write-Host "Default Credentials:" -ForegroundColor Green
Write-Host "  Gitea:          admin / Dev@BabyNAS2024" -ForegroundColor White
Write-Host "  n8n:            admin@baby.isn.biz / Dev@BabyNAS2024" -ForegroundColor White
Write-Host "  VS Code:        password: Dev@BabyNAS2024" -ForegroundColor White
Write-Host "  PostgreSQL:     devuser / Dev@BabyNAS2024" -ForegroundColor White
Write-Host "  Nginx Proxy:    admin@baby.isn.biz / Dev@BabyNAS2024" -ForegroundColor White
Write-Host ""

Write-Host "⚠ IMPORTANT: Change all default passwords after first login!" -ForegroundColor Yellow
Write-Host ""

Write-Host "Data Locations (on Baby NAS):" -ForegroundColor Green
Write-Host "  Git Repositories:     /mnt/tank/development/git-repos" -ForegroundColor White
Write-Host "  n8n Workflows:        /mnt/tank/development/n8n" -ForegroundColor White
Write-Host "  VS Code Workspaces:   /mnt/tank/development/vscode" -ForegroundColor White
Write-Host "  PostgreSQL Data:      /mnt/tank/development/databases/postgres" -ForegroundColor White
Write-Host "  Nginx Configs:        /mnt/tank/development/nginx-proxy" -ForegroundColor White
Write-Host ""

Write-Host "Management Commands:" -ForegroundColor Green
Write-Host "  View all containers:   ssh ${BabyNasUser}@${BabyNasIP} 'docker ps -a'" -ForegroundColor White
Write-Host "  View logs:             ssh ${BabyNasUser}@${BabyNasIP} 'cd /opt/development && docker-compose logs -f [service]'" -ForegroundColor White
Write-Host "  Restart service:       ssh ${BabyNasUser}@${BabyNasIP} 'cd /opt/development && docker-compose restart [service]'" -ForegroundColor White
Write-Host "  Stop all:              ssh ${BabyNasUser}@${BabyNasIP} 'cd /opt/development && docker-compose down'" -ForegroundColor White
Write-Host "  Start all:             ssh ${BabyNasUser}@${BabyNasIP} 'cd /opt/development && docker-compose up -d'" -ForegroundColor White
Write-Host ""

Write-Host "Management Scripts (on Baby NAS):" -ForegroundColor Green
Write-Host "  /opt/development/dev-start.sh      - Start all services" -ForegroundColor White
Write-Host "  /opt/development/dev-stop.sh       - Stop all services" -ForegroundColor White
Write-Host "  /opt/development/dev-restart.sh    - Restart all services" -ForegroundColor White
Write-Host "  /opt/development/dev-logs.sh       - View logs" -ForegroundColor White
Write-Host "  /opt/development/dev-backup.sh     - Backup configurations" -ForegroundColor White
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Green
Write-Host "  1. Access Gitea and create your first repository" -ForegroundColor White
Write-Host "  2. Configure n8n workflows for TrueNAS automation" -ForegroundColor White
Write-Host "  3. Open VS Code Server and connect to your projects" -ForegroundColor White
Write-Host "  4. Setup PostgreSQL databases for your applications" -ForegroundColor White
Write-Host "  5. Review backup schedule (daily snapshots configured)" -ForegroundColor White
Write-Host ""

Write-Host "Documentation:" -ForegroundColor Green
Write-Host "  Full setup guide: /mnt/tank/development/README-DEVELOPMENT.md" -ForegroundColor White
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Offer to open browser
$openBrowser = Read-Host "Open Gitea in browser? (y/n)"
if ($openBrowser -eq "y") {
    Start-Process "http://${BabyNasIP}:3000"
}

Write-Host ""
Write-Host "Deployment complete! Happy coding! 🚀" -ForegroundColor Green
Write-Host ""
