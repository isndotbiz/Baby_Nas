# Map Baby NAS Network Drives
# Run as Administrator

Write-Host "=== Baby NAS Network Drive Mapping ===" -ForegroundColor Cyan
Write-Host ""

# Force remove all existing mappings
Write-Host "Removing all existing drive mappings..." -ForegroundColor Yellow
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.DisplayRoot -like "\\10.0.0.88\*" } | ForEach-Object {
    Write-Host "  Removing $($_.Name):"
    Remove-PSDrive -Name $_.Name -Force -ErrorAction SilentlyContinue
}

# Also use net use to clear
@('B:', 'M:', 'S:', 'W:') | ForEach-Object {
    net use $_ /delete /y 2>$null
}

Write-Host ""
Write-Host "Clearing cached credentials..." -ForegroundColor Yellow
cmdkey /delete:10.0.0.88 2>$null
net use \\10.0.0.88\IPC$ /delete /y 2>$null

Write-Host ""
Write-Host "Restarting workstation service..." -ForegroundColor Yellow
Restart-Service -Name LanmanWorkstation -Force
Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Mapping drives to Baby NAS..." -ForegroundColor Yellow

$credentials = @{
    User = "smbuser"
    Pass = "SmbPass2024!"
}

$drives = @(
    @{Letter="W:"; Share="\\10.0.0.88\workspace"; Name="Workspace"}
    @{Letter="M:"; Share="\\10.0.0.88\models"; Name="Models"}
    @{Letter="S:"; Share="\\10.0.0.88\staging"; Name="Staging"}
    @{Letter="B:"; Share="\\10.0.0.88\backups"; Name="Backups"}
)

foreach ($drive in $drives) {
    Write-Host "  Mapping $($drive.Letter) -> $($drive.Name)..." -NoNewline
    $result = net use $drive.Letter $drive.Share /user:$credentials.User $credentials.Pass /persistent:yes 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host " OK" -ForegroundColor Green
    } else {
        Write-Host " FAILED" -ForegroundColor Red
        Write-Host "    Error: $result" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== Current Drive Mappings ===" -ForegroundColor Cyan
net use | Select-String "10.0.0.88"

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
