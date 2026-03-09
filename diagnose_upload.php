<?php
// Turn on error display for debugging
error_reporting(E_ALL);
ini_set('display_errors', '1');
ini_set('log_errors', '1');

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS, GET');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

$diagnostics = [];

// 1. Check PHP version
$diagnostics['php_version'] = phpversion();

// 2. Check if directory exists and is writable
$uploadDir = __DIR__ . '/banners/';
$diagnostics['upload_dir_path'] = $uploadDir;
$diagnostics['upload_dir_exists'] = is_dir($uploadDir);
$diagnostics['upload_dir_writable'] = is_writable($uploadDir);

// Try to create directory if it doesn't exist
if (!is_dir($uploadDir)) {
    $diagnostics['mkdir_attempt'] = mkdir($uploadDir, 0755, true);
    $diagnostics['mkdir_error'] = error_get_last();
}

// 3. Check file upload settings
$diagnostics['upload_max_filesize'] = ini_get('upload_max_filesize');
$diagnostics['post_max_size'] = ini_get('post_max_size');
$diagnostics['max_file_uploads'] = ini_get('max_file_uploads');

// 4. Check request method
$diagnostics['request_method'] = $_SERVER['REQUEST_METHOD'];

// 5. Check if file was uploaded
$diagnostics['files_count'] = count($_FILES);
$diagnostics['files_keys'] = array_keys($_FILES);

if (!empty($_FILES['banner'])) {
    $file = $_FILES['banner'];
    $diagnostics['file_info'] = [
        'name' => $file['name'],
        'type' => $file['type'],
        'size' => $file['size'],
        'error' => $file['error'],
        'error_message' => $file['error'] === 0 ? 'No error' : 'Error code ' . $file['error'],
        'tmp_name' => $file['tmp_name'],
        'tmp_exists' => file_exists($file['tmp_name'])
    ];
    
    // Try to get real file type
    if (function_exists('mime_content_type') && file_exists($file['tmp_name'])) {
        $diagnostics['file_info']['detected_mime'] = mime_content_type($file['tmp_name']);
    }
    
    // Try to move file
    if ($file['error'] === 0 && is_dir($uploadDir) && is_writable($uploadDir)) {
        $testFilename = 'test_' . time() . '.jpg';
        $testPath = $uploadDir . $testFilename;
        $moveResult = move_uploaded_file($file['tmp_name'], $testPath);
        $diagnostics['move_uploaded_file_result'] = $moveResult;
        
        if ($moveResult) {
            $diagnostics['file_saved'] = true;
            $diagnostics['file_path'] = $testPath;
            $diagnostics['file_exists_after_move'] = file_exists($testPath);
            
            // Get URL
            $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
            $host = $_SERVER['HTTP_HOST'];
            $diagnostics['image_url'] = $protocol . $host . '/uploads/banners/' . $testFilename;
        } else {
            $diagnostics['file_saved'] = false;
            $diagnostics['move_error'] = error_get_last();
        }
    }
}

// 6. Check server info
$diagnostics['server_software'] = $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown';
$diagnostics['document_root'] = $_SERVER['DOCUMENT_ROOT'] ?? 'Unknown';

echo json_encode([
    'success' => true,
    'message' => 'Diagnostic complete',
    'diagnostics' => $diagnostics
], JSON_PRETTY_PRINT);
