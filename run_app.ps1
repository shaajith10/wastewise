# WasteWise Runner
$ErrorActionPreference = "SilentlyContinue"
$Host.UI.RawUI.WindowTitle = "WasteWise Server (Port 3000)"

$rootDir = $PSScriptRoot
$backendDir = Join-Path $rootDir "backend"

Clear-Host
Write-Host "=======================================================================" -ForegroundColor Green
Write-Host "   WASTEWISE - Community Waste Management and Recycling Platform" -ForegroundColor Green
Write-Host "=======================================================================" -ForegroundColor Green
Write-Host ""

# Free port 3000 if occupied
$conn = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if ($conn) {
    $pids = $conn | Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($p in $pids) { Stop-Process -Id $p -Force -ErrorAction SilentlyContinue }
}

Write-Host "[*] Opening WasteWise in your browser (http://localhost:3000)..." -ForegroundColor Cyan
Start-Process "http://localhost:3000"

Write-Host "`n=======================================================================" -ForegroundColor Green
Write-Host "   SERVER IS RUNNING ON http://localhost:3000" -ForegroundColor Green
Write-Host "=======================================================================" -ForegroundColor Green
Write-Host "`nDemo Accounts:" -ForegroundColor Yellow
Write-Host "  [1] Citizen:   citizen@waste.dev   /  citizen123" -ForegroundColor White
Write-Host "  [2] Collector: collector@waste.dev /  collector123" -ForegroundColor White
Write-Host "  [3] Admin:     admin@waste.dev     /  admin123" -ForegroundColor White
Write-Host "`nKeep this window open while using the application." -ForegroundColor Gray
Write-Host "To stop the server, press Ctrl+C or close this window.`n" -ForegroundColor Gray

Push-Location $backendDir
node src/server.js
Pop-Location
