<?php
/**
 * download_proxy.php
 *
 * Fetches a remote file (Firebase Storage or Hostinger upload URL) and
 * streams it to the browser as a forced download, bypassing client-side CORS.
 *
 * Usage: GET /download_proxy.php?url=<encoded-url>&name=<optional-filename>
 *
 * Security: only URLs from whitelisted domains are allowed.
 */

// ── CORS: allow the admin panel origin ───────────────────────────────────────
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// ── Input validation ─────────────────────────────────────────────────────────
$url = isset($_GET['url']) ? trim($_GET['url']) : '';

if (empty($url)) {
    http_response_code(400);
    echo json_encode(['error' => 'Missing url parameter']);
    exit();
}

// Decode in case it was double-encoded
$url = urldecode($url);

// ── Whitelist: only allow these origins ──────────────────────────────────────
$allowedHosts = [
    'firebasestorage.googleapis.com',
    'storage.googleapis.com',
    'jenishaonlineservice.com',
    'www.jenishaonlineservice.com',
];

$parsedHost = parse_url($url, PHP_URL_HOST);

$allowed = false;
foreach ($allowedHosts as $host) {
    if ($parsedHost === $host || str_ends_with($parsedHost, '.' . $host)) {
        $allowed = true;
        break;
    }
}

if (!$allowed) {
    http_response_code(403);
    echo json_encode(['error' => 'URL origin not permitted']);
    exit();
}

// ── Derive filename ───────────────────────────────────────────────────────────
$customName = isset($_GET['name']) ? basename($_GET['name']) : '';
if (empty($customName)) {
    // Strip query string then take last path segment
    $path = parse_url($url, PHP_URL_PATH);
    $customName = basename($path);
    if (empty($customName)) {
        $customName = 'download';
    }
}
// Sanitise
$customName = preg_replace('/[^a-zA-Z0-9._\-]/', '_', $customName);

// ── Fetch the remote file ────────────────────────────────────────────────────
$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_MAXREDIRS      => 5,
    CURLOPT_TIMEOUT        => 60,
    CURLOPT_SSL_VERIFYPEER => true,
    CURLOPT_USERAGENT      => 'JenishaDownloadProxy/1.0',
    CURLOPT_HEADER         => true,       // include response headers so we can read Content-Type
]);

$response   = curl_exec($ch);
$httpCode   = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$headerSize = curl_getinfo($ch, CURLINFO_HEADER_SIZE);
$error      = curl_error($ch);
curl_close($ch);

if ($response === false || $error) {
    http_response_code(502);
    echo json_encode(['error' => 'Failed to fetch file: ' . $error]);
    exit();
}

if ($httpCode !== 200) {
    http_response_code(502);
    echo json_encode(['error' => "Remote returned HTTP $httpCode"]);
    exit();
}

// Separate headers and body
$remoteHeaders = substr($response, 0, $headerSize);
$body          = substr($response, $headerSize);

// Extract Content-Type from remote response
$contentType = 'application/octet-stream';
if (preg_match('/^Content-Type:\s*([^\r\n]+)/im', $remoteHeaders, $m)) {
    $contentType = trim($m[1]);
}

// ── Stream the file to the client ─────────────────────────────────────────────
header('Content-Type: ' . $contentType);
header('Content-Disposition: attachment; filename="' . $customName . '"');
header('Content-Length: ' . strlen($body));
header('Cache-Control: no-cache, no-store, must-revalidate');
header('Pragma: no-cache');
header('Expires: 0');

echo $body;
exit();
