<?php
/**
 * Comprehensive Upload Test Suite
 * Access: https://your-domain.com/uploads/test_suite.php
 * 
 * Tests:
 * - GET: Shows test form
 * - POST with file: Performs upload test
 * - GET ?action=simulate: Simulates Flutter upload with curl
 * - GET ?action=check: Lists all uploaded files
 */

error_reporting(E_ALL);
ini_set('display_errors', 1);

$uploadDir = __DIR__ . '/users';
$testLog = __DIR__ . '/test.log';

function writeLog($msg) {
    global $testLog;
    file_put_contents($testLog, date('Y-m-d H:i:s') . " - $msg\n", FILE_APPEND);
}

// Test 1: Directory structure
if (isset($_GET['action']) && $_GET['action'] === 'check') {
    header('Content-Type: application/json');
    
    $result = [
        'timestamp' => date('Y-m-d H:i:s'),
        'directories' => [],
        'files' => [],
        'errors' => [],
    ];
    
    if (!is_dir($uploadDir)) {
        $result['errors'][] = "/uploads/users directory missing";
    } else {
        // List user directories
        $userDirs = glob($uploadDir . '/*', GLOB_ONLYDIR);
        foreach ($userDirs as $dir) {
            $userId = basename($dir);
            $files = glob($dir . '/*');
            $result['directories'][$userId] = [
                'count' => count($files),
                'permissions' => substr(sprintf('%o', fileperms($dir)), -4),
                'writable' => is_writable($dir),
                'files' => array_map('basename', $files),
            ];
        }
    }
    
    echo json_encode($result, JSON_PRETTY_PRINT);
    exit;
}

// Test 2: Simulate Flutter upload with curl
if (isset($_GET['action']) && $_GET['action'] === 'simulate') {
    header('Content-Type: text/plain');
    
    echo "=== SIMULATING FLUTTER UPLOAD ===\n\n";
    
    // Create temp test file
    $testImageFile = tempnam(sys_get_temp_dir(), 'test_');
    $testImageData = base64_decode(
        '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAABAAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAAA//EABQAQAAAAAAAAAAAAAAAAAAAAD/2gAMAwEAAgEDEQA/AI+AAAH/9k='
    );
    file_put_contents($testImageFile, $testImageData);
    
    // Test upload
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => 'https://' . $_SERVER['HTTP_HOST'] . '/uploads/upload.php',
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => [
            'userId' => 'test_' . time(),
            'documentId' => 'adhaar',
            'file' => '@' . $testImageFile,
        ],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_SSL_VERIFYHOST => false,
        CURLOPT_TIMEOUT => 60,
        CURLOPT_VERBOSE => true,
    ]);
    
    $verbose = fopen('php://temp', 'w+');
    curl_setopt($ch, CURLOPT_STDERR, $verbose);
    
    $response = curl_exec($ch);
    $info = curl_getinfo($ch);
    $error = curl_error($ch);
    
    rewind($verbose);
    $verboseOutput = stream_get_contents($verbose);
    
    curl_close($ch);
    @unlink($testImageFile);
    
    echo "HTTP Status: " . $info['http_code'] . "\n";
    echo "Content-Type: " . $info['content_type'] . "\n";
    echo "Response Time: " . $info['total_time'] . "s\n\n";
    
    if ($error) {
        echo "CURL Error: $error\n\n";
    }
    
    echo "Response:\n";
    echo $response . "\n\n";
    
    echo "Verbose Output (first 500 chars):\n";
    echo substr($verboseOutput, 0, 500) . "\n";
    
    writeLog("Simulate test - Status: " . $info['http_code'] . ", Response: " . substr($response, 0, 100));
    
    exit;
}

// Test 3: POST form upload
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['testFile'])) {
    header('Content-Type: application/json');
    
    $userId = 'test_' . time();
    $documentId = 'manual_' . time();
    
    $result = [];
    
    // Step 1: Check $_FILES
    $result['step1_files_received'] = isset($_FILES['testFile']);
    $result['step1_file_size'] = $_FILES['testFile']['size'] ?? 0;
    $result['step1_file_error'] = $_FILES['testFile']['error'] ?? -1;
    
    // Step 2: Call upload.php
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => 'https://' . $_SERVER['HTTP_HOST'] . '/uploads/upload.php',
        CURLOPT_POST => true,
        CURLOPT_SAFE_UPLOAD => true,
        CURLOPT_POSTFIELDS => [
            'userId' => $userId,
            'documentId' => $documentId,
            'file' => curl_file_create(
                $_FILES['testFile']['tmp_name'],
                $_FILES['testFile']['type'],
                $_FILES['testFile']['name']
            ),
        ],
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_SSL_VERIFYPEER => false,
        CURLOPT_TIMEOUT => 60,
    ]);
    
    $response = curl_exec($ch);
    $info = curl_getinfo($ch);
    $error = curl_error($ch);
    
    curl_close($ch);
    
    $result['step2_http_status'] = $info['http_code'];
    $result['step2_response'] = json_decode($response, true);
    
    if ($error) {
        $result['step2_curl_error'] = $error;
    }
    
    writeLog("Web form upload - userId: $userId, Status: " . $info['http_code']);
    
    echo json_encode($result, JSON_PRETTY_PRINT);
    exit;
}

// Default: Show test form
?>
<!DOCTYPE html>
<html>
<head>
    <title>Upload Test Suite</title>
    <style>
        body { font-family: sans-serif; margin: 20px; }
        .test { border: 1px solid #ccc; padding: 15px; margin: 10px 0; }
        .test h3 { margin-top: 0; }
        button { padding: 8px 15px; background: #007bff; color: white; border: none; cursor: pointer; }
        button:hover { background: #0056b3; }
        pre { background: #f5f5f5; padding: 10px; overflow: auto; max-height: 300px; }
        .success { color: green; }
        .error { color: red; }
    </style>
</head>
<body>
    <h1>Upload Test Suite</h1>
    
    <div class="test">
        <h3>Test 1: Check Server Status</h3>
        <p>Checks PHP config, directory structure, permissions, and file counts</p>
        <button onclick="window.location='/uploads/status.php'">View Status</button>
    </div>
    
    <div class="test">
        <h3>Test 2: List All Uploads</h3>
        <p>Shows all user directories and files that have been uploaded</p>
        <button onclick="checkUploads()">Check Uploads</button>
        <pre id="checkResult"></pre>
    </div>
    
    <div class="test">
        <h3>Test 3: Web Form Upload</h3>
        <p>Upload a test image using HTML form (exactly like browser would)</p>
        <form method="POST" enctype="multipart/form-data">
            <input type="file" name="testFile" accept="image/*" required>
            <button type="submit">Upload Test Image</button>
        </form>
        <pre id="uploadResult"></pre>
    </div>
    
    <div class="test">
        <h3>Test 4: Simulate Flutter Upload</h3>
        <p>Uses curl to simulate exact Flutter upload with timeout and retry logic</p>
        <button onclick="simulateFlutter()">Simulate Flutter Upload</button>
        <pre id="simulateResult"></pre>
    </div>
    
    <script>
        function checkUploads() {
            fetch('/uploads/test_suite.php?action=check')
                .then(r => r.json())
                .then(data => {
                    document.getElementById('checkResult').textContent = JSON.stringify(data, null, 2);
                })
                .catch(err => {
                    document.getElementById('checkResult').textContent = 'Error: ' + err;
                });
        }
        
        function simulateFlutter() {
            document.getElementById('simulateResult').textContent = 'Loading...';
            fetch('/uploads/test_suite.php?action=simulate')
                .then(r => r.text())
                .then(text => {
                    document.getElementById('simulateResult').textContent = text;
                })
                .catch(err => {
                    document.getElementById('simulateResult').textContent = 'Error: ' + err;
                });
        }
    </script>
</body>
</html>
