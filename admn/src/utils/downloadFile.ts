/**
 * Downloads any file (image, PDF, etc.) directly to the user's device.
 *
 * Strategy:
 *  1. Cross-origin URLs (Firebase Storage, Hostinger) are routed through the
 *     server-side PHP proxy at jenishaonlineservice.com/download_proxy.php
 *     which fetches the file and streams it with Content-Disposition: attachment.
 *  2. Same-origin blobs / data URLs are downloaded directly via a temporary <a>.
 *
 * The proxy bypasses all browser CORS restrictions — the file is always saved
 * to disk and never just opened in a new tab.
 */

const PROXY_BASE = 'https://jenishaonlineservice.com/uploads/download_proxy.php';

/** Hosts whose files must go through the server-side proxy. */
const CROSS_ORIGIN_HOSTS = [
  'firebasestorage.googleapis.com',
  'storage.googleapis.com',
  'jenishaonlineservice.com',
  'www.jenishaonlineservice.com',
];

function needsProxy(url: string): boolean {
  try {
    const { hostname } = new URL(url);
    return CROSS_ORIGIN_HOSTS.some(
      (h) => hostname === h || hostname.endsWith('.' + h),
    );
  } catch {
    return false;
  }
}

function deriveFilename(url: string, hint?: string): string {
  if (hint) return hint;
  try {
    const path = new URL(url).pathname;
    const seg = decodeURIComponent(path.split('/').pop() || 'file');
    return seg || 'file';
  } catch {
    return 'file';
  }
}

/** Trigger a real browser download from a same-origin Blob/object URL. */
function blobDownload(blobOrObjectUrl: string, filename: string): void {
  const a = document.createElement('a');
  a.href = blobOrObjectUrl;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
}

export async function downloadFile(url: string, filename?: string): Promise<void> {
  if (!url) return;

  const name = deriveFilename(url, filename);

  if (needsProxy(url)) {
    // ── Route through PHP proxy ──────────────────────────────────────────────
    // The proxy sets Content-Disposition: attachment so the browser downloads.
    const proxyUrl =
      PROXY_BASE +
      '?url=' +
      encodeURIComponent(url) +
      '&name=' +
      encodeURIComponent(name);

    try {
      const res = await fetch(proxyUrl);
      if (!res.ok) throw new Error(`Proxy returned HTTP ${res.status}`);

      const blob = await res.blob();
      const objectUrl = window.URL.createObjectURL(blob);
      blobDownload(objectUrl, name);
      setTimeout(() => window.URL.revokeObjectURL(objectUrl), 15_000);
    } catch (err) {
      console.error('Proxy download failed:', err);
      // Last-resort: open directly so admin can at least view / save manually
      window.open(url, '_blank', 'noopener,noreferrer');
    }
  } else {
    // ── Same-origin or data URL — direct download ────────────────────────────
    blobDownload(url, name);
  }
}
