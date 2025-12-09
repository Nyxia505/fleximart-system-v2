#!/bin/bash

# Firebase Storage CORS Configuration Script
# This script applies CORS settings to your Firebase Storage bucket

echo "=========================================="
echo "Firebase Storage CORS Configuration"
echo "=========================================="
echo ""

# Check if gsutil is installed
if ! command -v gsutil &> /dev/null; then
    echo "❌ Error: gsutil is not installed."
    echo "Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if cors.json exists
if [ ! -f "cors.json" ]; then
    echo "❌ Error: cors.json file not found in current directory"
    exit 1
fi

# Prompt for bucket name
echo "Enter your Firebase Storage bucket name:"
echo "(e.g., your-project-id.appspot.com)"
read -p "Bucket name: " BUCKET_NAME

if [ -z "$BUCKET_NAME" ]; then
    echo "❌ Error: Bucket name cannot be empty"
    exit 1
fi

# Verify bucket exists
echo ""
echo "Verifying bucket exists..."
if ! gsutil ls -b gs://$BUCKET_NAME &> /dev/null; then
    echo "❌ Error: Bucket 'gs://$BUCKET_NAME' not found or not accessible"
    echo "Please check:"
    echo "  1. The bucket name is correct"
    echo "  2. You're authenticated: gcloud auth login"
    echo "  3. You have permissions to access the bucket"
    exit 1
fi

echo "✅ Bucket found: gs://$BUCKET_NAME"
echo ""

# Show current CORS configuration
echo "Current CORS configuration:"
gsutil cors get gs://$BUCKET_NAME
echo ""

# Confirm before applying
read -p "Apply new CORS configuration? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# Apply CORS configuration
echo ""
echo "Applying CORS configuration..."
if gsutil cors set cors.json gs://$BUCKET_NAME; then
    echo ""
    echo "✅ CORS configuration applied successfully!"
    echo ""
    echo "New CORS configuration:"
    gsutil cors get gs://$BUCKET_NAME
    echo ""
    echo "Note: Changes may take 1-2 minutes to propagate."
    echo "Clear your browser cache if images still don't load."
else
    echo ""
    echo "❌ Error: Failed to apply CORS configuration"
    exit 1
fi

