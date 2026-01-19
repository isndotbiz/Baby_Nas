# 1Password CLI Setup Guide

1Password is a much more robust solution for credential management and sharing across Claude Code instances.

## Installation

### Windows

**Using WinGet (Recommended)**:
```powershell
winget install AgileBits.1Password.CLI
```

**Using Chocolatey**:
```powershell
choco install 1password-cli
```

**Manual Download**:
```powershell
# Download from https://app-updates.agilebits.com/product_history/CLI2
# Extract and add to PATH
```

### Verify Installation

```bash
op --version
op --help
```

## Setup and Authentication

### 1. Sign In to 1Password

```bash
op signin
```

You'll be prompted for:
- **Email**: Your 1Password account email
- **Password**: Your 1Password master password
- **Secret Key**: Found in your 1Password account settings

### 2. Create/List Vaults

**List available vaults**:
```bash
op vault list
```

**Create a vault for BabyNAS** (if not exists):
```bash
op vault create \
  --name "BabyNAS" \
  --description "BabyNAS backup infrastructure credentials"
```

## Create Credential Items

### 1. BabyNAS-SMB

```bash
op item create \
  --vault "BabyNAS" \
  --category "server" \
  --title "BabyNAS-SMB" \
  --generate-password=off \
  ipv4_address="192.168.215.2" \
  hostname="baby.isn.biz" \
  username="jdmal" \
  "custom_field[Protocol]"="SMB" \
  "custom_field[Shares]"="backups, veeam, wsl-backups, phone, media"
```

### 2. BabyNAS-API

```bash
op item create \
  --vault "BabyNAS" \
  --category "server" \
  --title "BabyNAS-API" \
  ipv4_address="192.168.215.2" \
  hostname="baby.isn.biz" \
  "custom_field[API URL]"="http://192.168.215.2/api/v2.0" \
  "custom_field[API Key]"="1-VkZdCiOTla5o0cs2lDBocRiTS14RIGDPchTiSVg2Hflt1AcmBzYzJiBuJLkOTI9A" \
  "custom_field[Root Password]"="74108520"
```

### 3. BabyNAS-SSH

```bash
op item create \
  --vault "BabyNAS" \
  --category "server" \
  --title "BabyNAS-SSH" \
  ipv4_address="192.168.215.2" \
  hostname="baby.isn.biz" \
  username="jdmal" \
  "custom_field[SSH Port]"="22" \
  "custom_field[SSH Key Path]"="~/.ssh/id_ed25519"
```

### 4. ZFS-Replication

```bash
op item create \
  --vault "BabyNAS" \
  --category "server" \
  --title "ZFS-Replication" \
  hostname="baby.isn.biz" \
  username="baby-nas" \
  "custom_field[Source Host]"="192.168.215.2" \
  "custom_field[Target Host]"="10.0.0.89" \
  "custom_field[SSH Key Path]"="D:\workspace\Baby_Nas\keys\baby-nas-replication" \
  "custom_field[Datasets]"="tank/backups, tank/veeam, tank/wsl-backups, tank/media, tank/phone"
```

### 5. StoragePool-Config

```bash
op item create \
  --vault "BabyNAS" \
  --category "server" \
  --title "StoragePool-Config" \
  "custom_field[Pool Name]"="tank" \
  "custom_field[Pool Type]"="RAIDZ1" \
  "custom_field[Compression]"="LZ4" \
  "custom_field[Record Size]"="1M" \
  "custom_field[SLOG]"="250GB SSD" \
  "custom_field[L2ARC]"="256GB SSD"
```

## Retrieve Credentials

### Get Full Item

```bash
# Get BabyNAS-SMB item
op item get "BabyNAS-SMB" --vault "BabyNAS"

# Output includes all fields
```

### Get Specific Field

```bash
# Get just the IP address
op item get "BabyNAS-SMB" --vault "BabyNAS" --fields "ipv4_address"

# Get custom field
op item get "BabyNAS-SMB" --vault "BabyNAS" --fields "custom_field[Shares]"
```

### JSON Format (for scripts)

```bash
# Get as JSON
op item get "BabyNAS-SMB" --vault "BabyNAS" --format json | jq

# Extract specific fields
op item get "BabyNAS-SMB" --vault "BabyNAS" --format json | jq '.fields[] | select(.label=="ipv4_address") | .value'
```

## Use Credentials in Scripts

### PowerShell Example

```powershell
# Get BabyNAS IP
$ip = op item get "BabyNAS-SMB" --vault "BabyNAS" --fields "ipv4_address"

# Get all SMB fields as JSON
$smb = op item get "BabyNAS-SMB" --vault "BabyNAS" --format json | ConvertFrom-Json

# Map SMB share
net use Z: "\\$ip\backups" /user:jdmal /persistent:yes
```

### Python Example

```python
import subprocess
import json

def get_op_item(item_name, vault_name="BabyNAS"):
    """Get item from 1Password"""
    cmd = ["op", "item", "get", item_name, "--vault", vault_name, "--format", "json"]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(result.stdout)

# Retrieve BabyNAS-SMB
smb_item = get_op_item("BabyNAS-SMB")
ip = next(f['value'] for f in smb_item['fields'] if f['label'] == 'ipv4_address')
print(f"BabyNAS IP: {ip}")

# Retrieve BabyNAS-API
api_item = get_op_item("BabyNAS-API")
api_url = next(f['value'] for f in api_item['fields'] if 'API URL' in f['label'])
print(f"API URL: {api_url}")
```

### Bash Example

```bash
#!/bin/bash

# Get BabyNAS IP
BABYNAS_IP=$(op item get "BabyNAS-SMB" --vault "BabyNAS" --fields "ipv4_address")
echo "BabyNAS IP: $BABYNAS_IP"

# Get API key
API_KEY=$(op item get "BabyNAS-API" --vault "BabyNAS" --fields "custom_field[API Key]")
echo "API Key: ${API_KEY:0:10}..."

# SSH example
SSH_USER=$(op item get "BabyNAS-SSH" --vault "BabyNAS" --fields "username")
ssh -i ~/.ssh/id_ed25519 ${SSH_USER}@${BABYNAS_IP}
```

## Share with Others

### Method 1: Share Vault Access

In 1Password app:
1. Go to Vault settings
2. Click "Share" or "Invite people"
3. Enter email addresses
4. Grant appropriate permissions

They can then:
```bash
op signin
op item get "BabyNAS-SMB" --vault "BabyNAS"
```

### Method 2: Export Credentials (Secure)

**Export vault data** (handles carefully!):
```bash
# Export as JSON (SENSITIVE - handle with care)
op vault export "BabyNAS" --format json > babynas-credentials.json

# Encrypt before sharing
gpg --encrypt --recipient person@example.com babynas-credentials.json
```

**Import into 1Password**:
```bash
op vault import "BabyNAS" babynas-credentials.json
```

## Security Best Practices

### ✓ DO:
- Use 1Password for all credential storage
- Rotate API keys quarterly
- Enable biometric unlock in 1Password
- Use strong master password
- Enable two-factor authentication
- Share access via 1Password, not export

### ✗ DON'T:
- Commit credentials to git (even if encrypted)
- Export and email credentials
- Share master password via chat
- Store plaintext API keys in code
- Disable two-factor authentication
- Leave 1Password unlocked unattended

## Troubleshooting

### Authentication Issues

```bash
# Check session status
op whoami

# Re-authenticate
op signin --force

# Clear cached session
op signout
op signin
```

### Cannot Find Item

```bash
# List all items in vault
op item list --vault "BabyNAS"

# Check exact item name (case-sensitive)
op item get "BabyNAS-SMB" --vault "BabyNAS"  # Correct
op item get "babynas-smb" --vault "BabyNAS"  # Wrong!
```

### Vault Permissions

```bash
# Check your access
op vault list --format table

# Verify item access
op item get "BabyNAS-SMB" --vault "BabyNAS" --format json
```

## Update Item

```bash
# Update a field
op item edit "BabyNAS-API" \
  --vault "BabyNAS" \
  "custom_field[API Key]"="NEW-KEY-HERE"
```

## Delete Item (Careful!)

```bash
# Move to trash (can recover)
op item delete "BabyNAS-SMB" --vault "BabyNAS"

# Permanently delete (no recovery)
op item delete "BabyNAS-SMB" --vault "BabyNAS" --permanently
```

## Environment Variable Integration

### Set Credentials in Environment

```bash
#!/bin/bash

# Load BabyNAS-API credentials into environment
export BABYNAS_IP=$(op item get "BabyNAS-SMB" --vault "BabyNAS" --fields "ipv4_address")
export BABYNAS_API_KEY=$(op item get "BabyNAS-API" --vault "BabyNAS" --fields "custom_field[API Key]")
export BABYNAS_API_URL=$(op item get "BabyNAS-API" --vault "BabyNAS" --fields "custom_field[API URL]")

# Now use in script
echo "Connecting to ${BABYNAS_API_URL}"
curl -H "Authorization: Bearer ${BABYNAS_API_KEY}" "${BABYNAS_API_URL}/pool"
```

### Service Account Auth (for automation)

For CI/CD or automated systems:

```bash
# Generate service account token
op service account create \
  --vaults "BabyNAS" \
  "Claude Code Automation"

# Use in scripts
export OP_SERVICE_ACCOUNT_TOKEN="..."
op item get "BabyNAS-SMB" --vault "BabyNAS"
```

## Reference

- **1Password CLI Docs**: https://developer.1password.com/docs/cli
- **Item Types**: https://developer.1password.com/docs/cli/item-types
- **Field Reference**: https://developer.1password.com/docs/cli/reference
- **Examples**: https://github.com/1Password/op-demos
