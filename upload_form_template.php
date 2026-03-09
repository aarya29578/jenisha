<?php
/*
 * upload_form_template.php
 * Upload a PDF / DOC / DOCX form template for a service.
 * Called from the admin panel with multipart/form-data.
 * Expected field: file  (the template file)
 * Returns JSON: { success: true, fileUrl: "https://..." }
 */

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

if (!isset($_FILES['file']) || $_FILES['file']['error'] !== UPLOAD_ERR_OK) {
    $errCode = $_FILES['file']['error'] ?? 'missing';
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'No file uploaded or upload error: ' . $errCode]);
    exit();
}

$file = $_FILES['file'];

// Allow PDF, DOC, DOCX, XLS, XLSX
$allowedMimes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
];
$allowedExts = ['pdf', 'doc', 'docx', 'xls', 'xlsx'];

$extension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));

if (!in_array($file['type'], $allowedMimes) && !in_array($extension, $allowedExts)) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Invalid file type. Only PDF, DOC, DOCX are allowed.']);
    exit();
}

// Max 20 MB
if ($file['size'] > 20 * 1024 * 1024) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'File too large. Max 20 MB.']);
    exit();
}

// Create directory if not exists
$uploadDir = __DIR__ . '/forms/templates/';
if (!file_exists($uploadDir)) {
    mkdir($uploadDir, 0755, true);
}

// Safe filename: timestamp + sanitized original name
$safeName    = preg_replace('/[^a-zA-Z0-9_.-]/', '_', pathinfo($file['name'], PATHINFO_FILENAME));
$timestamp   = round(microtime(true) * 1000);
$newFilename = 'template_' . $timestamp . '_' . $safeName . '.' . $extension;
$targetPath  = $uploadDir . $newFilename;

if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Failed to save file to server.']);
    exit();
}

$protocol  = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https' : 'http';
$host      = $_SERVER['HTTP_HOST'];
$publicUrl = $protocol . '://' . $host . '/uploads/forms/templates/' . $newFilename;

ob_clean();
echo json_encode([
    'success'  => true,
    'fileUrl'  => $publicUrl,
    'filename' => $newFilename,
]);
exit();
?>
