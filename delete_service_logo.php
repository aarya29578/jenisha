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

// Accept JSON body
$body     = file_get_contents('php://input');
$data     = json_decode($body, true);
$filename = $data['filename'] ?? '';

// Also accept form-encoded
if (empty($filename) && isset($_POST['filename'])) {
    $filename = $_POST['filename'];
}

if (empty($filename)) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'filename is required']);
    exit();
}

// Security: allow only filenames (no path traversal)
$basename = basename($filename);
if ($basename !== $filename || strpos($basename, '..') !== false) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Invalid filename']);
    exit();
}

$filePath = __DIR__ . '/services/' . $basename;

if (!file_exists($filePath)) {
    // Already gone – treat as success
    ob_clean();
    echo json_encode(['success' => true, 'message' => 'File not found (already deleted)']);
    exit();
}

if (unlink($filePath)) {
    ob_clean();
    echo json_encode(['success' => true, 'message' => 'File deleted']);
} else {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Failed to delete file']);
}
exit();
?>
