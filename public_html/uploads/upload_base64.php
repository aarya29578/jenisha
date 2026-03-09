<?php
/**
 * Base64 Upload Endpoint - Alternative to multipart
 * More reliable for slow connections and may avoid connection reset issues
 */

set_time_limit(300);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');
header('Connection: close');

ob_start();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    ob_end_flush();
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    ob_end_flush();
    exit;
}

try {
    $input = file_get_contents('php://input');
    $data = json_decode($input, true);

    if (!$data || !isset($data['userId']) || !isset($data['documentId']) || !isset($data['imageData'])) {
        throw new Exception('Missing required fields: userId, documentId, imageData');
    }

    $userId = preg_replace('/[^a-zA-Z0-9_\-]/', '', $data['userId']);
    $documentId = preg_replace('/[^a-zA-Z0-9_\-]/', '', $data['documentId']);
    $imageData = $data['imageData']; // base64 string

    // Remove data URI prefix if present
    if (strpos($imageData, 'data:image') === 0) {
        $imageData = preg_replace('#^data:image/[^;]+;base64,#', '', $imageData);
    }

    // Decode base64
    $binaryData = base64_decode($imageData, true);
    if ($binaryData === false) {
        throw new Exception('Invalid base64 data');
    }

    // Validate size (5MB max)
    if (strlen($binaryData) > 5 * 1024 * 1024) {
        throw new Exception('File too large');
    }

    // Create directory
    $dir = __DIR__ . '/users/' . $userId . '/';
    @mkdir($dir, 0777, true);

    if (!is_writable($dir)) {
        throw new Exception('Cannot write to upload directory');
    }

    // Detect image format
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mime = finfo_buffer($finfo, $binaryData);
    finfo_close($finfo);

    $ext = 'jpg';
    if ($mime === 'image/png') $ext = 'png';
    elseif ($mime === 'image/gif') $ext = 'gif';
    elseif ($mime === 'image/webp') $ext = 'webp';

    $filename = $documentId . '.' . $ext;
    $path = $dir . $filename;

    // Write file
    if (file_put_contents($path, $binaryData) === false) {
        throw new Exception('Failed to write file');
    }

    @chmod($path, 0644);

    // Generate URL
    $protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https://' : 'http://';
    $imageUrl = $protocol . $_SERVER['HTTP_HOST'] . '/uploads/users/' . $userId . '/' . $filename;

    http_response_code(200);
    echo json_encode([
        'success' => true,
        'imageUrl' => $imageUrl,
        'userId' => $userId,
        'documentId' => $documentId,
    ]);

    ob_end_flush();
    exit;

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);

    ob_end_flush();
    exit;
}
?>
