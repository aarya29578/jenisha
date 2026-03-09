<?php
header('Content-Type: text/plain; charset=utf-8');
header('Access-Control-Allow-Origin: *');
echo "=== SERVER UPLOAD DIAGNOSTICS ===\n\n";

// 1. PHP limits
echo "[PHP LIMITS]\n";
echo "PHP version         : " . phpversion() . "\n";
echo "upload_max_filesize : " . ini_get('upload_max_filesize') . "\n";
echo "post_max_size       : " . ini_get('post_max_size') . "\n";
echo "max_execution_time  : " . ini_get('max_execution_time') . "\n";
echo "file_uploads        : " . (ini_get('file_uploads') ? 'ON' : 'OFF') . "\n";
echo "upload_tmp_dir      : " . (ini_get('upload_tmp_dir') ?: sys_get_temp_dir()) . "\n";
echo "\n";

// 2. Directory checks
echo "[DIRECTORY CHECKS]\n";
$dirs = [
    __DIR__,
    __DIR__ . '/users',
];
foreach ($dirs as $d) {
    $exists   = is_dir($d)      ? 'EXISTS' : 'MISSING';
    $writable = is_writable($d) ? 'WRITABLE' : 'NOT WRITABLE';
    $perms    = is_dir($d) ? substr(sprintf('%o', fileperms($d)), -4) : 'n/a';
    echo "$d\n  => $exists | $writable | perms=$perms\n";
}
echo "\n";

// 3. Temp dir writable?
echo "[TEMP DIR]\n";
$tmp = sys_get_temp_dir();
$tmpWritable = is_writable($tmp) ? 'WRITABLE' : 'NOT WRITABLE';
echo "$tmp => $tmpWritable\n\n";

// 4. PHP extensions
echo "[EXTENSIONS]\n";
foreach (['fileinfo','curl','json','gd'] as $ext) {
    echo "$ext : " . (extension_loaded($ext) ? 'loaded' : 'MISSING') . "\n";
}
echo "\n";

// 5. Test write into users/
echo "[WRITE TEST]\n";
$testDir = __DIR__ . '/users';
if (!is_dir($testDir)) {
    if (@mkdir($testDir, 0755, true)) {
        echo "Created users/ directory\n";
    } else {
        echo "FAILED to create users/ directory\n";
    }
}
$testFile = $testDir . '/_test_' . time() . '.txt';
$written = @file_put_contents($testFile, 'test');
if ($written !== false) {
    echo "Write test: PASSED (wrote $written bytes to $testFile)\n";
    @unlink($testFile);
} else {
    echo "Write test: FAILED - cannot write to $testDir\n";
}
echo "\n";

// 6. Recent upload.log entries
echo "[RECENT UPLOAD LOG]\n";
$logFile = __DIR__ . '/upload.log';
if (file_exists($logFile)) {
    $lines = array_filter(array_map('rtrim', file($logFile)));
    $recent = array_slice($lines, -20);
    echo implode("\n", $recent) . "\n";
} else {
    echo "(no upload.log yet)\n";
}
echo "\n";

// 7. List files in users/
echo "[FILES IN users/]\n";
$usersDir = __DIR__ . '/users';
if (is_dir($usersDir)) {
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($usersDir, FilesystemIterator::SKIP_DOTS));
    $count = 0;
    foreach ($it as $f) {
        echo "  " . str_replace($usersDir, '', $f->getPathname()) . "  (" . $f->getSize() . " bytes)\n";
        if (++$count >= 30) { echo "  ... (truncated)\n"; break; }
    }
    if ($count === 0) echo "  (empty)\n";
} else {
    echo "  users/ does not exist\n";
}

echo "\n=== END DIAGNOSTICS ===\n";
?>
