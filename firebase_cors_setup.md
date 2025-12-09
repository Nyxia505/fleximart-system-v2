# Firebase Storage CORS Configuration for Flutter Web

## Overview
This guide helps you configure CORS (Cross-Origin Resource Sharing) for Firebase Storage to allow Flutter Web applications to load images correctly.

## Prerequisites
1. **Google Cloud SDK (gcloud)** installed
2. **gsutil** command-line tool installed (comes with Google Cloud SDK)
3. **Firebase project** with Storage enabled
4. **Firebase Storage bucket name**

## Step 1: Find Your Firebase Storage Bucket Name

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to **Storage** section
4. Click on the **Files** tab
5. Look at the URL - it will be something like: `gs://your-project-id.appspot.com`
   - Your bucket name is: `your-project-id.appspot.com`

Alternatively, you can find it in your Firebase project settings or by running:
```bash
gcloud storage buckets list
```

## Step 2: Create the CORS Configuration File

The `cors.json` file has already been created in your project root with the following configuration:

```json
[
  {
    "origin": ["*"],
    "method": ["GET", "HEAD", "OPTIONS"],
    "responseHeader": [
      "Content-Type",
      "Content-Length",
      "Content-Range",
      "Accept-Ranges",
      "Cache-Control",
      "Expires",
      "Last-Modified",
      "ETag"
    ],
    "maxAgeSeconds": 3600
  }
]
```

This configuration:
- ✅ Allows **any origin** (`*`) - you can restrict this to specific domains later
- ✅ Allows **GET, HEAD, OPTIONS** methods (required for image loading)
- ✅ Allows necessary **response headers** for image caching and display
- ✅ Sets **maxAgeSeconds** to 3600 (1 hour) for CORS preflight caching

## Step 3: Apply CORS Configuration

### Option A: Using gsutil (Recommended)

1. **Authenticate with Google Cloud:**
   ```bash
   gcloud auth login
   ```

2. **Set your project:**
   ```bash
   gcloud config set project YOUR_PROJECT_ID
   ```
   Replace `YOUR_PROJECT_ID` with your Firebase project ID.

3. **Apply CORS configuration:**
   ```bash
   gsutil cors set cors.json gs://YOUR_BUCKET_NAME
   ```
   Replace `YOUR_BUCKET_NAME` with your Firebase Storage bucket name (e.g., `your-project-id.appspot.com`)

4. **Verify CORS configuration:**
   ```bash
   gsutil cors get gs://YOUR_BUCKET_NAME
   ```

### Option B: Using Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Navigate to **Cloud Storage** > **Buckets**
3. Click on your Firebase Storage bucket
4. Go to the **Configuration** tab
5. Scroll down to **CORS configuration**
6. Click **Edit CORS configuration**
7. Paste the contents of `cors.json` (without the outer array brackets if the UI requires it)
8. Click **Save**

## Step 4: Verify the Configuration

After applying CORS, verify it's working:

1. **Check CORS settings:**
   ```bash
   gsutil cors get gs://YOUR_BUCKET_NAME
   ```

2. **Test in browser:**
   - Open your Flutter Web app
   - Open browser DevTools (F12)
   - Go to Network tab
   - Try loading an image from Firebase Storage
   - Check that there are no CORS errors in the Console

## Troubleshooting

### If images still don't load:

1. **Clear browser cache** - CORS changes may be cached
2. **Check browser console** for specific CORS error messages
3. **Verify bucket name** is correct
4. **Wait a few minutes** - CORS changes can take a few minutes to propagate
5. **Check Firebase Storage rules** - Make sure your security rules allow read access:
   ```javascript
   match /{allPaths=**} {
     allow read: if true;  // Or your specific rules
   }
   ```

### Restrict to Specific Origins (Optional)

If you want to restrict CORS to specific domains instead of allowing all origins, modify `cors.json`:

```json
[
  {
    "origin": [
      "https://your-domain.com",
      "https://www.your-domain.com",
      "http://localhost:8080",
      "http://localhost:5000"
    ],
    "method": ["GET", "HEAD", "OPTIONS"],
    "responseHeader": [
      "Content-Type",
      "Content-Length",
      "Content-Range",
      "Accept-Ranges",
      "Cache-Control",
      "Expires",
      "Last-Modified",
      "ETag"
    ],
    "maxAgeSeconds": 3600
  }
]
```

## Quick Command Reference

```bash
# Set CORS
gsutil cors set cors.json gs://YOUR_BUCKET_NAME

# Get current CORS configuration
gsutil cors get gs://YOUR_BUCKET_NAME

# Remove CORS (if needed)
gsutil cors set [] gs://YOUR_BUCKET_NAME
```

## Notes

- CORS changes typically take effect within 1-2 minutes
- The `maxAgeSeconds: 3600` means browsers will cache CORS preflight responses for 1 hour
- Allowing `*` origin is convenient for development but consider restricting to specific domains in production
- The configuration allows all necessary headers for image loading and caching

