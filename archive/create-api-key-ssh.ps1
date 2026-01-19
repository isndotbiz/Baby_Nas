# Create TrueNAS API Key via SSH
# This script connects to BabyNAS via SSH and creates an API key programmatically
# NEW: Automatically updates .env file with generated API key

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$SshUser = "root",
    [string]$SshKey = "$env:USERPROFILE\.ssh\id_ed25519",
    [string]$SshKey2 = "$env:USERPROFILE\.ssh\id_babynas",
    [string]$ApiKeyName = "Baby-Nas-Automation",
    [string]$EnvFile = "D:\workspace\Baby_Nas\.env",
    [switch]$AutoUpdate = $true
)

Write-Host "=== TrueNAS API Key Generation via SSH ===" -ForegroundColor Cyan
Write-Host ""

# Check if SSH key exists, try alternate if not
if (-not (Test-Path $SshKey)) {
    if (Test-Path $SshKey2) {
        $SshKey = $SshKey2
        Write-Host "Using alternate SSH key: $SshKey2" -ForegroundColor Gray
    }
}

# Test SSH connectivity first
Write-Host "1. Testing SSH connectivity to $BabyNasIP..." -ForegroundColor Yellow
$sshTest = & ssh -i $SshKey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
    $SshUser@$BabyNasIP "echo 'SSH connection successful'" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ SSH connection successful" -ForegroundColor Green
} else {
    Write-Host "   ✗ SSH connection failed" -ForegroundColor Red
    Write-Host "   Error: $sshTest" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "2. Creating API key '$ApiKeyName'..." -ForegroundColor Yellow

# Use TrueNAS API to create an API key
# This connects via SSH and uses sqlite3 to create the key directly
$sshCommand = @"
python3 << 'EOF'
import sqlite3
import secrets
import os
from datetime import datetime

# Connect to TrueNAS database
db_path = '/data/freenas-v1.db'
conn = sqlite3.connect(db_path)
cursor = conn.cursor()

# Generate a secure token
api_key = secrets.token_hex(32)

# Get current user ID (usually 1 for root)
cursor.execute('SELECT id FROM account_user WHERE username = ?', ('root',))
user_id = cursor.fetchone()[0]

# Insert API key
try:
    cursor.execute('''
        INSERT INTO account_apikey (name, key, user_id, created_at)
        VALUES (?, ?, ?, ?)
    ''', ('$ApiKeyName', api_key, user_id, datetime.utcnow()))

    conn.commit()
    print(f"API Key created successfully!")
    print(f"API Key: {api_key}")
except Exception as e:
    print(f"Error creating API key: {e}")
finally:
    conn.close()
EOF
"@

# Execute the command via SSH
$apiKey = & ssh -i $SshKey -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null `
    $SshUser@$BabyNasIP $sshCommand 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✓ API key created" -ForegroundColor Green
    Write-Host ""
    Write-Host "Generated API Key:" -ForegroundColor Cyan
    Write-Host $apiKey -ForegroundColor Yellow
    Write-Host ""

    # Extract the actual API key value from output
    $apiKeyValue = ($apiKey | Where-Object { $_ -match "^[a-f0-9]{64}$" }) -split '\s' | Where-Object { $_ -match "^[a-f0-9]{64}$" } | Select-Object -First 1

    if (-not $apiKeyValue) {
        # Try to extract from the output
        $apiKeyValue = [regex]::Match($apiKey, '[a-f0-9]{64}').Value
    }

    # Auto-update .env file if enabled
    if ($AutoUpdate -and $apiKeyValue -and (Test-Path $EnvFile)) {
        Write-Host "4. Updating .env file..." -ForegroundColor Yellow

        try {
            $envContent = Get-Content $EnvFile -Raw

            # Check if API key already exists
            if ($envContent -like "*TRUENAS_API_KEY=*") {
                $envContent = $envContent -replace 'TRUENAS_API_KEY=.*', "TRUENAS_API_KEY=$apiKeyValue"
            } else {
                # Add it after the comment
                $envContent = $envContent -replace '(# Generate API key.*\n)', "`$1TRUENAS_API_KEY=$apiKeyValue`n"
            }

            Set-Content $EnvFile -Value $envContent -Encoding UTF8
            Write-Host "   ✓ .env file updated with API key!" -ForegroundColor Green
            Write-Host "   File: $EnvFile" -ForegroundColor Gray
        } catch {
            Write-Host "   ⚠ Could not auto-update .env file" -ForegroundColor Yellow
            Write-Host "   Manual update required:" -ForegroundColor Yellow
            Write-Host "   Edit .env and set: TRUENAS_API_KEY=$apiKeyValue" -ForegroundColor Gray
        }
    } else {
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Copy the API key above"
        Write-Host "2. Edit .env file: $EnvFile"
        Write-Host "3. Set: TRUENAS_API_KEY=$apiKeyValue"
        Write-Host "4. Save the file"
    }

    Write-Host ""
    Write-Host "Verify the key in TrueNAS Web UI:" -ForegroundColor Yellow
    Write-Host "  https://172.21.203.18/ui/system/api-keys" -ForegroundColor Gray
    Write-Host "  Should show: '$ApiKeyName'" -ForegroundColor Gray

} else {
    Write-Host "   ✗ Failed to create API key" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative method (Manual via Web UI):" -ForegroundColor Yellow
    Write-Host "   1. Open https://172.21.203.18/ui"
    Write-Host "   2. Login with root credentials"
    Write-Host "   3. Go to System → API Keys → Add"
    Write-Host "   4. Give it a name: 'Baby-Nas-Automation'"
    Write-Host "   5. Copy the generated key"
    Write-Host "   6. Run this script with the key:"
    Write-Host "      Manual: Edit .env and set TRUENAS_API_KEY=<your-key>"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "   • Ensure BabyNAS is running and accessible"
    Write-Host "   • Run diagnose-baby-nas.ps1 to check connectivity"
    Write-Host "   • Verify SSH keys are properly set up"
}
