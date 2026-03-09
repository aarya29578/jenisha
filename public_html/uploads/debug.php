<?php
/**
 * Upload Debug Endpoint
 * Tests upload functionality and returns detailed diagnostics
 */

header('Content-Type: application/json');

// Log request
file_put_contents(__DIR__ . '/debug.log', 
    date('Y-m-d H:i:s') . " - Debug request from " . $_SERVER['REMOTE_ADDR'] . "\n", 
    FILE_APPEND);

$response = [
    'timestamp' => date('Y-m-d H:i:s'),
    'server' => [
        'name' => $_SERVER['SERVER_NAME'],
        'software' => $_SERVER['SERVER_SOFTWARE'],
        'php_version' => phpversion(),
    ],
    'upload' => [
        'max_filesize' => ini_get('upload_max_filesize'),
        'post_max_size' => ini_get('post_max_size'),
        'max_execution_time' => ini_get('max_execution_time'),
    ],
    'directories' => [
        'uploads_exists' => is_dir(__DIR__),
        'uploads_writable' => is_writable(__DIR__),
        'users_exists' => is_dir(__DIR__ . '/users'),
        'users_writable' => is_writable(__DIR__ . '/users'),
    ],
    'files' => [
        'upload_php_exists' => file_exists(__DIR__ . '/upload.php'),
        'debug_log_exists' => file_exists(__DIR__ . '/debug.log'),
        'request_log_exists' => file_exists(__DIR__ . '/request.log'),
    ],
    'endpoints' => [
        'upload' => $_SERVER['HTTP_HOST'] . '/uploads/upload.php',
        'test' => $_SERVER['HTTP_HOST'] . '/uploads/test.php',
        'verify' => $_SERVER['HTTP_HOST'] . '/uploads/verify.php',
    ],
];

// Count uploaded files
if (is_dir(__DIR__ . '/users')) {
    $total = 0;
    $folders = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator(__DIR__ . '/users'),
        RecursiveIteratorIterator::LEAVES_ONLY
    );
    foreach ($folders as $file) {
        if ($file->isFile()) $total++;
    }
    $response['statistics']['total_files'] = $total;
}

echo json_encode($response, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
?>
