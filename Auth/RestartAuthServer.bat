@echo off
setlocal

set AUTH_DIR=C:\streaming\auth
set AUTH_PORT=8081

echo Restarting Auth Server...

for /f "tokens=5" %%a in ('netstat -ano ^| findstr :%AUTH_PORT% ^| findstr LISTENING') do (
    echo Killing process on port %AUTH_PORT%: %%a
    taskkill /PID %%a /T /F
)

timeout /t 1 >nul

start "Auth Server" cmd /c "cd /d %AUTH_DIR% && powershell -NoProfile -ExecutionPolicy Bypass -Command ""$env:STREAM_PASSWORD=[Environment]::GetEnvironmentVariable('STREAM_PASSWORD','Machine'); $env:STREAM_SECRET=[Environment]::GetEnvironmentVariable('STREAM_SECRET','Machine'); py auth_server.py"""

echo Auth Server restarted.

endlocal