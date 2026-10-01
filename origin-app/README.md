# fde-demo-origin

A **tiny, dependency-free live-reload origin** for the FDE demo. It serves
`public/index.html` on `http://localhost:8080` and reloads every connected
browser the instant you save a file.

Point a **Cloudflare Tunnel** at `localhost:8080`, then edit
`public/index.html` and save — the change appears **across the public
internet** in real time, proving the origin is your own machine (no public IP,
no inbound ports).

## Run

```bash
node server.mjs           # http://localhost:8080
PORT=9000 node server.mjs # custom port
```

Node 18+ only — no `npm install`, no dependencies.

## Use in the demo

1. Start the tunnel connector on this machine (it already forwards
   `tunnel.<zone>` → `http://localhost:8080`).
2. `node server.mjs`.
3. Open `https://tunnel.<zone>/` — you'll see this page over the internet.
4. Edit the `<h1>` in `public/index.html`, save, and watch both the local page
   and the public URL reload with your new text.

## How it works

`server.mjs` (Node built-ins only):
- serves `./public` with sensible MIME types,
- injects a small Server-Sent-Events client into every HTML response,
- watches `./public` and pushes a `reload` event on any change,
- templates `{{HOSTNAME}}` and `{{RENDERED}}` so the page shows the real machine
  name and render time.

> Note: while this runs on `:8080`, the Cloudflare Tunnel serves it for all
> paths except `/secure*`, which the `fde-demo-secure` Worker route intercepts.
