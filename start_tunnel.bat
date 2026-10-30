@echo off
setlocal
title WasteWise HTTPS Tunnel

cd /d "%~dp0"

echo =======================================================================
echo    WASTEWISE - HTTPS Tunnel (for iPhone / off-laptop access)
echo =======================================================================
echo.
echo Run run_app.bat FIRST and leave it open - this needs the server
echo already running on http://localhost:3000.
echo.

if not exist "tools\cloudflared.exe" (
    echo [*] tools\cloudflared.exe not found - downloading it once ^(~65 MB^)...
    mkdir tools >nul 2>nul
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile 'tools\cloudflared.exe'"
    if not exist "tools\cloudflared.exe" (
        echo [ERROR] Download failed. Check your internet connection and try again.
        pause
        exit /b 1
    )
)

echo [*] Starting tunnel... look for a line below containing:
echo       https://something.trycloudflare.com
echo     That is your link. Open it in Safari on your iPhone and use
echo     "Add to Home Screen". It changes every time you run this script.
echo.
echo Keep this window open while using the app away from this laptop.
echo To stop the tunnel, press Ctrl+C or close this window.
echo =======================================================================
echo.

:: --protocol http2 avoids QUIC (UDP), which some mobile hotspots/carriers block
:: or throttle after the initial connection ("no recent network activity" errors).
tools\cloudflared.exe tunnel --protocol http2 --url http://localhost:3000
pause
