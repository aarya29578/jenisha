<?php
/**
 * Document Upload Verification Script
 * This script verifies that the document upload system is working correctly
 */

header('Content-Type: text/html; charset=utf-8');

echo "<!DOCTYPE html>
<html>
<head>
    <title>Document Upload Verification</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .check { margin: 20px 0; padding: 15px; border-radius: 5px; }
        .pass { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .fail { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .info { background: #d1ecf1; color: #0c5460; border: 1px solid #bee5eb; }
        h1 { color: #333; }
        code { background: #f0f0f0; padding: 2px 5px; border-radius: 3px; }
        pre { background: #f0f0f0; padding: 10px; border-radius: 5px; overflow-x: auto; }
        .warning { background: #fff3cd; color: #856404; border: 1px solid #ffeaa7; }
    </style>
</head>
<body>
    <h1>📋 Document Upload System Verification</h1>
    <p><strong>Server Time:</strong> " . date('Y-m-d H:i:s') . "</p>
    <hr>
";

// Check 1: upload.php exists and is readable
$uploadPhpPath = __DIR__ . '/upload.php';
if (file_exists($uploadPhpPath) && is_readable($uploadPhpPath)) {
    echo '<div class="check pass">✓ <strong>upload.php</strong> exists and is readable</div>';
} else {
    echo '<div class="check fail">✗ <strong>upload.php</strong> not found or not readable</div>';
}

// Check 2: users directory
$usersDir = __DIR__ . '/users';
if (is_dir($usersDir)) {
    echo '<div class="check pass">✓ <code>/uploads/users/</code> directory exists</div>';
    $files = scandir($usersDir);
    $subdirs = array_diff($files, ['.', '..']);
    if (count($subdirs) > 0) {
        echo '<div class="check info">ℹ️ Found ' . count($subdirs) . ' user directories: ' . implode(', ', array_slice($subdirs, 0, 5)) . (count($subdirs) > 5 ? '...' : '') . '</div>';
    } else {
        echo '<div class="check info">ℹ️ No user directories yet (this is normal for a fresh installation)</div>';
    }
} else {
    // Try to create it
    if (@mkdir($usersDir, 0755, true)) {
        echo '<div class="check warning">⚠️ <code>/uploads/users/</code> directory created automatically</div>';
    } else {
        echo '<div class="check fail">✗ <code>/uploads/users/</code> directory does not exist and could not be created</div>';
        echo '<div class="check fail">✗ <strong>ERROR:</strong> Directory creation failed. Check permissions: chmod 755 uploads/</div>';
    }
}

// Check 3: PHP Extensions
$extensions = ['json', 'gd', 'fileinfo'];
$missingExtensions = [];
foreach ($extensions as $ext) {
    if (!extension_loaded($ext)) {
        $missingExtensions[] = $ext;
    }
}

if (empty($missingExtensions)) {
    echo '<div class="check pass">✓ All required PHP extensions loaded: ' . implode(', ', $extensions) . '</div>';
} else {
    echo '<div class="check warning">⚠️ Missing PHP extensions: ' . implode(', ', $missingExtensions) . '</div>';
}

// Check 4: Permissions
$testFile = $usersDir . '/.permission_test_' . time();
if (@file_put_contents($testFile, 'test')) {
    @unlink($testFile);
    echo '<div class="check pass">✓ <code>/uploads/users/</code> is writable</div>';
} else {
    echo '<div class="check fail">✗ <code>/uploads/users/</code> is not writable. Run: chmod 755 ' . $usersDir . '</div>';
}

// Check 5: CORS Headers
echo '<div class="check info">ℹ️ <strong>CORS Configuration:</strong>';
echo '<pre>';
echo "Access-Control-Allow-Origin: *\n";
echo "Access-Control-Allow-Methods: POST, OPTIONS\n";
echo "Access-Control-Allow-Headers: Content-Type\n";
echo '</pre></div>';

// Check 6: Test endpoint
echo '<div class="check info">
<strong>Test Upload Endpoint</strong>
<p>You can test the upload endpoint using curl:</p>
<pre>
curl -X POST https://cyan-llama-839264.hostingersite.com/uploads/upload.php \\
  -F "userId=test-user-123" \\
  -F "documentId=aadhaar" \\
  -F "file=@/path/to/image.jpg"
</pre>
<p>Or test with this form:</p>';

// Form to test upload
echo '<form method="POST" enctype="multipart/form-data" style="margin-top: 15px; padding: 15px; background: white; border-radius: 5px;">
    <div style="margin-bottom: 10px;">
        <label style="display: block; margin-bottom: 5px;"><strong>User ID:</strong></label>
        <input type="text" name="userId" value="test-' . date('Ymd') . '" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 3px;">
    </div>
    <div style="margin-bottom: 10px;">
        <label style="display: block; margin-bottom: 5px;"><strong>Document ID:</strong></label>
        <input type="text" name="documentId" value="aadhaar" style="width: 100%; padding: 8px; border: 1px solid #ddd; border-radius: 3px;">
    </div>
    <div style="margin-bottom: 10px;">
        <label style="display: block; margin-bottom: 5px;"><strong>Select Image:</strong></label>
        <input type="file" name="file" accept="image/*" style="width: 100%; padding: 8px;">
    </div>
    <button type="submit" style="background: #243BFF; color: white; padding: 10px 20px; border: none; border-radius: 3px; cursor: pointer;">Test Upload</button>
</form>';

// Handle test upload
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['file'])) {
    echo '<hr style="margin-top: 20px;"><h2>📤 Upload Test Result</h2>';
    
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => 'https://cyan-llama-839264.hostingersite.com/uploads/upload.php',
        CURLOPT_POST => 1,
        CURLOPT_POSTFIELDS => [
            'userId' => $_POST['userId'] ?? 'test',
            'documentId' => $_POST['documentId'] ?? 'test',
            'file' => new CURLFile($_FILES['file']['tmp_name'], $_FILES['file']['type'], $_FILES['file']['name'])
        ],
        CURLOPT_RETURNTRANSFER => 1,
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    echo '<div class="check info"><strong>HTTP Status:</strong> ' . $httpCode . '</div>';
    echo '<div class="check info"><strong>Response:</strong><pre>' . htmlspecialchars($response) . '</pre></div>';
}

echo '
</div>

<hr>
<p style="color: #666; font-size: 12px;">
<strong>Troubleshooting:</strong><br>
- Check PHP error logs: <code>/var/log/php/</code><br>
- Check upload logs: <code>/uploads/uploads.log</code><br>
- Verify directory permissions: <code>ls -la uploads/</code>
</p>
</body>
</html>';
?>
