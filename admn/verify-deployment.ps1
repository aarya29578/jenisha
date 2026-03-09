# VERIFY CLOUD FUNCTION DEPLOYMENT

Write-Host "🔍 Verifying Cloud Function Deployment" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if Firebase CLI is installed
Write-Host "1️⃣ Checking Firebase CLI..." -ForegroundColor Yellow
$firebaseInstalled = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseInstalled) {
    Write-Host "❌ Firebase CLI not found" -ForegroundColor Red
    Write-Host "   Install: npm install -g firebase-tools" -ForegroundColor White
    exit 1
}
Write-Host "✅ Firebase CLI installed" -ForegroundColor Green
Write-Host ""

# Step 2: Check current project
Write-Host "2️⃣ Checking Firebase project..." -ForegroundColor Yellow
cd d:\jenisha\admn
$project = firebase use
Write-Host "   Project: $project" -ForegroundColor White
Write-Host ""

# Step 3: List deployed functions
Write-Host "3️⃣ Listing deployed functions..." -ForegroundColor Yellow
firebase functions:list
Write-Host ""

# Step 4: Check function logs
Write-Host "4️⃣ Recent function logs (last 10)..." -ForegroundColor Yellow
firebase functions:log --limit 10
Write-Host ""

# Step 5: Provide deployment command
Write-Host "🚀 TO DEPLOY FUNCTION:" -ForegroundColor Cyan
Write-Host "   cd d:\jenisha\admn" -ForegroundColor White
Write-Host "   firebase deploy --only functions" -ForegroundColor White
Write-Host ""

# Step 6: Provide test URL
Write-Host "🧪 TO TEST AFTER DEPLOYMENT:" -ForegroundColor Cyan
Write-Host "   Open: http://localhost:5175/admin-management" -ForegroundColor White
Write-Host "   Login as Super Admin" -ForegroundColor White
Write-Host "   Create a test admin" -ForegroundColor White
Write-Host ""

Write-Host "✅ Verification complete" -ForegroundColor Green
