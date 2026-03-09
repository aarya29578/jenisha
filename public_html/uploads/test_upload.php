<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// Log everything for debugging
$debug = [
    'request_method' => $_SERVER['REQUEST_METHOD'],
    'files_count' => count($_FILES),
    'files_keys' => array_keys($_FILES),
    'post_keys' => array_keys($_POST),
    'upload_dir_exists' => is_dir(__DIR__ . '/banners/'),
    'upload_dir_writable' => is_writable(__DIR__ . '/banners/'),
    'php_version' => phpversion(),
    'upload_max_filesize' => ini_get('upload_max_filesize'),
    'post_max_size' => ini_get('post_max_size')
];

if (!empty($_FILES['banner'])) {
    $debug['file_details'] = [
        'name' => $_FILES['banner']['name'],
        'type' => $_FILES['banner']['type'],
        'size' => $_FILES['banner']['size'],
        'error' => $_FILES['banner']['error'],
        'tmp_name' => $_FILES['banner']['tmp_name']
    ];
}

echo json_encode([
    'success' => true,
    'message' => 'Test endpoint reached successfully',
    'debug' => $debug
], JSON_PRETTY_PRINT);
