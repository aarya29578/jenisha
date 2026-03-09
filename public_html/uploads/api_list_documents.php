<?php
/**
 * Get List of Uploaded Documents API
 * Returns all documents uploaded by users
 */

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    $usersDir = __DIR__ . '/users/';
    
    if (!is_dir($usersDir)) {
        echo json_encode(['success' => true, 'documents' => [], 'total' => 0]);
        exit;
    }

    $documents = [];
    $protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https://' : 'http://';
    $host = $_SERVER['HTTP_HOST'];

    // Scan all user directories
    $userDirs = scandir($usersDir);
    foreach ($userDirs as $userId) {
        if ($userId === '.' || $userId === '..') continue;
        
        $userPath = $usersDir . $userId;
        if (!is_dir($userPath)) continue;

        // Scan all documents in user directory
        $docFiles = scandir($userPath);
        foreach ($docFiles as $filename) {
            if ($filename === '.' || $filename === '..') continue;
            
            $filePath = $userPath . '/' . $filename;
            if (!is_file($filePath)) continue;

            $fileUrl = $protocol . $host . '/uploads/users/' . $userId . '/' . $filename;
            $fileSize = filesize($filePath);
            $uploadTime = filemtime($filePath);

            // Extract document ID (remove extension)
            $documentId = pathinfo($filename, PATHINFO_FILENAME);

            $documents[] = [
                'userId' => $userId,
                'documentId' => $documentId,
                'filename' => $filename,
                'url' => $fileUrl,
                'size' => $fileSize,
                'sizeFormatted' => format_bytes($fileSize),
                'uploadedAt' => date('Y-m-d H:i:s', $uploadTime),
                'uploadedAtTimestamp' => $uploadTime,
            ];
        }
    }

    // Sort by newest first
    usort($documents, function($a, $b) {
        return $b['uploadedAtTimestamp'] - $a['uploadedAtTimestamp'];
    });

    echo json_encode([
        'success' => true,
        'documents' => $documents,
        'total' => count($documents),
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
    ]);
}

function format_bytes($bytes) {
    $units = ['B', 'KB', 'MB', 'GB'];
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    $bytes /= (1 << (10 * $pow));
    return round($bytes, 2) . ' ' . $units[$pow];
}
?>
