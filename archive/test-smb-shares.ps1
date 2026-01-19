Write-Host "=== Testing BabyNAS SMB Shares ===" -ForegroundColor Cyan
Write-Host ""

# Test connectivity
Write-Host "Testing SMB port 445..." -ForegroundColor Yellow
$portTest = Test-NetConnection -ComputerName 192.168.215.2 -Port 445
if ($portTest.TcpTestSucceeded) {
    Write-Host "✓ Port 445 is open" -ForegroundColor Green
} else {
    Write-Host "✗ Port 445 is closed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Listing available shares..." -ForegroundColor Yellow
net view \\192.168.215.2 2>&1

Write-Host ""
Write-Host "Testing share access..." -ForegroundColor Yellow

$shares = @("backups", "veeam", "wsl-backups", "phone", "media")

foreach ($share in $shares) {
    Write-Host ""
    Write-Host "Testing \\192.168.215.2\$share" -ForegroundColor Gray

    try {
        $items = @(Get-ChildItem "\\192.168.215.2\$share" -ErrorAction Stop)
        if ($items.Count -gt 0) {
            Write-Host "✓ Share accessible - $($items.Count) items" -ForegroundColor Green
        } else {
            Write-Host "✓ Share accessible - empty" -ForegroundColor Green
        }
    } catch {
        Write-Host "✗ Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Trying to map with credentials..." -ForegroundColor Yellow

        # Try to map drive
        $user = "jdmal"
        $pass = Read-Host "Enter password for jdmal"
        $cred = New-Object System.Management.Automation.PSCredential($user, (ConvertTo-SecureString $pass -AsPlainText -Force))

        try {
            New-PSDrive -Name "TestDrive" -PSProvider FileSystem -Root "\\192.168.215.2\$share" -Credential $cred -ErrorAction Stop | Out-Null
            Write-Host "✓ Mapped with credentials" -ForegroundColor Green
            Remove-PSDrive -Name "TestDrive" -Force | Out-Null
        } catch {
            Write-Host "✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "=== SMB Test Complete ===" -ForegroundColor Cyan
