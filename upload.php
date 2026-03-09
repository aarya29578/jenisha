<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

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

// When this file is served from public_html/uploads/, __DIR__ already
// points to that folder — saving to __DIR__ directly avoids double /uploads/.
$uploadDir = __DIR__ . '/';

if (!is_dir($uploadDir)) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Upload directory does not exist or is not accessible'
    ]);
    exit();
}

$userId = isset($_POST['userId']) ? trim($_POST['userId']) : null;
$documentId = isset($_POST['documentId']) ? trim($_POST['documentId']) : null;

if (!$userId || !$documentId) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Missing required fields: userId and documentId'
    ]);
    exit();
}

if (empty($_FILES) || !isset($_FILES['file'])) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'No file provided'
    ]);
    exit();
}

$file = $_FILES['file'];

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

$maxFileSize = 5 * 1024 * 1024;

if ($file['size'] > $maxFileSize) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'File size exceeds 5MB limit'
    ]);
    exit();
}

if ($file['size'] === 0) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'File is empty'
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
$randomString = bin2hex(random_bytes(4));
$fileName = $userId . '_' . $documentId . '_' . $timestamp . '_' . $randomString . '.' . $fileExtension;
$filePath = $uploadDir . $fileName;

if (!move_uploaded_file($file['tmp_name'], $filePath)) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Failed to save file to upload directory'
    ]);
    exit();
}

$protocol = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off' || $_SERVER['SERVER_PORT'] == 443) ? 'https://' : 'http://';
$domainAndPath = $_SERVER['HTTP_HOST'] . '/uploads/';  // files live in /uploads/
$imageUrl = $protocol . $domainAndPath . $fileName;

chmod($filePath, 0644);

http_response_code(200);
echo json_encode([
    'success' => true,
    'imageUrl' => $imageUrl,
    'fileName' => $fileName,
    'uploadedAt' => date('Y-m-d H:i:s'),
    'fileSize' => $file['size']
]);
?>
