# Test SMB connectivity to Baby NAS
$nasIP = "10.0.0.88"
$share = "workspace"
$uncPath = "\\$nasIP\$share"

Write-Host "Testing SMB connection to: $uncPath"

# Test if path exists
if (Test-Path $uncPath) {
    Write-Host "SUCCESS: Share accessible"
    Get-ChildItem $uncPath | Select-Object Name, LastWriteTime
} else {
    Write-Host "FAILED: Cannot access $uncPath"
    Write-Host ""
    Write-Host "Attempting with credentials..."

    try {
        $cred = New-Object System.Management.Automation.PSCredential("smbuser", (ConvertTo-SecureString "SmbPass2024!" -AsPlainText -Force))
        New-PSDrive -Name "TestNAS" -PSProvider FileSystem -Root $uncPath -Credential $cred -ErrorAction Stop
        Write-Host "SUCCESS: Mapped with credentials"
        Get-ChildItem TestNAS:\ | Select-Object Name, LastWriteTime
        Remove-PSDrive -Name "TestNAS"
    } catch {
        Write-Host "FAILED: $($_.Exception.Message)"
    }
}
