const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 5000;
const HOST = '0.0.0.0';
const ROOT = path.join(__dirname, 'build', 'web');

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.webp': 'image/webp',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.wasm': 'application/wasm',
  '.map': 'application/json; charset=utf-8',
};

// Extensions that should get a 404 (not HTML fallback) when missing.
// Returning HTML for these causes "Unexpected token '<'" JS parse errors
// in the service worker and CanvasKit loader.
const ASSET_EXTS = new Set([
  '.js', '.mjs', '.css', '.wasm', '.map',
  '.png', '.jpg', '.jpeg', '.gif', '.svg',
  '.ico', '.webp', '.woff', '.woff2', '.ttf', '.otf',
  '.json',
]);

function send(res, status, headers, body) {
  res.writeHead(status, {
    'Cache-Control': 'no-store, no-cache, must-revalidate, max-age=0',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'credentialless',
    ...headers,
  });
  res.end(body);
}

const server = http.createServer((req, res) => {
  try {
    let urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
    if (urlPath === '/') urlPath = '/index.html';
    let filePath = path.join(ROOT, urlPath);

    if (!filePath.startsWith(ROOT)) {
      return send(res, 403, { 'Content-Type': 'text/plain' }, 'Forbidden');
    }

    const ext = path.extname(filePath).toLowerCase();

    fs.stat(filePath, (err, stat) => {
      if (err || !stat.isFile()) {
        // For asset files (JS, WASM, etc.) return a real 404 so the
        // browser/service-worker doesn't try to execute HTML as JavaScript.
        if (ASSET_EXTS.has(ext)) {
          return send(res, 404, { 'Content-Type': 'text/plain' }, 'Not Found');
        }
        // For navigation requests (no extension or .html) fall back to the
        // Flutter app shell so client-side routing works.
        filePath = path.join(ROOT, 'index.html');
      }

      const resolvedExt = path.extname(filePath).toLowerCase();
      const type = MIME[resolvedExt] || 'application/octet-stream';
      fs.readFile(filePath, (err2, data) => {
        if (err2) {
          return send(res, 500, { 'Content-Type': 'text/plain' }, 'Internal Server Error');
        }
        send(res, 200, { 'Content-Type': type }, data);
      });
    });
  } catch (e) {
    send(res, 500, { 'Content-Type': 'text/plain' }, 'Internal Server Error');
  }
});

server.listen(PORT, HOST, () => {
  console.log(`YS Trackify Flutter Web serving on http://${HOST}:${PORT}`);
  console.log(`Document root: ${ROOT}`);
});
