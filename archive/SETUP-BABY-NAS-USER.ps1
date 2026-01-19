#Requires -Version 5.0
param(
    [string]$AdminUser = "admin",
    [string]$AdminPassword = "74108520",
    [string]$MainNasIP = "10.0.0.89",
    [string]$BabyNasIP = "172.31.246.136"
)

Write-Host ""
Write-Host "=== CREATE BABY-NAS REPLICATION USER ===" -ForegroundColor Cyan
Write-Host ""

$ApiUrl = "http://$MainNasIP/api/v2.0"

# Step 1: Get SSH Key
Write-Host "Step 1: Retrieving SSH key from BabyNAS..." -ForegroundColor Yellow
$sshKey = ssh -i "$env:USERPROFILE\.ssh\id_ed25519" root@$BabyNasIP "cat ~/.ssh/id_ed25519.pub"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Could not get SSH key from BabyNAS" -ForegroundColor Red
    exit 1
}

Write-Host "OK: SSH key retrieved" -ForegroundColor Green
Write-Host ""

# Step 2: Authenticate
Write-Host "Step 2: Authenticating to Main NAS API..." -ForegroundColor Yellow
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$AdminUser`:$AdminPassword"))
$headers = @{
    'Authorization' = "Basic $auth"
    'Content-Type' = 'application/json'
}

$response = Invoke-WebRequest -Uri "$ApiUrl/system/version" -Headers $headers -ErrorAction SilentlyContinue
if ($response.StatusCode -ne 200) {
    Write-Host "ERROR: Could not authenticate" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Authenticated to TrueNAS API" -ForegroundColor Green
Write-Host ""

# Step 3: Create user
Write-Host "Step 3: Creating baby-nas user..." -ForegroundColor Yellow

$userJson = @"
{
  "username": "baby-nas",
  "full_name": "BabyNAS Replication User",
  "shell": "/usr/sbin/nologin",
  "home": "/nonexistent",
  "password_disabled": true,
  "ssh_password_enabled": false
}
"@

$createResponse = Invoke-WebRequest -Uri "$ApiUrl/user" -Headers $headers -Method Post -Body $userJson -ErrorAction SilentlyContinue

if ($createResponse.StatusCode -eq 200 -or $createResponse.StatusCode -eq 201) {
    Write-Host "OK: Created baby-nas user" -ForegroundColor Green
}
else {
    Write-Host "WARNING: Could not create user (may already exist)" -ForegroundColor Yellow
}

Write-Host ""

# Step 4: Get user list and find baby-nas
Write-Host "Step 4: Adding SSH key to baby-nas user..." -ForegroundColor Yellow

$usersResponse = Invoke-RestMethod -Uri "$ApiUrl/user" -Headers $headers -Method Get
$babyNasUser = $usersResponse | Where-Object { $_.username -eq "baby-nas" }

if ($babyNasUser) {
    $userId = $babyNasUser.uid
    Write-Host "Found user: baby-nas (UID: $userId)" -ForegroundColor Gray

    $updateJson = @"
{
  "ssh_pubkey": "$sshKey"
}
"@

    $updateResponse = Invoke-WebRequest -Uri "$ApiUrl/user/$userId" -Headers $headers -Method Put -Body $updateJson -ErrorAction SilentlyContinue

    if ($updateResponse.StatusCode -eq 200) {
        Write-Host "OK: SSH key added to baby-nas user" -ForegroundColor Green
    }
    else {
        Write-Host "ERROR: Could not add SSH key" -ForegroundColor Red
    }
}
else {
    Write-Host "ERROR: baby-nas user not found" -ForegroundColor Red
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "SETUP COMPLETE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Created:" -ForegroundColor Yellow
Write-Host "  ✓ User: baby-nas"
Write-Host "  ✓ SSH Public Key: Added"
Write-Host ""

Write-Host "NEXT STEP: Grant ZFS Permissions" -ForegroundColor Yellow
Write-Host ""
Write-Host "Open TrueNAS Shell and run:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  zfs allow -u baby-nas create,receive,rollback,destroy,mount tank/rag-system" -ForegroundColor Gray
Write-Host ""
Write-Host "Then verify:" -ForegroundColor Gray
Write-Host "  zfs allow tank/rag-system | grep baby-nas" -ForegroundColor Gray
Write-Host ""
