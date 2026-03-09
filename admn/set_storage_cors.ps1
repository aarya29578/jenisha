# PowerShell helper to apply CORS to the Firebase Storage bucket
# Requirements: gsutil (part of Google Cloud SDK) must be installed and authenticated
# Usage: Open PowerShell in this folder and run: .\set_storage_cors.ps1

$bucket = 'jenisha-46c62.appspot.com'
$corsFile = Join-Path $PSScriptRoot 'firebase_storage_cors.json'

if (-Not (Get-Command gsutil -ErrorAction SilentlyContinue)) {
  Write-Host "gsutil not found. Please install the Google Cloud SDK and ensure 'gsutil' is on PATH." -ForegroundColor Yellow
  exit 1
}

if (-Not (Test-Path $corsFile)) {
  Write-Host "CORS config file not found: $corsFile" -ForegroundColor Red
  exit 1
}

Write-Host "Applying CORS config to bucket: gs://$bucket" -ForegroundColor Cyan
& gsutil cors set $corsFile "gs://$bucket"

if ($LASTEXITCODE -eq 0) {
  Write-Host "CORS applied successfully." -ForegroundColor Green
} else {
  Write-Host "Failed to apply CORS. See gsutil output above." -ForegroundColor Red
}
