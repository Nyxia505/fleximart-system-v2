# Writes Gmail App Password to local secrets + Firestore app_config/emailjs
# Usage: .\scripts\setup_gmail_smtp.ps1 "abcd efgh ijkl mnop"
param(
  [Parameter(Mandatory = $true, Position = 0)]
  [string]$AppPassword,

  [string]$SmtpUser = "queenyvonnedalahay@gmail.com",
  [string]$ProjectId = "fleximart-system"
)

$ErrorActionPreference = "Stop"
$pass = $AppPassword -replace '\s', ''

if ($pass.Length -lt 16) {
  Write-Warning "Gmail App Passwords are usually 16 characters. You entered $($pass.Length)."
}

$secretsPath = Join-Path $PSScriptRoot "..\assets\config\emailjs.secrets.json"
$json = (@{
  smtpUser = $SmtpUser
  smtpPass = $pass
} | ConvertTo-Json -Compress)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText((Resolve-Path $secretsPath).Path, $json, $utf8NoBom)
Write-Host "✅ Wrote $secretsPath"

$env:GMAIL_APP_PASSWORD = $pass
$env:FIREBASE_PROJECT_ID = $ProjectId
Push-Location (Join-Path $PSScriptRoot "..")
try {
  node scripts/seed_firestore_email_config.js
  Write-Host "✅ Firestore app_config/emailjs updated"
  Write-Host ""
  Write-Host "Next steps:"
  Write-Host "  1. firebase deploy --only functions"
  Write-Host "  2. flutter run -d chrome   (or restart your app)"
} finally {
  Pop-Location
}
