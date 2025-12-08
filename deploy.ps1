# Flutter Web Deployment Script for Firebase Hosting

Write-Host "🚀 Building Flutter web app..." -ForegroundColor Cyan
flutter build web --release

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Build successful!" -ForegroundColor Green
    Write-Host "📦 Deploying to Firebase Hosting..." -ForegroundColor Cyan
    firebase deploy --only hosting
} else {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}

