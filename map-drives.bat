@echo off
echo === Mapping Baby NAS Drives ===
echo.

net use W: \\10.0.0.88\workspace /user:smbuser SmbPass2024! /persistent:yes
net use M: \\10.0.0.88\models /user:smbuser SmbPass2024! /persistent:yes
net use S: \\10.0.0.88\staging /user:smbuser SmbPass2024! /persistent:yes
net use B: \\10.0.0.88\backups /user:smbuser SmbPass2024! /persistent:yes

echo.
echo === Current Drive Mappings ===
net use

pause
