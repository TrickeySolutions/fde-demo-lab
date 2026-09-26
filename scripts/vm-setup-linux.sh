#!/usr/bin/env bash
# Prepare a Linux VM (or the Mac host) as the private Tunnel origin
# (assignment step 4): dockerised go-httpbin on :8080 + cloudflared connector.
#
# Usage:  vm-setup-linux.sh <TUNNEL_TOKEN>
# Get the token on your Mac with:
#   cd fde-demo-lab/terraform && tofu output -raw tunnel_token
set -euo pipefail

TOKEN="${1:-}"
PORT="${PORT:-8080}"

echo "==> Starting go-httpbin on :${PORT} (Docker)..."
if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Install Docker Engine first: https://docs.docker.com/engine/install/" >&2
  exit 1
fi
docker rm -f httpbin >/dev/null 2>&1 || true
docker run -d --name httpbin -p "${PORT}:8080" mccutchen/go-httpbin
sleep 2
curl -fsS "http://localhost:${PORT}/headers" >/dev/null && \
  echo "    httpbin OK on http://localhost:${PORT}/headers"

echo "==> Installing cloudflared..."
if ! command -v cloudflared >/dev/null 2>&1; then
  echo "Install cloudflared: https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/" >&2
  echo "(e.g. macOS: brew install cloudflared)" >&2
fi

if [[ -n "$TOKEN" ]]; then
  echo "==> Installing cloudflared service with the tunnel token..."
  sudo cloudflared service install "$TOKEN"
  echo "    Done. Check Zero Trust -> Networks -> Tunnels (fde-demo-tunnel Healthy)."
else
  echo "==> No token given. When ready, run:  sudo cloudflared service install <TOKEN>"
fi

echo "==> Verify from anywhere:  curl https://tunnel.<zone>/headers"
