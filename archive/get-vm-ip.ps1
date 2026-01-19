#Requires -RunAsAdministrator

$OutputFile = "D:\workspace\True_Nas\windows-scripts\vm-ip-output.txt"

"=== VM IP Addresses ===" | Out-File -FilePath $OutputFile

$vm = Get-VM -Name 'TrueNAS-BabyNAS'
$netAdapter = Get-VMNetworkAdapter -VMName 'TrueNAS-BabyNAS'

if ($netAdapter.IPAddresses) {
    $netAdapter.IPAddresses | Out-File -FilePath $OutputFile -Append
} else {
    "No IP addresses detected" | Out-File -FilePath $OutputFile -Append
}

Write-Host "IP addresses saved to: $OutputFile"
