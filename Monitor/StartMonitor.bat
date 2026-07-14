@echo off
setlocal
cd /d C:\Streaming\Monitor
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Streaming\Monitor\TailwindMonitor.ps1"
endlocal
