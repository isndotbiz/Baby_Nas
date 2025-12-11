#Requires -RunAsAdministrator
###############################################################################
# Complete SSH Key Setup for Baby NAS
# Generates keys, deploys to both Baby NAS and Main NAS, creates SSH config
###############################################################################

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$MainNasIP = "10.0.0.89",
    [string]$BabyNasUser = "truenas_admin",
    [string]$MainNasUser = "root"
)

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "║          SSH Key Setup for TrueNAS Servers               ║" -ForegroundColor Cyan
Write-Host "║                                                          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$sshDir = "$env:USERPROFILE\.ssh"

###############################################################################
# Step 1: Create .ssh directory
###############################################################################
Write-Host "[1/7] Setting up SSH directory..." -ForegroundColor Cyan

if (-not (Test-Path $sshDir)) {
    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    Write-Host "      ✓ Created $sshDir" -ForegroundColor Green
} else {
    Write-Host "      ✓ Directory exists: $sshDir" -ForegroundColor Green
}

# Set proper permissions
$acl = Get-Acl $sshDir
$acl.SetAccessRuleProtection($true, $false)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $sshDir -AclObject $acl

Write-Host "      ✓ Permissions set" -ForegroundColor Green

###############################################################################
# Step 2: Generate SSH keys for Baby NAS
###############################################################################
Write-Host ""
Write-Host "[2/7] Generating SSH key for Baby NAS..." -ForegroundColor Cyan

$babyNasKeyPath = "$sshDir\id_babynas"

if (Test-Path $babyNasKeyPath) {
    Write-Host "      • Key already exists: $babyNasKeyPath" -ForegroundColor Gray
    $recreate = Read-Host "      Recreate? (yes/no)"

    if ($recreate -eq "yes") {
        Remove-Item "$babyNasKeyPath*" -Force
        Write-Host "      • Old key deleted" -ForegroundColor Gray
    } else {
        Write-Host "      ✓ Using existing key" -ForegroundColor Green
        $skipBabyGeneration = $true
    }
}

if (-not $skipBabyGeneration) {
    ssh-keygen -t ed25519 -f $babyNasKeyPath -N '""' -C "windows@baby-nas" -q

    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✓ SSH key generated (Ed25519)" -ForegroundColor Green
        Write-Host "      Private: $babyNasKeyPath" -ForegroundColor Gray
        Write-Host "      Public:  ${babyNasKeyPath}.pub" -ForegroundColor Gray
    } else {
        Write-Host "      ✗ Key generation failed" -ForegroundColor Red
        exit 1
    }
}

###############################################################################
# Step 3: Generate SSH keys for Main NAS
###############################################################################
Write-Host ""
Write-Host "[3/7] Generating SSH key for Main NAS..." -ForegroundColor Cyan

$mainNasKeyPath = "$sshDir\id_mainnas"

if (Test-Path $mainNasKeyPath) {
    Write-Host "      • Key already exists: $mainNasKeyPath" -ForegroundColor Gray
    $recreate = Read-Host "      Recreate? (yes/no)"

    if ($recreate -eq "yes") {
        Remove-Item "$mainNasKeyPath*" -Force
        Write-Host "      • Old key deleted" -ForegroundColor Gray
    } else {
        Write-Host "      ✓ Using existing key" -ForegroundColor Green
        $skipMainGeneration = $true
    }
}

if (-not $skipMainGeneration) {
    ssh-keygen -t ed25519 -f $mainNasKeyPath -N '""' -C "windows@main-nas" -q

    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✓ SSH key generated (Ed25519)" -ForegroundColor Green
        Write-Host "      Private: $mainNasKeyPath" -ForegroundColor Gray
        Write-Host "      Public:  ${mainNasKeyPath}.pub" -ForegroundColor Gray
    } else {
        Write-Host "      ✗ Key generation failed" -ForegroundColor Red
        exit 1
    }
}

###############################################################################
# Step 4: Deploy key to Baby NAS
###############################################################################
Write-Host ""
Write-Host "[4/7] Deploying key to Baby NAS ($BabyNasIP)..." -ForegroundColor Cyan

# Test connectivity first
if (-not (Test-Connection -ComputerName $BabyNasIP -Count 2 -Quiet)) {
    Write-Host "      ✗ Cannot reach Baby NAS at $BabyNasIP" -ForegroundColor Red
    Write-Host "      Skipping Baby NAS key deployment" -ForegroundColor Yellow
} else {
    # Read public key
    $babyPubKey = Get-Content "${babyNasKeyPath}.pub"

    # Copy key to Baby NAS
    Write-Host "      • Copying public key..." -ForegroundColor Gray

    $sshCommand = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$babyPubKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'Key added successfully'
"@

    $result = echo "y" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BabyNasUser}@${BabyNasIP}" "$sshCommand" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✓ Public key deployed to Baby NAS" -ForegroundColor Green

        # Test key authentication
        Write-Host "      • Testing key authentication..." -ForegroundColor Gray
        $testResult = ssh -i $babyNasKeyPath -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${BabyNasUser}@${BabyNasIP}" "echo 'SSH key auth works'" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✓ SSH key authentication successful!" -ForegroundColor Green
        } else {
            Write-Host "      ⚠ Key deployed but authentication test failed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "      ✗ Failed to deploy key" -ForegroundColor Red
        Write-Host "      Error: $result" -ForegroundColor Red
    }
}

###############################################################################
# Step 5: Deploy key to Main NAS
###############################################################################
Write-Host ""
Write-Host "[5/7] Deploying key to Main NAS ($MainNasIP)..." -ForegroundColor Cyan

# Test connectivity first
if (-not (Test-Connection -ComputerName $MainNasIP -Count 2 -Quiet)) {
    Write-Host "      ✗ Cannot reach Main NAS at $MainNasIP" -ForegroundColor Red
    Write-Host "      Skipping Main NAS key deployment" -ForegroundColor Yellow
    Write-Host "      (Main NAS may be offline - will configure replication later)" -ForegroundColor Yellow
} else {
    # Read public key
    $mainPubKey = Get-Content "${mainNasKeyPath}.pub"

    # Copy key to Main NAS
    Write-Host "      • Copying public key..." -ForegroundColor Gray

    $sshCommand = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$mainPubKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo 'Key added successfully'
"@

    $result = echo "y" | ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${MainNasUser}@${MainNasIP}" "$sshCommand" 2>&1

    if ($LASTEXITCODE -eq 0) {
        Write-Host "      ✓ Public key deployed to Main NAS" -ForegroundColor Green

        # Test key authentication
        Write-Host "      • Testing key authentication..." -ForegroundColor Gray
        $testResult = ssh -i $mainNasKeyPath -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${MainNasUser}@${MainNasIP}" "echo 'SSH key auth works'" 2>&1

        if ($LASTEXITCODE -eq 0) {
            Write-Host "      ✓ SSH key authentication successful!" -ForegroundColor Green
        } else {
            Write-Host "      ⚠ Key deployed but authentication test failed" -ForegroundColor Yellow
        }
    } else {
        Write-Host "      ✗ Failed to deploy key" -ForegroundColor Red
        Write-Host "      Error: $result" -ForegroundColor Red
    }
}

###############################################################################
# Step 6: Create SSH config file
###############################################################################
Write-Host ""
Write-Host "[6/7] Creating SSH config file..." -ForegroundColor Cyan

$sshConfigPath = "$sshDir\config"

# Create or append to config
$configContent = @"

# Baby NAS (Local Hyper-V VM)
Host babynas baby baby.isn.biz
    HostName $BabyNasIP
    User $BabyNasUser
    IdentityFile $babyNasKeyPath
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3

# Main NAS (Remote Server)
Host mainnas main true.isn.biz
    HostName $MainNasIP
    User $MainNasUser
    IdentityFile $mainNasKeyPath
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    ServerAliveInterval 60
    ServerAliveCountMax 3
"@

if (Test-Path $sshConfigPath) {
    # Check if config already has these entries
    $existingConfig = Get-Content $sshConfigPath -Raw

    if ($existingConfig -match "Host babynas") {
        Write-Host "      • SSH config already contains Baby NAS entry" -ForegroundColor Gray
        $overwrite = Read-Host "      Overwrite? (yes/no)"

        if ($overwrite -eq "yes") {
            Add-Content -Path $sshConfigPath -Value $configContent
            Write-Host "      ✓ SSH config updated" -ForegroundColor Green
        } else {
            Write-Host "      ✓ Using existing config" -ForegroundColor Green
        }
    } else {
        Add-Content -Path $sshConfigPath -Value $configContent
        Write-Host "      ✓ SSH config updated" -ForegroundColor Green
    }
} else {
    Set-Content -Path $sshConfigPath -Value $configContent.TrimStart()
    Write-Host "      ✓ SSH config created" -ForegroundColor Green
}

###############################################################################
# Step 7: Test connections
###############################################################################
Write-Host ""
Write-Host "[7/7] Testing SSH connections..." -ForegroundColor Cyan

# Test Baby NAS
Write-Host "      • Testing Baby NAS (ssh babynas)..." -ForegroundColor Gray
$babyTest = ssh babynas "hostname && echo 'Connection successful'" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "      ✓ Baby NAS: $babyTest" -ForegroundColor Green
} else {
    Write-Host "      ✗ Baby NAS connection failed" -ForegroundColor Red
}

# Test Main NAS
Write-Host "      • Testing Main NAS (ssh mainnas)..." -ForegroundColor Gray
$mainTest = ssh mainnas "hostname && echo 'Connection successful'" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "      ✓ Main NAS: $mainTest" -ForegroundColor Green
} else {
    Write-Host "      ⚠ Main NAS connection failed (may be offline)" -ForegroundColor Yellow
}

###############################################################################
# COMPLETION
###############################################################################
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                          ║" -ForegroundColor Green
Write-Host "║          SSH Key Setup Complete!                         ║" -ForegroundColor Green
Write-Host "║                                                          ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "SSH Keys Generated:" -ForegroundColor Cyan
Write-Host "  • Baby NAS: $babyNasKeyPath" -ForegroundColor White
Write-Host "  • Main NAS: $mainNasKeyPath" -ForegroundColor White
Write-Host ""

Write-Host "SSH Config Created:" -ForegroundColor Cyan
Write-Host "  • Config file: $sshConfigPath" -ForegroundColor White
Write-Host ""

Write-Host "Quick Access Commands:" -ForegroundColor Cyan
Write-Host "  • ssh babynas        # Connect to Baby NAS" -ForegroundColor White
Write-Host "  • ssh baby           # Alias for Baby NAS" -ForegroundColor White
Write-Host "  • ssh mainnas        # Connect to Main NAS" -ForegroundColor White
Write-Host "  • ssh main           # Alias for Main NAS" -ForegroundColor White
Write-Host ""

Write-Host "Test Commands:" -ForegroundColor Cyan
Write-Host "  ssh babynas 'zpool status tank'" -ForegroundColor White
Write-Host "  ssh babynas 'zfs list -r tank'" -ForegroundColor White
Write-Host "  ssh mainnas 'zpool list'" -ForegroundColor White
Write-Host ""

Write-Host "PowerShell Aliases (add to `$PROFILE):" -ForegroundColor Yellow
Write-Host @'
  function Connect-BabyNAS { ssh babynas }
  function Connect-MainNAS { ssh mainnas }
  function Get-BabyNASStatus { ssh babynas "zpool status tank && zfs list -r tank" }

  Set-Alias -Name bn -Value Connect-BabyNAS
  Set-Alias -Name mn -Value Connect-MainNAS
  Set-Alias -Name bnstat -Value Get-BabyNASStatus
'@ -ForegroundColor Gray
Write-Host ""
