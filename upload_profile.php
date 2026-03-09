<?php
/**
 * Profile Photo Upload Endpoint
 * Method: POST multipart/form-data
 * Fields: profile (image file), userId (string)
 * Returns: { success: true, imageUrl: "https://..." }
 */

set_time_limit(120);
ini_set('max_execution_time', 120);
error_reporting(E_ALL);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log');

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

function profileLog($msg) {
    $ts = date('Y-m-d H:i:s');
    $ip = $_SERVER['REMOTE_ADDR'] ?? '-';
    @file_put_contents(__DIR__ . '/upload.log', "[$ts][$ip][PROFILE] $msg\n", FILE_APPEND | LOCK_EX);
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['success' => false, 'error' => 'Method not allowed']));
}

try {
    profileLog('=== PROFILE UPLOAD REQUEST ===');

    $userId = trim($_POST['userId'] ?? '');
    if ($userId === '') throw new Exception('userId is required');
    $userId = preg_replace('/[^a-zA-Z0-9_\-]/', '', $userId);
    if ($userId === '') throw new Exception('Invalid userId');

    profileLog("userId=$userId");

    if (!isset($_FILES['profile'])) {
        throw new Exception('No file uploaded (field name must be "profile")');
    }

    $file = $_FILES['profile'];

    $phpErrors = [
        UPLOAD_ERR_INI_SIZE   => 'File exceeds server upload_max_filesize (' . ini_get('upload_max_filesize') . ')',
        UPLOAD_ERR_FORM_SIZE  => 'File exceeds MAX_FILE_SIZE',
        UPLOAD_ERR_PARTIAL    => 'File only partially uploaded',
        UPLOAD_ERR_NO_FILE    => 'No file uploaded',
        UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder',
        UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
        UPLOAD_ERR_EXTENSION  => 'PHP extension rejected upload',
    ];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('Upload error: ' . ($phpErrors[$file['error']] ?? 'Code ' . $file['error']));
    }
    if ($file['size'] === 0) throw new Exception('Uploaded file is empty (0 bytes)');
    if ($file['size'] > 5 * 1024 * 1024) throw new Exception('File too large: ' . round($file['size'] / 1048576, 2) . ' MB (max 5 MB)');

    // Detect MIME from actual bytes
    $allowed = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];
    $extMap  = ['image/jpeg' => 'jpg', 'image/jpg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp'];
    $imageInfo = @getimagesize($file['tmp_name']);
    $mime = $imageInfo ? $imageInfo['mime'] : (function_exists('mime_content_type') ? mime_content_type($file['tmp_name']) : $file['type']);
    if (!in_array($mime, $allowed, true)) {
        throw new Exception("Rejected MIME type: $mime. Only JPG, PNG, WEBP allowed.");
    }
    $ext = $extMap[$mime] ?? 'jpg';
    profileLog("MIME=$mime ext=$ext size={$file['size']}");

    // Save to /uploads/profiles/ — flat dir, no uid subdir
    $uploadDir = __DIR__ . '/profiles/';
    if (!is_dir($uploadDir)) {
        if (!@mkdir($uploadDir, 0755, true)) {
            profileLog("WARNING: mkdir failed for $uploadDir — falling back to __DIR__");
            $uploadDir = __DIR__ . '/';
        } else {
            profileLog("Created directory: $uploadDir");
        }
    }
    if (!is_writable($uploadDir)) {
        throw new Exception("Upload directory not writable: $uploadDir");
    }

    $filename = 'profile_' . $userId . '.' . $ext;
    $destPath = $uploadDir . $filename;
    profileLog("Moving to: $destPath");

    if (!move_uploaded_file($file['tmp_name'], $destPath)) {
        throw new Exception('move_uploaded_file() failed. dest=' . $destPath);
    }
    @chmod($destPath, 0644);
    if (!file_exists($destPath)) throw new Exception('File missing after move — filesystem error');

    $savedSize = filesize($destPath);
    profileLog("Saved OK size=$savedSize");

    $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host   = $_SERVER['HTTP_HOST'];
    $publicPath = (strpos($destPath, '/profiles/') !== false)
        ? "/uploads/profiles/$filename"
        : "/uploads/$filename";
    $imageUrl = "$scheme://$host$publicPath";
    profileLog("SUCCESS imageUrl=$imageUrl");

    echo json_encode(['success' => true, 'imageUrl' => $imageUrl, 'filename' => $filename]);

} catch (Exception $e) {
    profileLog('FAILED: ' . $e->getMessage());
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>
