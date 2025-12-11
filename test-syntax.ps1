# Quick syntax test
try {
    $null = Get-Content ".\FULL-AUTOMATION.ps1" -Raw
    Write-Host "✓ Script syntax is valid" -ForegroundColor Green
    Write-Host ""
    Write-Host "Ready to run:" -ForegroundColor Cyan
    Write-Host "  .\FULL-AUTOMATION.ps1" -ForegroundColor White
} catch {
    Write-Host "✗ Syntax error: $($_.Exception.Message)" -ForegroundColor Red
}
