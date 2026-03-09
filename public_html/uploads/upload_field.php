<?php
error_reporting(0);
ini_set('display_errors', '0');

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false, 'error' => 'Only POST method allowed']);
    exit();
}

// Read JSON input
$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data || !isset($data['image']) || !isset($data['filename'])) {
    echo json_encode(['success' => false, 'error' => 'Missing image or filename']);
    exit();
}

$base64Image = $data['image'];
$filename = $data['filename'];

// Validate base64
if (!preg_match('/^[a-zA-Z0-9\/\r\n+]*={0,2}$/', $base64Image)) {
    echo json_encode(['success' => false, 'error' => 'Invalid base64 image']);
    exit();
}

// Decode base64
$imageData = base64_decode($base64Image);

if ($imageData === false) {
    echo json_encode(['success' => false, 'error' => 'Failed to decode base64 image']);
    exit();
}

// Check file size (max 10MB)
$fileSize = strlen($imageData);
if ($fileSize > 10 * 1024 * 1024) {
    echo json_encode(['success' => false, 'error' => 'File too large. Max 10MB']);
    exit();
}

// Create documents folder if not exists
$uploadDir = __DIR__ . '/documents/';
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// Sanitize filename
$filename = preg_replace('/[^a-zA-Z0-9_.-]/', '_', $filename);
$targetPath = $uploadDir . $filename;

// Save file
if (!file_put_contents($targetPath, $imageData)) {
    echo json_encode(['success' => false, 'error' => 'Failed to save file']);
    exit();
}

// Set permissions
chmod($targetPath, 0644);

// Return the public URL
$protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'];
$publicUrl = $protocol . '://' . $host . '/uploads/documents/' . $filename;

echo json_encode([
    'success' => true,
    'url' => $publicUrl,
    'filename' => $filename,
    'size' => $fileSize
]);
exit();
?>
