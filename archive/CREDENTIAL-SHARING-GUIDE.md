# Credential Sharing Guide for Claude Code

This guide explains how to securely share BabyNAS and infrastructure credentials across different Claude Code instances using Vaultwarden.

## Overview

Instead of passing credentials directly between Claude Code instances, credentials are stored securely in **Vaultwarden** (vault.isn.biz) and accessed via OAuth 2.0 API keys.

### Credential Flow

```
Claude Code Instance 1
    ↓
    Uses .env.local (VAULTWARDEN_CLIENT_ID + CLIENT_SECRET)
    ↓
Vaultwarden at vault.isn.biz
    ↓
    Returns: BabyNAS-SMB, BabyNAS-API, BabyNAS-SSH, etc.
    ↓
Claude Code Instance 2
    (Same .env.local, same access)
```

## Setup Instructions

### 1. OAuth 2.0 Client Credentials

Two organizations are configured in Vaultwarden:

#### BABY_NAS Organization
```
CLIENT_ID:     organization.1a4d4b38-c293-4d05-aad1-f9a037483338
CLIENT_SECRET: lG1GNsHXEmYMnwo58eD0ahGMItdtoh
FINGERPRINT:   unzip-backless-barge-move-exclusive
```

#### TRUE_NAS Organization
```
CLIENT_ID:     organization.97735504-4e6e-44bb-8220-5d0178b18ebd
CLIENT_SECRET: hGjosmX51I6diO7xvjKSM7sCY8Bq1M
FINGERPRINT:   morse-cozily-studied-vivacious-jubilant
```

### 2. Add to .env.local Files

Both `D:\workspace\Baby_Nas\.env.local` and `D:\workspace\True_Nas\.env.local` already contain:

```bash
VAULTWARDEN_URL=https://vault.isn.biz
VAULTWARDEN_CLIENT_ID=organization.1a4d4b38-c293-4d05-aad1-f9a037483338
VAULTWARDEN_CLIENT_SECRET=lG1GNsHXEmYMnwo58eD0ahGMItdtoh
VAULTWARDEN_GRANT_TYPE=client_credentials
VAULTWARDEN_SCOPE=api.organization
VAULTWARDEN_FINGERPRINT=unzip-backless-barge-move-exclusive
```

### 3. Create Vault Entries

Run the setup script to populate Vaultwarden with BabyNAS credentials:

```powershell
.\setup-vaultwarden-credentials.ps1
```

This creates the following vault entries:
- **BabyNAS-SMB** - SMB share credentials (IP, shares, username)
- **BabyNAS-API** - TrueNAS REST API credentials
- **BabyNAS-SSH** - SSH authentication (jdmal user with Ed25519 key)
- **ZFS-Replication** - Replication source/target credentials
- **StoragePool-Config** - ZFS pool configuration details

## Retrieving Credentials

### Using Python Script

```bash
# Get BabyNAS SMB credentials
python vaultwarden-credential-manager.py get "BabyNAS-SMB"

# Output:
# {
#   "id": "...",
#   "name": "BabyNAS-SMB",
#   "credentials": {
#     "ip": "192.168.215.2",
#     "hostname": "baby.isn.biz",
#     "protocol": "smb",
#     "shares": ["backups", "veeam", "wsl-backups", "phone", "media"],
#     "username": "jdmal"
#   }
# }
```

### Using PowerShell

```powershell
# List all credentials
python vaultwarden-credential-manager.py list

# Test Vaultwarden connection
python vaultwarden-credential-manager.py test

# Create new credential entry
python vaultwarden-credential-manager.py create "MyCredentials"
```

## Sharing with Other Claude Code Instances

### Method 1: Share .env.local Variables

Pass these environment variables to other Claude Code instances:

```bash
export VAULTWARDEN_URL=https://vault.isn.biz
export VAULTWARDEN_CLIENT_ID=organization.1a4d4b38-c293-4d05-aad1-f9a037483338
export VAULTWARDEN_CLIENT_SECRET=lG1GNsHXEmYMnwo58eD0ahGMItdtoh
export VAULTWARDEN_GRANT_TYPE=client_credentials
export VAULTWARDEN_SCOPE=api.organization
```

### Method 2: Copy .env.local Between Repositories

```bash
# Copy BabyNAS .env.local to another project
cp D:\workspace\Baby_Nas\.env.local D:\workspace\OtherProject\.env.local

# Update VAULTWARDEN_CLIENT_ID if using TRUE_NAS org:
# VAULTWARDEN_CLIENT_ID=organization.97735504-4e6e-44bb-8220-5d0178b18ebd
# VAULTWARDEN_CLIENT_SECRET=hGjosmX51I6diO7xvjKSM7sCY8Bq1M
```

### Method 3: Create a Shared Secrets File

Create a file to distribute (never commit to git):

```bash
# File: VAULTWARDEN_CREDENTIALS.txt
VAULTWARDEN_URL=https://vault.isn.biz
VAULTWARDEN_CLIENT_ID=organization.1a4d4b38-c293-4d05-aad1-f9a037483338
VAULTWARDEN_CLIENT_SECRET=lG1GNsHXEmYMnwo58eD0ahGMItdtoh

# Loading in Claude Code:
source VAULTWARDEN_CREDENTIALS.txt
python vaultwarden-credential-manager.py get "BabyNAS-SMB"
```

## 1Password CLI Integration

### Install 1Password CLI

```bash
# Windows (using choco or winget)
winget install 1password-cli

# macOS
brew install 1password-cli

# Linux
curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
  sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
```

### Setup

```bash
# Authenticate with 1Password
op signin

# List vaults
op vault list

# List items in BabyNAS vault
op item list --vault "BabyNAS"
```

### Create Items in 1Password

```bash
# BabyNAS SMB Credentials
op item create \
  --vault "BabyNAS" \
  --category "server" \
  --title "BabyNAS-SMB" \
  hostname="baby.isn.biz" \
  ip="192.168.215.2" \
  username="jdmal"

# Retrieve
op item get "BabyNAS-SMB" --vault "BabyNAS"
```

## Environment Variable Precedence

Credentials are resolved in this order:

1. **Vaultwarden API** (recommended) - Fetch from vault.isn.biz via OAuth
2. **.env.local file** - Local environment variables (fallback)
3. **1Password CLI** - `op item get <name>` (if installed)
4. **Hardcoded** (NOT RECOMMENDED) - Last resort only

## Best Practices

### DO ✓
- Store all credentials in Vaultwarden
- Use OAuth 2.0 Client Credentials for API access
- Rotate API keys quarterly
- Keep .env.local in .gitignore
- Use different org IDs for different projects
- Log credential access attempts
- Test credential retrieval before using in automation

### DON'T ✗
- Commit .env.local to git
- Share CLIENT_SECRET directly in messages
- Hardcode credentials in scripts
- Log full credential values
- Reuse same credentials across projects
- Leave credentials in chat history
- Share CLIENT_ID + CLIENT_SECRET in plaintext

## Troubleshooting

### Can't authenticate with Vaultwarden

```bash
# Test connection
python vaultwarden-credential-manager.py test

# Check .env.local variables
echo $VAULTWARDEN_URL
echo $VAULTWARDEN_CLIENT_ID

# Verify vault.isn.biz is accessible
ping vault.isn.biz
curl -s https://vault.isn.biz/health
```

### Credential entry not found

```bash
# List all available entries
python vaultwarden-credential-manager.py list

# Check spelling of entry name (case-sensitive)
python vaultwarden-credential-manager.py get "BabyNAS-SMB"  # ✓ Correct
python vaultwarden-credential-manager.py get "babynas-smb"  # ✗ Wrong
```

### SSL/TLS certificate errors

```bash
# Trust self-signed certificates (development only)
export PYTHONHTTPSVERIFY=0

# Or update Python's certificate bundle
pip install certifi --upgrade
```

## Credential Inventory

### Current Vault Entries

| Entry Name | Type | Content | Updated |
|---|---|---|---|
| BabyNAS-SMB | Credentials | IP, shares, username | 2026-01-02 |
| BabyNAS-API | API Key | TrueNAS REST API endpoint + key | 2026-01-02 |
| BabyNAS-SSH | SSH Key | jdmal user + Ed25519 key path | 2026-01-02 |
| ZFS-Replication | SSH Key | Source/target hosts, replication user | 2026-01-02 |
| StoragePool-Config | Config | Pool topology, compression, recordsize | 2026-01-02 |

## API Examples

### Retrieve BabyNAS IP and SMB Shares

```python
from vaultwarden_credential_manager import VaultwardenCredentialManager

mgr = VaultwardenCredentialManager()
entry = mgr.get_credential_entry("BabyNAS-SMB")

ip = entry['credentials']['ip']
shares = entry['credentials']['shares']
print(f"BabyNAS at {ip} with shares: {shares}")
```

### Map SMB Share Using Vault Credentials

```powershell
# Retrieve from Vaultwarden
$creds = python vaultwarden-credential-manager.py get "BabyNAS-SMB" | ConvertFrom-Json
$ip = $creds.credentials.ip
$username = $creds.credentials.username

# Map drive
net use Z: "\\$ip\backups" /user:$username /persistent:yes
```

### Connect SSH Using Vault Credentials

```bash
# Retrieve from Vaultwarden
SSH_CONFIG=$(python vaultwarden-credential-manager.py get "BabyNAS-SSH")
SSH_USER=$(echo $SSH_CONFIG | jq -r '.credentials.ssh_user')
SSH_HOST=$(echo $SSH_CONFIG | jq -r '.credentials.ip')
SSH_KEY=$(echo $SSH_CONFIG | jq -r '.credentials.ssh_key_path')

# Connect
ssh -i $SSH_KEY $SSH_USER@$SSH_HOST
```

## Updating Credentials

When credentials change, update them in Vaultwarden:

```bash
# Get the entry ID
python vaultwarden-credential-manager.py list | grep "BabyNAS-SMB"

# Update the entry with new credentials
# (Use the vaultwarden-credential-manager.py script)
```

## Revoking Access

To revoke access to vault credentials:

1. Generate new CLIENT_SECRET in Vaultwarden
2. Update .env.local in all affected repositories
3. Update environment variables in all Claude Code instances
4. Rotate API keys for any compromised credentials

## References

- **Vaultwarden Admin**: https://vault.isn.biz/admin
- **Python Script**: `vaultwarden-credential-manager.py`
- **Setup Script**: `setup-vaultwarden-credentials.ps1`
- **OAuth 2.0 Spec**: [RFC 6749](https://tools.ietf.org/html/rfc6749)
