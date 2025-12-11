#Requires -RunAsAdministrator

$OutputFile = "D:\workspace\True_Nas\windows-scripts\vm-status-output.txt"

"=== VM Status ===" | Out-File -FilePath $OutputFile
Get-VM -Name 'TrueNAS-BabyNAS' | Select-Object Name, State, Status, Uptime, CPUUsage, MemoryAssigned, MemoryStartup | Format-List | Out-File -FilePath $OutputFile -Append

"`n=== DVD Drive ===" | Out-File -FilePath $OutputFile -Append
Get-VMDvdDrive -VMName 'TrueNAS-BabyNAS' | Select-Object VMName, ControllerType, ControllerNumber, ControllerLocation, Path | Format-List | Out-File -FilePath $OutputFile -Append

"`n=== Hard Disks ===" | Out-File -FilePath $OutputFile -Append
Get-VMHardDiskDrive -VMName 'TrueNAS-BabyNAS' | Sort-Object ControllerLocation | ForEach-Object {
    $disk = $_
    $size = "Unknown"
    if ($disk.Path -match "\.vhdx?$") {
        $vhd = Get-VHD -Path $disk.Path -ErrorAction SilentlyContinue
        if ($vhd) {
            $size = "{0:N2} GB" -f ($vhd.Size / 1GB)
        }
    } else {
        $size = "Physical Disk"
    }

    "Disk: $($disk.ControllerType) $($disk.ControllerNumber):$($disk.ControllerLocation) - Size: $size" | Out-File -FilePath $OutputFile -Append
    "Path: $($disk.Path)" | Out-File -FilePath $OutputFile -Append
    "" | Out-File -FilePath $OutputFile -Append
}

"`n=== Boot Order ===" | Out-File -FilePath $OutputFile -Append
$firmware = Get-VMFirmware -VMName 'TrueNAS-BabyNAS'
"First boot device: $($firmware.BootOrder[0].BootType) - $($firmware.BootOrder[0].Device)" | Out-File -FilePath $OutputFile -Append

"`n=== Network Adapter ===" | Out-File -FilePath $OutputFile -Append
Get-VMNetworkAdapter -VMName 'TrueNAS-BabyNAS' | Select-Object VMName, SwitchName, MacAddressSpoofing, Status | Format-List | Out-File -FilePath $OutputFile -Append

Write-Host "Status saved to: $OutputFile"
