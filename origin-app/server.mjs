/**
 * fde-demo-origin — a tiny, dependency-free live-reload origin.
 *
 * Serves ./public on http://localhost:<PORT> (default 8080) and reloads every
 * connected browser the instant a file changes. Point a Cloudflare Tunnel at
 * localhost:8080 and edit public/index.html live — the change appears across
 * the public internet, proving the origin is your own machine.
 *
 *   node server.mjs            # port 8080
 *   PORT=9000 node server.mjs  # custom port
 *
 * Node built-ins only — no npm install, nothing to go wrong on stage.
 */
import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { watch } from "node:fs";
import { extname, join, normalize, sep } from "node:path";
import { fileURLToPath } from "node:url";
import { dirname } from "node:path";
import os from "node:os";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "public");
const PORT = Number(process.env.PORT) || 8080;

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".ico": "image/x-icon",
  ".json": "application/json; charset=utf-8",
  ".txt": "text/plain; charset=utf-8",
};

// ── Live-reload: hold open SSE connections, ping them on any file change ──
const clients = new Set();
const LIVE_RELOAD = `
<script>
  (function () {
    const es = new EventSource("/__livereload");
    es.onmessage = function (e) { if (e.data === "reload") location.reload(); };
  })();
</script>`;

let debounce;
watch(ROOT, { recursive: true }, () => {
  clearTimeout(debounce);
  debounce = setTimeout(() => {
    for (const res of clients) res.write("data: reload\n\n");
  }, 80);
});

function template(html) {
  return html
    .replaceAll("{{HOSTNAME}}", os.hostname())
    .replaceAll("{{RENDERED}}", new Date().toISOString());
}

const server = createServer(async (req, res) => {
  // Echo the incoming request headers (httpbin-style) — handy to show the
  // Cf-* headers Cloudflare adds when this origin is reached via the tunnel.
  if ((req.url || "").split("?")[0] === "/headers") {
    const headers = {};
    for (const [k, v] of Object.entries(req.headers)) headers[k] = Array.isArray(v) ? v.join(", ") : v;
    res.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    res.end(JSON.stringify({ method: req.method, url: req.url, host: os.hostname(), headers }, null, 2));
    return;
  }

  // Server-Sent Events stream for live reload.
  if (req.url === "/__livereload") {
    res.writeHead(200, {
      "content-type": "text/event-stream",
      "cache-control": "no-cache",
      connection: "keep-alive",
    });
    res.write("retry: 1000\n\n");
    clients.add(res);
    req.on("close", () => clients.delete(res));
    return;
  }

  // Resolve the path safely inside ROOT.
  const urlPath = decodeURIComponent((req.url || "/").split("?")[0]);
  let rel = normalize(urlPath).replace(/^(\.\.[/\\])+/, "");
  if (rel.endsWith("/") || rel === "") rel += "index.html";
  const filePath = join(ROOT, rel);
  if (!filePath.startsWith(ROOT + sep) && filePath !== join(ROOT, "index.html")) {
    res.writeHead(403).end("Forbidden");
    return;
  }

  try {
    const info = await stat(filePath);
    if (info.isDirectory()) throw new Error("dir");
    const ext = extname(filePath).toLowerCase();
    const type = MIME[ext] || "application/octet-stream";
    let body = await readFile(filePath);
    if (ext === ".html") {
      body = Buffer.from(template(body.toString("utf8")) + LIVE_RELOAD);
    }
    res.writeHead(200, { "content-type": type, "cache-control": "no-store" });
    res.end(body);
  } catch {
    res.writeHead(404, { "content-type": "text/html; charset=utf-8" });
    res.end(`<h1>404</h1><p>${rel} not found in /public</p>` + LIVE_RELOAD);
  }
});

server.listen(PORT, () => {
  console.log(`\n  fde-demo-origin — serving ./public`);
  console.log(`  Local:   http://localhost:${PORT}/`);
  console.log(`  Host:    ${os.hostname()}`);
  console.log(`  Live-reload ON — edit public/index.html and save.\n`);
});
