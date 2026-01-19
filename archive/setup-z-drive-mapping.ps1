# Setup Z: Drive Mapping to BabyNAS Dataset
# This script mounts a TrueNAS dataset as a network drive letter Z:

param(
    [string]$BabyNasIP = "172.21.203.18",
    [string]$BabyNasHostname = "babynas.isndotbiz.com",
    [string]$DatasetShareName = "backups",  # Name of the SMB share on BabyNAS
    [string]$Username = "root",
    [string]$Password = "",  # Will prompt if not provided
    [switch]$Persistent = $true
)

Write-Host "=== Z: Drive Mapping Setup ===" -ForegroundColor Cyan
Write-Host ""

# Get password if not provided
if (-not $Password) {
    Write-Host "Enter BabyNAS root password:" -ForegroundColor Yellow
    $SecurePassword = Read-Host -AsSecureString
    $Password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecurePassword))
}

Write-Host ""
Write-Host "1. Checking if Z: drive is already mapped..." -ForegroundColor Yellow
$existingDrive = Get-PSDrive -Name Z -ErrorAction SilentlyContinue
if ($existingDrive) {
    Write-Host "   Z: drive already exists. Removing..." -ForegroundColor Yellow
    Remove-PSDrive -Name Z -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-Host "2. Creating Z: drive mapping..." -ForegroundColor Yellow
$uncPath = "\\$BabyNasIP\$DatasetShareName"
Write-Host "   UNC Path: $uncPath" -ForegroundColor Gray

try {
    # Create credentials object
    $credential = New-Object System.Management.Automation.PSCredential (
        $Username,
        (ConvertTo-SecureString $Password -AsPlainText -Force)
    )

    # Map the network drive
    $newDrive = New-PSDrive -Name Z -PSProvider FileSystem -Root $uncPath `
        -Credential $credential -Scope Global -ErrorAction Stop

    Write-Host "   ✓ Z: drive mapped successfully" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Failed to map Z: drive" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "3. Making mapping persistent (adding to registry)..." -ForegroundColor Yellow

# Make the mapping persistent across reboots
if ($Persistent) {
    try {
        # Create WScript.Network COM object for persistent mapping
        $network = New-Object -ComObject WScript.Network
        $network.MapNetworkDrive("Z:", $uncPath, $false, $Username, $Password)
        Write-Host "   ✓ Persistent mapping created" -ForegroundColor Green
    } catch {
        Write-Host "   ⚠ Could not create persistent mapping (non-admin?)" -ForegroundColor Yellow
        Write-Host "   But Z: drive is currently mapped for this session" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "4. Testing Z: drive access..." -ForegroundColor Yellow
try {
    $testPath = "Z:\"
    $dirListing = Get-ChildItem -Path $testPath -ErrorAction Stop
    Write-Host "   ✓ Z: drive is accessible" -ForegroundColor Green
    Write-Host "   Listing:" -ForegroundColor Gray
    $dirListing | Select-Object Name, @{N="Type";E={if($_.PSIsContainer){"Folder"}else{"File"}}} |
        Format-Table -AutoSize | Out-String | ForEach-Object {Write-Host $_}
} catch {
    Write-Host "   ✗ Cannot access Z: drive" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "✓ Z: drive mapping is ready"
Write-Host "  Path: $uncPath"
Write-Host "  Access it from Windows Explorer or command line as Z:\"
Write-Host ""
Write-Host "To remove this mapping later:" -ForegroundColor Gray
Write-Host "  Remove-PSDrive -Name Z -Force" -ForegroundColor Gray
Write-Host "  Or: net use Z: /delete" -ForegroundColor Gray
