# ADB Connection Fix Script
# This script restarts ADB and checks device connectivity

$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"

Write-Host "=== ADB Connection Fix Script ===" -ForegroundColor Cyan
Write-Host ""

# Check if ADB exists
if (-not (Test-Path $adbPath)) {
    Write-Host "ERROR: ADB not found at $adbPath" -ForegroundColor Red
    Write-Host "Please check your Android SDK installation." -ForegroundColor Yellow
    exit 1
}

Write-Host "[1/5] Checking current device status..." -ForegroundColor Yellow
& $adbPath devices
Write-Host ""

Write-Host "[2/5] Killing ADB server..." -ForegroundColor Yellow
& $adbPath kill-server
Start-Sleep -Seconds 2
Write-Host "✓ ADB server killed" -ForegroundColor Green
Write-Host ""

Write-Host "[3/5] Starting ADB server..." -ForegroundColor Yellow
& $adbPath start-server
Start-Sleep -Seconds 2
Write-Host "✓ ADB server started" -ForegroundColor Green
Write-Host ""

Write-Host "[4/5] Checking devices after restart..." -ForegroundColor Yellow
$devices = & $adbPath devices
Write-Host $devices
Write-Host ""

# Check if any device is offline
if ($devices -match "offline") {
    Write-Host "[5/5] Attempting to reconnect offline devices..." -ForegroundColor Yellow
    & $adbPath reconnect
    Start-Sleep -Seconds 3
    
    Write-Host ""
    Write-Host "Final device status:" -ForegroundColor Cyan
    & $adbPath devices
    Write-Host ""
    
    Write-Host "⚠ Device still offline. Please check your device:" -ForegroundColor Yellow
    Write-Host "  1. Unlock your device" -ForegroundColor White
    Write-Host "  2. Look for 'Allow USB debugging?' popup and tap Allow" -ForegroundColor White
    Write-Host "  3. Or go to Settings → Developer options → Toggle USB debugging OFF/ON" -ForegroundColor White
    Write-Host "  4. Try disconnecting and reconnecting the USB cable" -ForegroundColor White
} else {
    Write-Host "[5/5] Checking Flutter device status..." -ForegroundColor Yellow
    flutter devices
    Write-Host ""
    Write-Host "✓ ADB connection check complete!" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Script Complete ===" -ForegroundColor Cyan

