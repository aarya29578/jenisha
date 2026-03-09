<?php
error_reporting(0);
ini_set('display_errors', '0');
ob_start();

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Only POST method allowed']);
    exit();
}

if (!isset($_FILES['logo']) || $_FILES['logo']['error'] !== UPLOAD_ERR_OK) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'No file uploaded or upload error']);
    exit();
}

$file = $_FILES['logo'];
$allowedTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp'];

if (!in_array($file['type'], $allowedTypes)) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Invalid file type. Only JPG, PNG, GIF, WEBP allowed']);
    exit();
}

// Max 5MB
if ($file['size'] > 5 * 1024 * 1024) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'File too large. Max 5MB']);
    exit();
}

// Create logos folder if not exists
$uploadDir = __DIR__ . '/logos/';
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// Generate unique filename
$extension = pathinfo($file['name'], PATHINFO_EXTENSION);
$timestamp = round(microtime(true) * 1000);
$newFilename = 'logo_' . $timestamp . '.' . $extension;
$targetPath = $uploadDir . $newFilename;

// Move uploaded file
if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Failed to save file']);
    exit();
}

// Return the public URL
$protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'];
$publicUrl = $protocol . '://' . $host . '/uploads/logos/' . $newFilename;

ob_clean();
echo json_encode([
    'success' => true,
    'imageUrl' => $publicUrl,
    'filename' => $newFilename
]);
exit();
?>
