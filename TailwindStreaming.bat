@echo off
setlocal

set STREAM_ROOT=C:\streaming
set CADDY_DIR=%STREAM_ROOT%\caddy
set AUTH_DIR=%STREAM_ROOT%\auth
set MEDIAMTX_DIR=C:\Apps\MediaMTX

start /min "MediaMTX" cmd /k "cd /d %MEDIAMTX_DIR% && mediamtx.exe"
start /min "Caddy" cmd /k "cd /d %CADDY_DIR% && caddy run --config Caddyfile"

call "%AUTH_DIR%\RestartAuthServer.bat"

start /min "FFmpeg MultiAudio Clean" cmd /k "cd /d %STREAM_ROOT% && call clean_multiaudio.bat"

start "Tailwind Monitor" cmd /k "C:\Streaming\Monitor\StartMonitor.bat"

endlocal