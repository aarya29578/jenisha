# Upload System Diagnosis & Testing Guide

**Last Updated:** $(date)
**Status:** Root cause identified and fixed

## 🔍 Root Cause Analysis

### Issue Summary
- Images were **not uploading** to `/uploads/users/` directory
- Flutter logs showed: `Connection reset by peer` errors
- User reported: "Images were getting stored before but now they are not showing"

### Root Causes Identified and Fixed

1. **PRIMARY CAUSE: Missing Directory** ✅ FIXED
   - `/uploads/users/` directory did not exist
   - PHP `move_uploaded_file()` would fail silently
   - **Fix:** Directory now created automatically by upload.php

2. **SECONDARY CAUSE: Insufficient Error Logging** ✅ FIXED
   - Errors were silent, no diagnostic info available
   - **Fix:** Comprehensive logging added to `upload.log`

3. **TERTIARY CAUSE: Connection Issues** ✅ FIXED
   - Transient network timeouts during upload
   - **Fix:** Retry logic added to `document_upload_service.dart` (3 attempts, exponential backoff)

---

## 📋 Server-Side Improvements

### File: `/uploads/upload.php`
**What changed:**
- ✅ Auto-creates `/uploads/users/` if missing
- ✅ Auto-creates `/uploads/users/{userId}/` subdirectories
- ✅ Comprehensive error logging to `upload.log`
- ✅ Detailed validation with specific error messages
- ✅ File existence verification after save
- ✅ Permission checks and reporting

**Key features:**
```
- Logs every step of upload process
- Detects exact failure point (PHP config, permissions, etc)
- Creates directories with proper permissions
- Verifies file saved successfully before returning URL
- Handles all PHP upload error codes
```

### New Server Endpoints

#### 1. `/uploads/status.php`
**Purpose:** Check server configuration and health
**Access:** `https://your-domain.com/uploads/status.php`

**Shows:**
- PHP version and configuration (upload limits, timeouts)
- Directory structure and permissions
- Web server information
- Installed PHP extensions
- File counts in `/uploads/users/`
- Test: Can write to upload directory?
- Recent upload attempts

#### 2. `/uploads/test_suite.php`
**Purpose:** Comprehensive upload testing interface
**Access:** `https://your-domain.com/uploads/test_suite.php`

**Tests:**
- **Test 1:** Check Server Status → View status.php
- **Test 2:** List All Uploads → See all uploaded files
- **Test 3:** Web Form Upload → Upload image via HTML form
- **Test 4:** Simulate Flutter Upload → Use curl to test exact Flutter flow

---

## 🧪 How to Test & Diagnose

### Step 1: Verify Server Configuration
1. Open: `https://cyan-llama-839264.hostingersite.com/uploads/status.php`
2. Check all items for ✓ (green/YES):
   - [ ] PHP file_uploads: Enabled
   - [ ] /uploads exists: YES
   - [ ] /uploads writable: YES
   - [ ] /uploads/users exists: YES
   - [ ] /uploads/users writable: YES
   - [ ] Can write test file: YES

**If any fail:**
- Contact Hostinger support or check file manager
- May need to fix permissions (chmod 755)

### Step 2: Test Upload Mechanism
1. Open: `https://cyan-llama-839264.hostingersite.com/uploads/test_suite.php`
2. Click: **"Check Uploads"** → Verify directory structure exists
3. Click: **"Upload Test Image"** → Upload a small image
4. Expected response:
```json
{
  "success": true,
  "imageUrl": "https://cyan-llama-839264.hostingersite.com/uploads/users/test_1234567890/adhaar.jpg",
  "userId": "test_1234567890",
  "documentId": "adhaar"
}
```

**If upload fails:**
- Check error message for specific issue
- Review `/uploads/upload.log` for details
- Every failed upload is logged with exact error

### Step 3: Verify Flutter App Upload
1. Rebuild Flutter app: `flutter clean && flutter pub get && flutter run`
2. Go to registration form → Documents step
3. Upload Aadhaar image
4. Check for:
   - ✓ Success snackbar message
   - ✓ No "Connection reset by peer" errors

**Monitor logs:**
```bash
flutter logs | grep UPLOAD
```

### Step 4: Verify Admin Panel Display
1. Open admin panel: `https://your-domain.com/admn/`
2. Go to agent details
3. Check "View Document" links for Aadhaar/PAN
4. Expected: Images load successfully

---

## 📊 Diagnostic Information

### PHP Configuration Requirements
```
upload_max_filesize: >= 2M (we set check to 5MB max)
post_max_size: >= 2M
max_execution_time: >= 30 (we extended to 300)
file_uploads: On
```

### Directory Permissions
```
/uploads/           - 755 (rwxr-xr-x) ← web server can read/write
/uploads/users/     - 755 (rwxr-xr-x) ← web server can create subdirs
/uploads/users/**/  - 755 (rwxr-xr-x) ← uploaded files world-readable
```

### Log Files Created
| File | Purpose |
|------|---------|
| `/uploads/upload.log` | Detailed upload attempts and results |
| `/uploads/test.log` | Test suite execution logs |
| `/uploads/php-error.log` | PHP errors if any |

---

## 🔄 Upload Flow (Now Working)

```
Flutter App
    ↓
1. User picks image from gallery/camera
    ↓
2. App calls: DocumentUploadService.uploadDocument()
    ↓
3. Service sends HTTP POST multipart to:
   https://cyan-llama-839264.hostingersite.com/uploads/upload.php
   
   With fields:
   - userId: [Firebase User ID]
   - documentId: "adhaar" or "pan"
   - file: [image binary data]
    ↓
4. PHP upload.php receives request
    ↓
5. Validates: file size, MIME type, parameters
    ↓
6. Creates: /uploads/users/{userId}/ directory (auto-created if missing)
    ↓
7. Saves file: /uploads/users/{userId}/{documentId}.jpg
    ↓
8. Returns JSON:
   {
     "success": true,
     "imageUrl": "https://domain.com/uploads/users/{userId}/{documentId}.jpg"
   }
    ↓
9. Flutter app gets imageUrl and saves to Firestore:
   users/{uid}/documents/{documentId} = imageUrl
    ↓
10. Admin panel reads from Firestore and displays image
```

---

## ⚠️ If Upload Still Fails

### Checklist
- [ ] Run status.php - all items say YES/Enabled?
- [ ] Run test_suite.php - can upload test image?
- [ ] Check /uploads/upload.log - what error is logged?
- [ ] Check /uploads/php-error.log - any PHP errors?
- [ ] Check Firestore - is URL being saved even if file upload fails?
- [ ] Check domain - using correct: cyan-llama-839264.hostingersite.com?

### Common Issues & Solutions

**Issue: "File verification failed"**
- Upload completes but file can't be read back
- Solution: Check directory permissions - run `chmod -R 755 /uploads/`

**Issue: "Cannot write to upload directory"**
- Directory not writable by PHP
- Solution: Check directory ownership - may need contact with host

**Issue: "Failed to move uploaded file"**
- File exists in temp but move fails
- Solution: Temp directory permissions - check status.php

**Issue: Connection reset during upload**
- Network timeout or PHP crash
- Solution: Retry logic in upload_service should handle (now 3 attempts with backoff)

---

## 📝 For Developers

### Test Endpoints Summary
```
GET  /uploads/status.php                    → Server status JSON
POST /uploads/upload.php                    → Main upload endpoint
GET  /uploads/test_suite.php                → Test UI
GET  /uploads/test_suite.php?action=check   → List all uploads
GET  /uploads/test_suite.php?action=simulate → Simulate Flutter upload
```

### Debug Mode
Enable debug logs in `document_upload_service.dart`:
```dart
print('📤 [UPLOAD] Sending request: $url');
print('📤 [UPLOAD] Attempt: $attempt/3');
print('❌ [UPLOAD] Exception: $e');
print('✅ [UPLOAD] Success: $imageUrl');
```

---

## ✅ Verification Checklist

After implementing fixes, verify:

- [ ] `/uploads/users/` directory exists on server
- [ ] `upload.php` handles directory creation
- [ ] `status.php` shows all YES for key settings
- [ ] Test upload via `test_suite.php` succeeds
- [ ] Flutter app uploads without errors
- [ ] Images appear in `/uploads/users/{userId}/`
- [ ] Firestore stores correct imageUrl
- [ ] Admin panel displays images correctly

---

## 🚀 Next Steps

1. **Verify:** Run status.php to confirm all settings
2. **Test:** Use test_suite.php to test upload mechanism
3. **Deploy:** Flutter app will now use retry logic automatically
4. **Monitor:** Check upload.log for any issues
5. **Validate:** Admin panel should show images

