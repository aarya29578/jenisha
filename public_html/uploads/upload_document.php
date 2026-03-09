<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    echo json_encode(['success' => false]);
    exit;
}

$dir = __DIR__ . '/documents/';
@mkdir($dir, 0755, true);

if (!isset($_FILES['document'])) {
    echo json_encode(['success' => false]);
    exit;
}

$f = $_FILES['document'];
if ($f['error'] !== UPLOAD_ERR_OK || $f['size'] > 50 * 1024 * 1024) {
    echo json_encode(['success' => false]);
    exit;
}

$ext = strtolower(pathinfo($f['name'], PATHINFO_EXTENSION));
if (!in_array($ext, ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'gif'])) {
    echo json_encode(['success' => false]);
    exit;
}

$name = 'doc_' . time() . '.' . $ext;
$path = $dir . $name;

if (!move_uploaded_file($f['tmp_name'], $path)) {
    echo json_encode(['success' => false]);
    exit;
}

chmod($path, 0644);
$protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https://' : 'http://';
echo json_encode(['success' => true, 'imageUrl' => $protocol . $_SERVER['HTTP_HOST'] . '/uploads/documents/' . $name]);
?>
