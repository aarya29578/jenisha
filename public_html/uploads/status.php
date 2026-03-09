<?php
/**
 * Server Status & Configuration Check
 * Access: https://your-domain.com/uploads/status.php
 */

header('Content-Type: application/json; charset=utf-8');

$status = [];

// 1. PHP Configuration
$status['PHP'] = [
    'version' => phpversion(),
    'upload_max_filesize' => ini_get('upload_max_filesize'),
    'post_max_size' => ini_get('post_max_size'),
    'max_execution_time' => ini_get('max_execution_time'),
    'memory_limit' => ini_get('memory_limit'),
    'file_uploads' => ini_get('file_uploads') ? 'Enabled' : 'Disabled',
    'temp_dir' => sys_get_temp_dir(),
];

// 2. Directories
$uploadDir = __DIR__ . '/users';
$baseStat = @stat(__DIR__);

$status['Directories'] = [
    '/uploads exists' => is_dir(__DIR__) ? 'YES' : 'NO',
    '/uploads writable' => is_writable(__DIR__) ? 'YES' : 'NO',
    '/uploads permissions' => substr(sprintf('%o', fileperms(__DIR__)), -4),
    '/uploads/users exists' => is_dir($uploadDir) ? 'YES' : 'NO',
    '/uploads/users writable' => is_writable($uploadDir) ? 'YES' : 'NO',
    '/uploads/users permissions' => is_dir($uploadDir) ? substr(sprintf('%o', fileperms($uploadDir)), -4) : 'N/A',
    'Temp dir writable' => is_writable(sys_get_temp_dir()) ? 'YES' : 'NO',
];

// 3. Web server info
$status['Web Server'] = [
    'Server Software' => $_SERVER['SERVER_SOFTWARE'] ?? 'Unknown',
    'HTTP Host' => $_SERVER['HTTP_HOST'] ?? 'Unknown',
    'Protocol' => (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'HTTPS' : 'HTTP',
    'PHP SAPI' => php_sapi_name(),
];

// 4. Extensions
$extensions = ['gd', 'curl', 'fileinfo', 'json', 'spl', 'pdo'];
$status['Extensions'] = [];
foreach ($extensions as $ext) {
    $status['Extensions'][$ext] = extension_loaded($ext) ? 'Loaded' : 'Not Loaded';
}

// 5. File counts
$status['Uploads'] = [
    'Total files' => count(glob($uploadDir . '/*/*', GLOB_NOSORT) ?: []),
    'User directories' => count(glob($uploadDir . '/*', GLOB_ONLYDIR) ?: []),
];

// 6. Recent log entries
$logFile = __DIR__ . '/upload.log';
$status['Recent Uploads'] = [];
if (file_exists($logFile)) {
    $lines = array_filter(array_map('trim', file($logFile)));
    $recent = array_slice($lines, -10);
    $status['Recent Uploads'] = array_reverse($recent);
} else {
    $status['Recent Uploads'][] = 'No log file yet';
}

// 7. Test write capability
$testFile = $uploadDir . '/.test_' . time() . '.txt';
$canWrite = @file_put_contents($testFile, 'test') !== false;
if ($canWrite) {
    @unlink($testFile);
}
$status['Test'] = [
    'Can write to /uploads/users' => $canWrite ? 'YES' : 'NO',
];

// 8. Connectivity
$status['Connectivity'] = [
    'Remote IP' => $_SERVER['REMOTE_ADDR'] ?? 'Unknown',
    'Request Method' => $_GET['_method'] ?? 'GET',
    'User Agent' => substr($_SERVER['HTTP_USER_AGENT'] ?? 'Unknown', 0, 50) . '...',
];

// Output
http_response_code(200);
echo json_encode($status, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
exit;
?>
