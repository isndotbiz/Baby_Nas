#Requires -Version 5.0
# Setup replication infrastructure on Main NAS

param(
    [string]$AdminUser = "admin",
    [string]$AdminPassword = "74108520",
    [string]$MainNasIP = "10.0.0.89",
    [string]$BabyNasIP = "172.31.246.136"
)

Write-Host ""
Write-Host "=== SETUP REPLICATION INFRASTRUCTURE ===" -ForegroundColor Cyan
Write-Host ""

$ApiUrl = "http://$MainNasIP/api/v2.0"
$NewAdminPassword = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})
$BabyNasUser = "baby-nas"

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Main NAS IP:        $MainNasIP"
Write-Host "  BabyNAS IP:         $BabyNasIP"
Write-Host "  Replication User:   $BabyNasUser"
Write-Host ""

# Step 1: Authenticate
Write-Host "Step 1: Authenticating to TrueNAS API..." -ForegroundColor Yellow

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$AdminUser`:$AdminPassword"))
$headers = @{
    'Authorization' = "Basic $auth"
    'Content-Type' = 'application/json'
}

try {
    $version = Invoke-RestMethod -Uri "$ApiUrl/system/version" -Headers $headers -ErrorAction Stop
    Write-Host "✓ Authenticated to TrueNAS API" -ForegroundColor Green
    Write-Host "  Version: $($version.version)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Failed to authenticate" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Get SSH key from BabyNAS
Write-Host "Step 2: Getting SSH public key from BabyNAS..." -ForegroundColor Yellow

$sshKey = ""
try {
    $output = ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@$BabyNasIP "cat ~/.ssh/id_ed25519.pub" 2>&1
    $sshKey = $output | Select-Object -First 1

    if ($sshKey -match "ssh-ed25519") {
        Write-Host "✓ Retrieved SSH public key" -ForegroundColor Green
        Write-Host "  Key: $($sshKey.Substring(0, 50))..." -ForegroundColor Gray
    } else {
        Write-Host "✗ Invalid SSH key" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "✗ Could not retrieve SSH key" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Create baby-nas user
Write-Host "Step 3: Creating $BabyNasUser user on Main NAS..." -ForegroundColor Yellow

$userBody = @{
    username = $BabyNasUser
    full_name = "BabyNAS Replication User"
    shell = "/usr/sbin/nologin"
    home = "/nonexistent"
    password_disabled = $true
    ssh_password_enabled = $false
} | ConvertTo-Json

try {
    $users = Invoke-RestMethod -Uri "$ApiUrl/user" -Headers $headers -ErrorAction SilentlyContinue
    $existing = $users | Where-Object { $_.username -eq $BabyNasUser }

    if ($existing) {
        Write-Host "✓ User $BabyNasUser already exists (UID: $($existing.uid))" -ForegroundColor Green
        $userId = $existing.uid
    } else {
        $newUser = Invoke-RestMethod -Uri "$ApiUrl/user" -Headers $headers -Method Post -Body $userBody -ErrorAction Stop
        Write-Host "✓ Created user $BabyNasUser (UID: $($newUser.uid))" -ForegroundColor Green
        $userId = $newUser.uid
    }
} catch {
    Write-Host "✗ Failed to create user" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Add SSH key
Write-Host "Step 4: Adding SSH public key to user..." -ForegroundColor Yellow

$updateBody = @{
    ssh_pubkey = $sshKey
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$ApiUrl/user/$userId" -Headers $headers -Method Put -Body $updateBody -ErrorAction Stop | Out-Null
    Write-Host "✓ SSH public key added" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to add SSH key" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Verify dataset
Write-Host "Step 5: Verifying tank/rag-system dataset..." -ForegroundColor Yellow

try {
    $datasets = Invoke-RestMethod -Uri "$ApiUrl/pool/dataset" -Headers $headers -ErrorAction SilentlyContinue
    $ragDataset = $datasets | Where-Object { $_.name -eq "tank/rag-system" }

    if ($ragDataset) {
        Write-Host "✓ Dataset tank/rag-system exists" -ForegroundColor Green
    } else {
        Write-Host "! Dataset tank/rag-system not found (will be created on first replication)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "! Could not verify dataset" -ForegroundColor Yellow
}

Write-Host ""

# Step 6: Rotate admin password
Write-Host "Step 6: Rotating admin password..." -ForegroundColor Yellow

$pwdBody = @{
    password = $NewAdminPassword
} | ConvertTo-Json

try {
    $adminUsers = Invoke-RestMethod -Uri "$ApiUrl/user" -Headers $headers -ErrorAction SilentlyContinue
    $adminObj = $adminUsers | Where-Object { $_.username -eq $AdminUser }

    if ($adminObj) {
        Invoke-RestMethod -Uri "$ApiUrl/user/$($adminObj.uid)" -Headers $headers -Method Put -Body $pwdBody -ErrorAction Stop | Out-Null
        Write-Host "✓ Admin password rotated" -ForegroundColor Green
    }
} catch {
    Write-Host "! Could not rotate password automatically" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "SETUP COMPLETE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Created:" -ForegroundColor Yellow
Write-Host "  ✓ User: $BabyNasUser"
Write-Host "  ✓ SSH Key: Configured"
Write-Host "  ✓ Admin Password: Rotated"
Write-Host ""

Write-Host "NEW ADMIN CREDENTIALS:" -ForegroundColor Cyan
Write-Host "  Username: $AdminUser"
Write-Host "  Password: $NewAdminPassword"
Write-Host ""

Write-Host "REQUIRED: Grant ZFS permissions via TrueNAS Shell:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  zfs allow -u $BabyNasUser create,receive,rollback,destroy,mount tank/rag-system"
Write-Host ""

Write-Host "Then proceed with creating snapshot tasks in BabyNAS TrueNAS Web UI."
Write-Host ""
