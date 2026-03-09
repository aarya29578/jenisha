<?php
// CORS Headers - MUST be at the very top before any output
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS, GET');
header('Access-Control-Allow-Headers: Content-Type, Accept');
header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-cache, no-store, must-revalidate');
header('Pragma: no-cache');
header('Expires: 0');

// Disable output buffering for faster response
ob_end_clean();

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Only POST requests are allowed'
    ]);
    exit();
}

$uploadDir = __DIR__ . '/uploads/banners/';

if (!is_dir($uploadDir)) {
    if (!mkdir($uploadDir, 0755, true)) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'message' => 'Could not create upload directory'
        ]);
        exit();
    }
}

if (empty($_FILES) || !isset($_FILES['banner'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'No file provided - expected key: banner'
    ]);
    exit();
}

$file = $_FILES['banner'];

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
    $errorMessage = isset($errorMessages[$file['error']]) ? $errorMessages[$file['error']] : 'Unknown upload error';
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $errorMessage
    ]);
    exit();
}

$maxFileSize = 10 * 1024 * 1024; // 10MB limit for banners

if ($file['size'] > $maxFileSize) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'File size exceeds 10MB limit'
    ]);
    exit();
}

$mimeType = mime_content_type($file['tmp_name']);
$allowedMimes = ['image/jpeg', 'image/png', 'image/jpg'];

if (!in_array($mimeType, $allowedMimes)) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid file type. Only JPEG and PNG images are allowed'
    ]);
    exit();
}

$fileExtension = pathinfo($file['name'], PATHINFO_EXTENSION);
$fileExtension = strtolower($fileExtension);

if (!in_array($fileExtension, ['jpg', 'jpeg', 'png'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Invalid file extension. Only .jpg, .jpeg, and .png are allowed'
    ]);
    exit();
}

$timestamp = time();
$fileName = 'banner_' . $timestamp . '.' . $fileExtension;
$filePath = $uploadDir . $fileName;

if (!move_uploaded_file($file['tmp_name'], $filePath)) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to save file to upload directory'
    ]);
    exit();
}

chmod($filePath, 0644);

// Build proper response URL
$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' || $_SERVER['SERVER_PORT'] == 443) ? 'https://' : 'http://';
$domainAndPath = $_SERVER['HTTP_HOST'] . '/uploads/banners/';
$imageUrl = $protocol . $domainAndPath . $fileName;

// Send clean JSON response
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
exit;