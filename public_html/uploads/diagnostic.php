<?php
/**
 * Complete Upload System Diagnostic
 * Identifies all potential issues with document uploads
 */

header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html>
<head>
    <title>Upload System Diagnostic Report</title>
    <style>
        * { margin: 0; padding: 0; }
        body { font-family: 'Monaco', 'Courier New', monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: #4ec9b0; margin-bottom: 20px; font-size: 24px; }
        h2 { color: #569cd6; margin-top: 30px; margin-bottom: 15px; font-size: 18px; border-bottom: 2px solid #464447; padding-bottom: 10px; }
        .section { background: #252526; border: 1px solid #464447; border-radius: 4px; padding: 15px; margin-bottom: 15px; }
        .success { background: #0d3e0d; border-left: 4px solid #4ec9b0; }
        .warning { background: #3e3e1d; border-left: 4px solid #dcdcaa; }
        .error { background: #3e0d0d; border-left: 4px solid #f48771; }
        .info { background: #1e2a3e; border-left: 4px solid #569cd6; }
        code { background: #1e1e1e; padding: 2px 6px; border-radius: 3px; }
        pre { background: #1e1e1e; overflow-x: auto; padding: 10px; border-radius: 4px; margin: 10px 0; border: 1px solid #464447; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #464447; }
        th { background: #2d2d30; font-weight: bold; }
        .pass { color: #4ec9b0; }
        .fail { color: #f48771; }
        .warn { color: #dcdcaa; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Upload System Diagnostic Report</h1>
        <p>Generated: <?= date('Y-m-d H:i:s'); ?> | Server: <?= $_SERVER['SERVER_NAME']; ?></p>

<?php
class Diagnostic {
    private $issues = [];
    private $checks = [];

    public function run() {
        $this->checkPhpConfiguration();
        $this->checkDirectories();
        $this->checkFilePermissions();
        $this->checkPhpExtensions();
        $this->checkFiles();
        $this->checkLogs();
        $this->testUpload();
        $this->generateReport();
    }

    private function checkPhpConfiguration() {
        echo '<h2>1️⃣ PHP Configuration</h2>';
        echo '<div class="section">';

        $configs = [
            'upload_max_filesize' => 'Max file upload size',
            'post_max_size' => 'Max POST data size',
            'max_execution_time' => 'Max execution time (seconds)',
            'default_socket_timeout' => 'Socket timeout',
            'memory_limit' => 'Memory limit',
        ];

        echo '<table>';
        echo '<tr><th>Setting</th><th>Value</th><th>Status</th></tr>';
        foreach ($configs as $ini => $label) {
            $value = ini_get($ini);
            $class = 'pass';
            $status = '✓ OK';

            // Check if values are appropriate
            if ($ini === 'upload_max_filesize' && $this->parseBytes($value) < 5 * 1024 * 1024) {
                $class = 'fail';
                $status = '✗ Too small (need 5MB+)';
            }
            if ($ini === 'max_execution_time' && $value < 60) {
                $class = 'warn';
                $status = '⚠ May be too short';
            }

            echo "<tr><td>$label</td><td><code>$value</code></td><td class=\"$class\">$status</td></tr>";
        }
        echo '</table>';
        echo '</div>';
    }

    private function checkDirectories() {
        echo '<h2>2️⃣ Directory Structure</h2>';
        echo '<div class="section">';

        $dirs = [
            __DIR__ => 'Uploads root',
            __DIR__ . '/users' => 'Users directory',
            __DIR__ . '/banners' => 'Banners directory',
            __DIR__ . '/documents' => 'Documents directory',
            __DIR__ . '/logos' => 'Logos directory',
        ];

        echo '<table>';
        echo '<tr><th>Directory</th><th>Exists</th><th>Readable</th><th>Writable</th></tr>';

        foreach ($dirs as $path => $label) {
            $exists = is_dir($path) ? '<span class="pass">✓</span>' : '<span class="fail">✗</span>';
            $readable = (is_dir($path) && is_readable($path)) ? '<span class="pass">✓</span>' : '<span class="fail">✗</span>';
            $writable = (is_dir($path) && is_writable($path)) ? '<span class="pass">✓</span>' : '<span class="fail">✗</span>';

            if (!is_dir($path)) {
                $this->issues[] = "Missing directory: $path";
            }
            if (is_dir($path) && !is_writable($path)) {
                $this->issues[] = "Directory not writable: $path";
            }

            echo "<tr><td>$label<br><code>" . basename($path) . "</code></td><td>$exists</td><td>$readable</td><td>$writable</td></tr>";
        }
        echo '</table>';
        echo '</div>';
    }

    private function checkFilePermissions() {
        echo '<h2>3️⃣ File Permissions</h2>';
        echo '<div class="section">';

        // Try to create a test file
        $testFile = __DIR__ . '/users/.permission_test_' . time();
        $canWrite = @file_put_contents($testFile, 'test');

        if ($canWrite) {
            @unlink($testFile);
            echo '<div class="success">✓ Directory is writable - can create files</div>';
        } else {
            echo '<div class="error">✗ Cannot create files in users directory</div>';
            echo '<pre>Fix: chmod 755 ' . __DIR__ . '/users/
cd ' . __DIR__ . '/users
ls -la</pre>';
            $this->issues[] = "Users directory not writable - cannot save uploads";
        }

        // Check if we can create subdirectories
        $testDir = __DIR__ . '/users/test_' . time();
        if (@mkdir($testDir)) {
            @rmdir($testDir);
            echo '<div class="success">✓ Can create subdirectories</div>';
        } else {
            echo '<div class="error">✗ Cannot create subdirectories</div>';
            $this->issues[] = "Cannot create user subdirectories";
        }

        echo '</div>';
    }

    private function checkPhpExtensions() {
        echo '<h2>4️⃣ PHP Extensions</h2>';
        echo '<div class="section">';

        $extensions = [
            'curl' => 'cURL',
            'gd' => 'GD Image',
            'fileinfo' => 'File Info',
            'json' => 'JSON',
            'spl' => 'SPL',
        ];

        echo '<table>';
        echo '<tr><th>Extension</th><th>Status</th></tr>';

        foreach ($extensions as $ext => $name) {
            $loaded = extension_loaded($ext) ? '<span class="pass">✓ Loaded</span>' : '<span class="fail">✗ Missing</span>';
            echo "<tr><td>$name</td><td>$loaded</td></tr>";
        }
        echo '</table>';
        echo '</div>';
    }

    private function checkFiles() {
        echo '<h2>5️⃣ Upload Endpoint Files</h2>';
        echo '<div class="section">';

        $files = [
            'upload.php' => 'Main multipart upload',
            'upload_base64.php' => 'Base64 upload endpoint',
            'test.php' => 'Test upload form',
            'debug.php' => 'Debug endpoint',
            'request.log' => 'Request log file',
            'error.log' => 'Error log file',
        ];

        echo '<table>';
        echo '<tr><th>File</th><th>Purpose</th><th>Status</th></tr>';

        foreach ($files as $file => $purpose) {
            $path = __DIR__ . '/' . $file;
            $exists = file_exists($path) ? '<span class="pass">✓ Exists</span>' : '<span class="fail">✗ Missing</span>';
            echo "<tr><td><code>$file</code></td><td>$purpose</td><td>$exists</td></tr>";
        }
        echo '</table>';
        echo '</div>';
    }

    private function checkLogs() {
        echo '<h2>6️⃣ Log Files</h2>';
        echo '<div class="section">';

        $logs = ['request.log', 'error.log', 'debug.log'];

        foreach ($logs as $log) {
            $path = __DIR__ . '/' . $log;
            if (file_exists($path)) {
                $size = filesize($path);
                $lines = count(file($path));
                echo '<div class="info">';
                echo "📄 <strong>$log</strong>: $size bytes, $lines lines<br>";
                echo '<pre>' . htmlspecialchars(file_get_contents($path, false, null, -2000)) . '</pre>';
                echo '</div>';
            } else {
                echo "<div class=\"warning\">⚠ $log not created yet</div>";
            }
        }
        echo '</div>';
    }

    private function testUpload() {
        echo '<h2>7️⃣ Upload Test</h2>';
        echo '<div class="section">';

        if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['test_file'])) {
            $file = $_FILES['test_file'];
            $testDir = __DIR__ . '/users/test_' . time() . '/';

            @mkdir($testDir, 0777, true);

            if (!is_dir($testDir)) {
                echo '<div class="error">✗ Failed to create test directory: ' . $testDir . '</div>';
                return;
            }

            if (move_uploaded_file($file['tmp_name'], $testDir . 'test.jpg')) {
                echo '<div class="success">✓ Test upload successful!</div>';
                echo '<img src="/uploads/users/' . basename($testDir) . 'test.jpg" style="max-width: 200px; margin: 10px 0;" alt="Test image">';
                
                // Clean up
                @unlink($testDir . 'test.jpg');
                @rmdir($testDir);
            } else {
                echo '<div class="error">✗ Failed to move uploaded file</div>';
                $this->issues[] = "move_uploaded_file() failed in test";
            }
        } else {
            echo '<form method="POST" enctype="multipart/form-data" style="padding: 10px; background: #2d2d30; border-radius: 4px;">';
            echo '<input type="file" name="test_file" accept="image/*" required>';
            echo '<button type="submit" style="margin-left: 10px; padding: 8px 15px; background: #569cd6; border: none; border-radius: 3px; color: white; cursor: pointer;">Test Upload</button>';
            echo '</form>';
        }

        echo '</div>';
    }

    private function generateReport() {
        echo '<h2>📋 Summary</h2>';
        echo '<div class="section">';

        if (empty($this->issues)) {
            echo '<div class="success">✓ All checks passed! Upload system should be working.</div>';
        } else {
            echo '<div class="error">✗ Found ' . count($this->issues) . ' issue(s):</div>';
            echo '<ul style="margin: 10px 0; padding-left: 20px;">';
            foreach ($this->issues as $issue) {
                echo "<li>$issue</li>";
            }
            echo '</ul>';
        }

        echo '</div>';
        echo '<hr style="margin: 20px 0; border: 1px solid #464447;">';
        echo '<h2>🔧 Troubleshooting Commands</h2>';
        echo '<div class="section"><pre>';
        echo "# Check directory permissions
ls -la " . __DIR__ . "/

# Make directory writable
chmod 755 " . __DIR__ . "/users

# Fix ownership (if needed)
chown www-data:www-data " . __DIR__ . "/users
chmod 755 " . __DIR__ . "/users

# Check PHP error logs
tail -100 /var/log/php-errors.log

# View recent uploads
ls -lah " . __DIR__ . "/users/
";
        echo '</pre></div>';
    }

    private function parseBytes($value) {
        $value = trim($value);
        $last = strtolower($value[strlen($value)-1]);
        $value = (int)$value;
        
        switch($last) {
            case 'g': $value *= 1024;
            case 'm': $value *= 1024;
            case 'k': $value *= 1024;
        }
        return $value;
    }
}

$diagnostic = new Diagnostic();
$diagnostic->run();
?>

    </div>
</body>
</html>
