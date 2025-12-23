@echo off
REM Run Baby NAS diagnostic as Administrator
powershell -Command "Start-Process powershell -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -NoProfile -File D:\workspace\Baby_Nas\diagnose-vm-simple.ps1' -WindowStyle Normal"
pause
