<?php
/**
 * Document Upload Endpoint - CLEAN VERSION
 * Method: POST multipart/form-data
 * Fields: userId, documentId, file (image)
 */

set_time_limit(120);
ini_set('max_execution_time', 120);
error_reporting(E_ALL);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/php-error.log');

// CORS - must come BEFORE any output
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');
header('Content-Type: application/json; charset=utf-8');

function writeLog($msg) {
    $ts = date('Y-m-d H:i:s');
    $ip = $_SERVER['REMOTE_ADDR'] ?? '-';
    @file_put_contents(__DIR__ . '/upload.log', "[$ts][$ip] $msg\n", FILE_APPEND | LOCK_EX);
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die(json_encode(['success' => false, 'message' => 'Method not allowed']));
}

try {
    writeLog('=== NEW UPLOAD REQUEST ===');
    writeLog('POST keys: ' . implode(', ', array_keys($_POST)));
    writeLog('FILES keys: ' . implode(', ', array_keys($_FILES)));

    $userId     = trim($_POST['userId'] ?? '');
    $documentId = trim($_POST['documentId'] ?? '');

    if ($userId === '')     throw new Exception('Missing required field: userId');
    if ($documentId === '') throw new Exception('Missing required field: documentId');
    if (!isset($_FILES['file'])) throw new Exception('Missing required field: file');

    $userId     = preg_replace('/[^a-zA-Z0-9_\-]/', '', $userId);
    $documentId = preg_replace('/[^a-zA-Z0-9_\-]/', '', $documentId);
    if ($userId === '' || $documentId === '') throw new Exception('Invalid userId or documentId');

    writeLog("userId=$userId documentId=$documentId");

    $file = $_FILES['file'];
    $phpErrors = [
        UPLOAD_ERR_INI_SIZE   => 'File exceeds upload_max_filesize ('.ini_get('upload_max_filesize').')',
        UPLOAD_ERR_FORM_SIZE  => 'File exceeds MAX_FILE_SIZE in form',
        UPLOAD_ERR_PARTIAL    => 'File was only partially uploaded',
        UPLOAD_ERR_NO_FILE    => 'No file was uploaded',
        UPLOAD_ERR_NO_TMP_DIR => 'Missing temporary folder on server',
        UPLOAD_ERR_CANT_WRITE => 'Failed to write file to disk',
        UPLOAD_ERR_EXTENSION  => 'A PHP extension rejected the upload',
    ];
    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('Upload error: ' . ($phpErrors[$file['error']] ?? 'Code '.$file['error']));
    }
    if ($file['size'] === 0) throw new Exception('Uploaded file is empty (0 bytes)');
    if ($file['size'] > 5 * 1024 * 1024) throw new Exception('File too large: '.round($file['size']/1048576,2).' MB (max 5 MB)');

    writeLog("File: name={$file['name']} size={$file['size']}");

    $allowed = ['image/jpeg','image/png','image/gif','image/webp'];
    $mime = function_exists('mime_content_type') ? mime_content_type($file['tmp_name']) : 'image/jpeg';
    if (!in_array($mime, $allowed, true)) throw new Exception("Rejected file type: $mime");

    $extMap = ['image/jpeg'=>'jpg','image/png'=>'png','image/gif'=>'gif','image/webp'=>'webp'];
    $ext = $extMap[$mime] ?? 'jpg';
    writeLog("MIME=$mime ext=$ext");

    $usersBaseDir = __DIR__ . '/users';
    $userDir      = $usersBaseDir . '/' . $userId;

    foreach ([$usersBaseDir, $userDir] as $dir) {
        if (!is_dir($dir)) {
            if (!@mkdir($dir, 0755, true)) throw new Exception("Cannot create directory: $dir");
            writeLog("Created directory: $dir");
        }
        if (!is_writable($dir)) throw new Exception("Directory not writable: $dir");
    }

    $filename = $documentId . '.' . $ext;
    $destPath = $userDir . '/' . $filename;
    writeLog("Moving to: $destPath");

    if (!move_uploaded_file($file['tmp_name'], $destPath)) {
        throw new Exception("move_uploaded_file() failed � check dir permissions. dest=$destPath");
    }
    @chmod($destPath, 0644);
    if (!file_exists($destPath)) throw new Exception("File missing after move � filesystem error");

    $savedSize = filesize($destPath);
    writeLog("Saved OK size=$savedSize");

    $scheme   = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
    $host     = $_SERVER['HTTP_HOST'];
    $imageUrl = "$scheme://$host/uploads/users/$userId/$filename";
    writeLog("SUCCESS imageUrl=$imageUrl");

    echo json_encode(['success'=>true,'imageUrl'=>$imageUrl,'userId'=>$userId,'documentId'=>$documentId,'filename'=>$filename,'size'=>$savedSize]);

} catch (Exception $e) {
    writeLog('FAILED: ' . $e->getMessage());
    http_response_code(400);
    echo json_encode(['success'=>false,'message'=>$e->getMessage()]);
}
?>
