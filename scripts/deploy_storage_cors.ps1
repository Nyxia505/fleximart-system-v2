# Apply CORS to Firebase Storage bucket (required for Flutter Web image loads).
# Requires Google Cloud SDK: https://cloud.google.com/sdk/docs/install
# Run from repo root: .\scripts\deploy_storage_cors.ps1

$ErrorActionPreference = "Stop"
$Bucket = "gs://fleximart-system.firebasestorage.app"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$CorsFile = Join-Path $Root "cors.json"

if (-not (Test-Path $CorsFile)) {
    Write-Error "Missing cors.json at $CorsFile"
}

$gsutil = Get-Command gsutil -ErrorAction SilentlyContinue
if (-not $gsutil) {
    Write-Host "gsutil not found. Install Google Cloud SDK, then run:"
    Write-Host "  gsutil cors set `"$CorsFile`" $Bucket"
    exit 1
}

Write-Host "Applying CORS to $Bucket ..."
& gsutil cors set $CorsFile $Bucket
Write-Host "Done. Verify with: gsutil cors get $Bucket"
