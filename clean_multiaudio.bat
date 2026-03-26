@echo off
setlocal

:loop
echo Starting ffmpeg cleanup for MultiAudio...
ffmpeg -rtsp_transport tcp -i rtsp://127.0.0.1:8554/MultiAudio -map 0:v:0 -map 0:a:0 -c:v libx264 -preset veryfast -tune zerolatency -pix_fmt yuv420p -bf 0 -g 48 -keyint_min 48 -sc_threshold 0 -r 24 -c:a aac -ar 48000 -ac 2 -b:a 128k -f rtsp -rtsp_transport tcp rtsp://127.0.0.1:8554/MultiAudio_clean

echo ffmpeg exited. Restarting in 2 seconds...
timeout /t 2 /nobreak >nul
goto loop