<?php
// Prevent any output before JSON response
error_reporting(0);
ini_set('display_errors', '0');
ob_start();

// FULL CORS Support - Must be at the very top
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS, GET');
header('Access-Control-Allow-Headers: Content-Type, Accept, Origin, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit(0);
}

// Only accept POST requests for actual uploads
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'error' => 'Only POST requests are allowed'
    ]);
    exit();
}

// Define banner upload directory
$bannerDir = __DIR__ . '/banners/';

// Create directory if it doesn't exist
if (!is_dir($bannerDir)) {
    if (!mkdir($bannerDir, 0755, true)) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Failed to create upload directory'
        ]);
        exit();
    }
}

// Check if file was uploaded
if (empty($_FILES) || !isset($_FILES['banner'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'No banner file provided. Expected key: banner'
    ]);
    exit();
}

$file = $_FILES['banner'];

// Check for upload errors
if ($file['error'] !== UPLOAD_ERR_OK) {
    $errorMessages = [
        UPLOAD_ERR_INI_SIZE => 'File exceeds server upload_max_filesize',
        UPLOAD_ERR_FORM_SIZE => 'File exceeds form MAX_FILE_SIZE',
        UPLOAD_ERR_PARTIAL => 'File was only partially uploaded',
        UPLOAD_ERR_NO_FILE => 'No file was uploaded',
        UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder',
        UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
        UPLOAD_ERR_EXTENSION => 'A PHP extension stopped the file upload'
    ];
    $errorMessage = $errorMessages[$file['error']] ?? 'Unknown upload error';
    
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => $errorMessage
    ]);
    exit();
}

// Validate file size (max 10MB for banners)
$maxFileSize = 10 * 1024 * 1024;
if ($file['size'] > $maxFileSize) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'File size exceeds 10MB limit'
    ]);
    exit();
}

// Validate file type
$mimeType = mime_content_type($file['tmp_name']);
$allowedMimes = ['image/jpeg', 'image/png', 'image/jpg', 'image/webp'];

if (!in_array($mimeType, $allowedMimes)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'Invalid file type. Only JPEG, PNG, and WebP images are allowed'
    ]);
    exit();
}

// Validate file extension
$fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($fileExtension, ['jpg', 'jpeg', 'png', 'webp'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'error' => 'Invalid file extension. Only .jpg, .jpeg, .png, and .webp are allowed'
    ]);
    exit();
}

// Generate unique filename with timestamp
$timestamp = time();
$fileName = 'banner_' . $timestamp . '.' . $fileExtension;
$filePath = $bannerDir . $fileName;

// Move uploaded file to banner directory
if (!move_uploaded_file($file['tmp_name'], $filePath)) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => 'Failed to save banner file'
    ]);
    exit();
}

// Set proper file permissions
chmod($filePath, 0644);

// Build full image URL
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' || $_SERVER['SERVER_PORT'] == 443) ? 'https://' : 'http://';
$domain = $_SERVER['HTTP_HOST'];
$imageUrl = $protocol . $domain . '/uploads/banners/' . $fileName;

// Return success response
ob_end_clean();
http_response_code(200);
$response = [
    'success' => true,
    'imageUrl' => $imageUrl,
    'fileName' => $fileName,
    'uploadedAt' => date('Y-m-d H:i:s'),
    'fileSize' => $file['size']
];
echo json_encode($response);
flush();
exit();
