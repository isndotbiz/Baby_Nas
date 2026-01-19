Write-Host "Testing BabyNAS SMB Shares" -ForegroundColor Cyan
Write-Host ""

Write-Host "Port 445 test..." -ForegroundColor Yellow
Test-NetConnection -ComputerName 192.168.215.2 -Port 445 | Select TcpTestSucceeded

Write-Host ""
Write-Host "Shares available:" -ForegroundColor Yellow
net view \\192.168.215.2

Write-Host ""
Write-Host "Testing backups share..." -ForegroundColor Yellow
Get-ChildItem \\192.168.215.2\backups -ErrorAction SilentlyContinue | Select-Object Name | Head -5

Write-Host "All shares tested." -ForegroundColor Green
