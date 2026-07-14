@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Monitor\TailwindMonitor.ps1"

endlocal
