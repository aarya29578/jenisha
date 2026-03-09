<?php
/*
 * upload_form_submission.php
 * Accepts multipart/form-data:  file (binary) + userId (text)
 * Returns JSON: { success, fileUrl, filename, fileSize } or { success:false, error }
 */

error_reporting(E_ALL);
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

//  Debug log � read at https://jenishaonlineservice.com/uploads/upload_debug.log
$logPath = __DIR__ . '/upload_debug.log';
$fileInfo = [];
foreach ($_FILES as $k => $f) {
    $fileInfo[$k] = ['name' => $f['name'], 'size' => $f['size'], 'error' => $f['error']];
}
$logLine = date('c') . ' | CT=' . ($_SERVER['CONTENT_TYPE'] ?? '-')
         . ' | CL=' . ($_SERVER['CONTENT_LENGTH'] ?? '-')
         . ' | FILES=' . json_encode($fileInfo)
         . ' | POST=' . implode(',', array_keys($_POST))
         . "\n";
file_put_contents($logPath, $logLine, FILE_APPEND);

if (!isset($_FILES['file'])) {
    ob_clean();
    echo json_encode(['success' => false,
        'error' => 'No "file" field. ContentType=' . ($_SERVER['CONTENT_TYPE'] ?? 'none')]);
    exit();
}

$errCode = (int)$_FILES['file']['error'];
if ($errCode !== UPLOAD_ERR_OK) {
    $msgs = [
        1 => 'File exceeds upload_max_filesize (' . ini_get('upload_max_filesize') . ')',
        2 => 'File exceeds form MAX_FILE_SIZE',
        3 => 'File only partially uploaded',
        4 => 'No file uploaded',
        6 => 'Server missing temp folder',
        7 => 'Server cannot write to disk',
        8 => 'PHP extension blocked upload',
    ];
    ob_clean();
    echo json_encode(['success' => false, 'error' => $msgs[$errCode] ?? 'Upload error ' . $errCode]);
    exit();
}

if ((int)$_FILES['file']['size'] === 0) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Received 0 bytes � file was empty on arrival at server.']);
    exit();
}

$file        = $_FILES['file'];
$allowedExts = ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'];
$ext         = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));

if (!in_array($ext, $allowedExts)) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'Invalid type "' . $ext . '". Allowed: pdf doc docx jpg png']);
    exit();
}

if ($file['size'] > 25 * 1024 * 1024) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'File too large (' . round($file['size']/1048576,1) . ' MB). Max 25 MB.']);
    exit();
}

$userId    = isset($_POST['userId']) ? preg_replace('/[^a-zA-Z0-9_-]/', '', $_POST['userId']) : 'unknown';
$uploadDir = __DIR__ . '/forms/submissions/' . $userId . '/';
if (!file_exists($uploadDir)) mkdir($uploadDir, 0755, true);

$safeName    = preg_replace('/[^a-zA-Z0-9_.-]/', '_', pathinfo($file['name'], PATHINFO_FILENAME));
$timestamp   = round(microtime(true) * 1000);
$newFilename = 'submission_' . $timestamp . '_' . $safeName . '.' . $ext;
$targetPath  = $uploadDir . $newFilename;

if (!move_uploaded_file($file['tmp_name'], $targetPath)) {
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'move_uploaded_file failed � check write permissions.']);
    exit();
}

$savedSize = filesize($targetPath);
if ($savedSize === 0) {
    unlink($targetPath);
    ob_clean();
    echo json_encode(['success' => false, 'error' => 'File saved as 0 bytes. Server disk issue.']);
    exit();
}

$protocol  = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https' : 'http';
$publicUrl = $protocol . '://' . $_SERVER['HTTP_HOST']
           . '/uploads/forms/submissions/' . $userId . '/' . $newFilename;

file_put_contents($logPath, date('c') . ' SUCCESS file=' . $newFilename . ' size=' . $savedSize . "\n", FILE_APPEND);

ob_clean();
echo json_encode(['success' => true, 'fileUrl' => $publicUrl, 'filename' => $newFilename, 'fileSize' => $savedSize]);
exit();
?>
