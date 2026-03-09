<?php
/**
 * Simple Test Upload Endpoint
 * Used to verify upload functionality with a test image
 */

set_time_limit(300);
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// GET - Return test form
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    header('Content-Type: text/html');
    echo '<!DOCTYPE html>
<html>
<head>
    <title>Upload Test</title>
    <style>
        body { font-family: Arial; margin: 20px; background: #f5f5f5; }
        .container { max-width: 500px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        input, button { padding: 10px; margin: 10px 0; width: 100%; box-sizing: border-box; }
        button { background: #243BFF; color: white; border: none; border-radius: 4px; cursor: pointer; }
        .result { padding: 10px; margin-top: 10px; background: #f0f0f0; border-radius: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📤 Upload Test</h1>
        <form id="uploadForm">
            <input type="text" id="userId" placeholder="User ID" value="test-' . date('Ymd-His') . '" required>
            <input type="text" id="documentId" placeholder="Document ID" value="test-doc" required>
            <input type="file" id="file" accept="image/*" required>
            <button type="submit">Upload Test</button>
        </form>
        <div id="result"></div>
    </div>
    
    <script>
        document.getElementById("uploadForm").addEventListener("submit", async (e) => {
            e.preventDefault();
            const form = new FormData();
            form.append("userId", document.getElementById("userId").value);
            form.append("documentId", document.getElementById("documentId").value);
            form.append("file", document.getElementById("file").files[0]);
            
            try {
                const res = await fetch(window.location.href, {
                    method: "POST",
                    body: form
                });
                const data = await res.json();
                document.getElementById("result").innerHTML = "<pre>" + JSON.stringify(data, null, 2) + "</pre>";
            } catch(e) {
                document.getElementById("result").innerHTML = "<pre>" + e.toString() + "</pre>";
            }
        });
    </script>
</body>
</html>';
    exit;
}

// POST - Handle upload
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Method not allowed']);
    exit;
}

try {
    if (!isset($_POST['userId'])) throw new Exception('Missing userId');
    if (!isset($_POST['documentId'])) throw new Exception('Missing documentId');
    if (!isset($_FILES['file'])) throw new Exception('Missing file');

    $userId = preg_replace('/[^a-zA-Z0-9_\-]/', '', $_POST['userId']);
    $documentId = preg_replace('/[^a-zA-Z0-9_\-]/', '', $_POST['documentId']);
    $file = $_FILES['file'];

    if ($file['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('Upload error: ' . $file['error']);
    }

    $dir = __DIR__ . '/users/' . $userId . '/';
    @mkdir($dir, 0777, true);

    $filename = $documentId . '.' . strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    $path = $dir . $filename;

    if (!move_uploaded_file($file['tmp_name'], $path)) {
        throw new Exception('Failed to move file');
    }

    @chmod($path, 0644);

    $protocol = (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') ? 'https://' : 'http://';
    $imageUrl = $protocol . $_SERVER['HTTP_HOST'] . '/uploads/users/' . $userId . '/' . $filename;

    echo json_encode([
        'success' => true,
        'imageUrl' => $imageUrl,
        'message' => 'Upload successful'
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
?>
