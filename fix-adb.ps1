# ADB Connection Fix Script
# This script restarts ADB server and checks device connection status

$adbPath = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ADB Connection Fix Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
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
Write-Host "✓ ADB server stopped" -ForegroundColor Green
Write-Host ""

Write-Host "[3/5] Starting ADB server..." -ForegroundColor Yellow
& $adbPath start-server
Start-Sleep -Seconds 2
Write-Host "✓ ADB server started" -ForegroundColor Green
Write-Host ""

Write-Host "[4/5] Attempting to reconnect devices..." -ForegroundColor Yellow
& $adbPath reconnect
Start-Sleep -Seconds 2
Write-Host ""

Write-Host "[5/5] Final device status:" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan
$devices = & $adbPath devices
$devices | ForEach-Object {
    if ($_ -match "device$") {
        Write-Host $_ -ForegroundColor Green
    } elseif ($_ -match "offline") {
        Write-Host $_ -ForegroundColor Red
    } elseif ($_ -match "unauthorized") {
        Write-Host $_ -ForegroundColor Yellow
    } else {
        Write-Host $_
    }
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check Flutter devices
Write-Host "Checking Flutter device status..." -ForegroundColor Yellow
flutter devices
Write-Host ""

# Provide troubleshooting tips if device is offline
if ($devices -match "offline") {
    Write-Host "⚠ Device is still offline. Try these steps:" -ForegroundColor Yellow
    Write-Host "  1. Unlock your Android device" -ForegroundColor White
    Write-Host "  2. Look for 'Allow USB debugging?' popup and tap Allow" -ForegroundColor White
    Write-Host "  3. Go to Settings → Developer options → Toggle USB debugging OFF/ON" -ForegroundColor White
    Write-Host "  4. Disconnect and reconnect the USB cable" -ForegroundColor White
    Write-Host "  5. Try a different USB cable or USB port" -ForegroundColor White
    Write-Host ""
}

