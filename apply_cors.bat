@echo off
REM Firebase Storage CORS Configuration Script for Windows
REM This script applies CORS settings to your Firebase Storage bucket

echo ==========================================
echo Firebase Storage CORS Configuration
echo ==========================================
echo.

REM Check if gsutil is installed
where gsutil >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] gsutil is not installed.
    echo Please install Google Cloud SDK: https://cloud.google.com/sdk/docs/install
    pause
    exit /b 1
)

REM Check if cors.json exists
if not exist "cors.json" (
    echo [ERROR] cors.json file not found in current directory
    pause
    exit /b 1
)

REM Prompt for bucket name
echo Enter your Firebase Storage bucket name:
echo (e.g., your-project-id.appspot.com)
set /p BUCKET_NAME="Bucket name: "

if "%BUCKET_NAME%"=="" (
    echo [ERROR] Bucket name cannot be empty
    pause
    exit /b 1
)

REM Verify bucket exists
echo.
echo Verifying bucket exists...
gsutil ls -b gs://%BUCKET_NAME% >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Bucket 'gs://%BUCKET_NAME%' not found or not accessible
    echo Please check:
    echo   1. The bucket name is correct
    echo   2. You're authenticated: gcloud auth login
    echo   3. You have permissions to access the bucket
    pause
    exit /b 1
)

echo [OK] Bucket found: gs://%BUCKET_NAME%
echo.

REM Show current CORS configuration
echo Current CORS configuration:
gsutil cors get gs://%BUCKET_NAME%
echo.

REM Confirm before applying
set /p CONFIRM="Apply new CORS configuration? (y/n): "
if /i not "%CONFIRM%"=="y" (
    echo Cancelled.
    pause
    exit /b 0
)

REM Apply CORS configuration
echo.
echo Applying CORS configuration...
gsutil cors set cors.json gs://%BUCKET_NAME%
if %ERRORLEVEL% EQU 0 (
    echo.
    echo [OK] CORS configuration applied successfully!
    echo.
    echo New CORS configuration:
    gsutil cors get gs://%BUCKET_NAME%
    echo.
    echo Note: Changes may take 1-2 minutes to propagate.
    echo Clear your browser cache if images still don't load.
) else (
    echo.
    echo [ERROR] Failed to apply CORS configuration
    pause
    exit /b 1
)

pause

