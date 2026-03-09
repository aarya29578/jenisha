# Quick Deployment Script for Cloud Functions

Write-Host "🚀 Firebase Cloud Functions Deployment" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseInstalled) {
    Write-Host "❌ Firebase CLI not found. Installing..." -ForegroundColor Red
    npm install -g firebase-tools
}

Write-Host "✅ Firebase CLI found" -ForegroundColor Green
Write-Host ""

# Navigate to admn directory
Set-Location -Path "d:\jenisha\admn"
Write-Host "📁 Current directory: $(Get-Location)" -ForegroundColor Cyan
Write-Host ""

# Check if firebase.json exists
if (-not (Test-Path "firebase.json")) {
    Write-Host "⚠️  firebase.json not found. Running firebase init..." -ForegroundColor Yellow
    Write-Host "Please select:" -ForegroundColor Yellow
    Write-Host "  - Functions: Configure Cloud Functions" -ForegroundColor Yellow
    Write-Host "  - Language: JavaScript" -ForegroundColor Yellow
    Write-Host "  - ESLint: No" -ForegroundColor Yellow
    Write-Host "  - Install dependencies: Yes" -ForegroundColor Yellow
    Write-Host ""
    firebase init
}

# Install function dependencies
Write-Host "📦 Installing function dependencies..." -ForegroundColor Cyan
Set-Location -Path "functions"
npm install
Set-Location -Path ".."
Write-Host "✅ Dependencies installed" -ForegroundColor Green
Write-Host ""

# Deploy functions
Write-Host "🚀 Deploying Cloud Functions..." -ForegroundColor Cyan
firebase deploy --only functions

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✅ Deployment Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Test admin creation at http://localhost:5175/admin-management" -ForegroundColor White
Write-Host "2. Verify Super Admin stays logged in" -ForegroundColor White
Write-Host "3. Check logs: firebase functions:log" -ForegroundColor White
Write-Host ""
