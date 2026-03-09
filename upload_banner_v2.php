<?php
// Strict error handling
error_reporting(E_ALL);
ini_set('display_errors', '0');
ini_set('log_errors', '1');

// JSON response only
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit(0);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'error' => 'Method not allowed']);
    exit();
}

try {
    // Check for file upload
    if (empty($_FILES['banner'])) {
        throw new Exception('No file uploaded. Expected field name: banner');
    }

    $file = $_FILES['banner'];

    // Check upload error
    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('Upload error code: ' . $file['error']);
    }

    // Validate size (10MB max)
    if ($file['size'] > 10485760) {
        throw new Exception('File too large. Max 10MB');
    }

    // Get extension
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, ['jpg', 'jpeg', 'png', 'webp', 'gif'])) {
        throw new Exception('Invalid file type. Allowed: jpg, png, webp, gif');
    }

    // Create upload directory
    $uploadDir = __DIR__ . '/banners/';
    if (!is_dir($uploadDir)) {
        if (!mkdir($uploadDir, 0755, true)) {
            throw new Exception('Cannot create upload directory');
        }
    }

    // Generate filename
    $filename = 'banner_' . time() . '_' . uniqid() . '.' . $ext;
    $filepath = $uploadDir . $filename;

    // Move uploaded file
    if (!move_uploaded_file($file['tmp_name'], $filepath)) {
        throw new Exception('Failed to move uploaded file');
    }

    // Set permissions
    @chmod($filepath, 0644);

    // Build URL
    $protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https://' : 'http://';
    $host = $_SERVER['HTTP_HOST'];
    $imageUrl = $protocol . $host . '/uploads/banners/' . $filename;

    // Success response
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'imageUrl' => $imageUrl,
        'fileName' => $filename,
        'fileSize' => $file['size']
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage()
    ]);
}
