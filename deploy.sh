#!/bin/bash
# Flutter Web Deployment Script for Firebase Hosting

echo "🚀 Building Flutter web app..."
flutter build web --release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📦 Deploying to Firebase Hosting..."
    firebase deploy --only hosting
else
    echo "❌ Build failed!"
    exit 1
fi

