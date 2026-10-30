@echo off
setlocal
title WasteWise Server (Port 3000)

cd /d "%~dp0backend"

echo =======================================================================
echo    WASTEWISE - Community Waste Management and Recycling Platform
echo =======================================================================
echo.

:: 1. Check prerequisites
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not found in your system PATH.
    echo Please install Node.js v18 or higher from https://nodejs.org/
    pause
    exit /b 1
)

:: 2. Ensure dependencies
if not exist "node_modules\" (
    echo [*] Installing backend dependencies...
    call npm install
)

:: 3. Clear port 3000 if previously occupied
for /f "tokens=5" %%a in ('netstat -aon ^| findstr ":3000" ^| findstr "LISTENING"') do (
    taskkill /f /pid %%a >nul 2>nul
)

echo [*] Starting WasteWise Server on http://localhost:3000 ...
echo [*] The browser will open automatically once the server is ready.
echo.
echo =======================================================================
echo Demo Login Accounts:
echo   [1] Citizen:   citizen@waste.dev   /  citizen123
echo   [2] Collector: collector@waste.dev /  collector123
echo   [3] Admin:     admin@waste.dev     /  admin123
echo.
echo Keep this window open while using the application.
echo To stop the server, press Ctrl+C or close this window.
echo =======================================================================
echo.

node src/server.js
pause
