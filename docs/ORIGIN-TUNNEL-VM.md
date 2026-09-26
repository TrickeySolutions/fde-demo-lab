# Origin B — local VM + Cloudflare Tunnel (assignment step 4)

This is the **private** origin, reached only through a **Cloudflare Tunnel**.
There is no public inbound and no origin IP to bypass — the connector
(`cloudflared`) dials out to Cloudflare. This satisfies step 4 and the "nobody
can bypass Cloudflare" half of step 6 automatically.

Helper scripts (copy them into the VM and run there):
- Windows: `scripts/vm-setup-windows.ps1`
- Linux:   `scripts/vm-setup-linux.sh`

The tunnel + its ingress are already created by Terraform
(`terraform/50-tunnel.tf`); ingress forwards `tunnel.<zone>` →
`var.tunnel_service` (default `http://localhost:8080`). So on the VM you only
need: (a) httpbin listening on **8080**, and (b) `cloudflared` running with the
tunnel token.

---

## Read this first — Docker inside a nested Windows VM

You asked whether you can "just run Docker on the Windows UTM VM". Honest answer:
**often not cleanly.** Docker Desktop on Windows needs **WSL2**, which needs
**nested virtualization**. A Windows guest running under UTM/QEMU on Apple
Silicon frequently cannot enable that, so Docker Desktop fails to start. Rather
than fight it, pick one of these (all satisfy the assignment equally):

| Option | Host | httpbin | When to use |
| --- | --- | --- | --- |
| **A (recommended)** | your existing **Windows** UTM VM | native `go-httpbin.exe` (no Docker) | you want to keep the Windows VM; single .exe, zero virtualization |
| **B** | a small **Linux** UTM VM | Docker `go-httpbin` | you're happy to spin up a Linux guest; Docker runs natively there |
| **C** | the **Mac host** directly | Docker `go-httpbin` | fastest to demo; skips the VM (less "private network" story) |

Docker itself is not a requirement of the assignment — only "an origin reachable
through a Tunnel". `go-httpbin` is a single static binary, which is why Option A
is the least fragile on your current setup.

---

## Step 1 — get the connector token (on your Mac)
After `tofu apply` has created the tunnel:
```bash
cd fde-demo-lab/terraform && tofu output -raw tunnel_token
```
Copy that token to the VM. **Never commit it.**

## Step 2 — start httpbin on port 8080

### Option A — Windows, native binary (recommended)
In an **elevated PowerShell** on the VM:
```powershell
# from the repo copy on the VM, or paste the script in:
./vm-setup-windows.ps1 -TunnelToken "<PASTE_TOKEN>"
```
The script installs `cloudflared` (winget), downloads the latest
`go-httpbin` Windows binary, starts it on `:8080` as a background task, then
installs `cloudflared` as a service with your token. Manual equivalent:
```powershell
winget install --id Cloudflare.cloudflared
# download go-httpbin from https://github.com/mccutchen/go-httpbin/releases (windows amd64)
./go-httpbin.exe -port 8080          # leave running
cloudflared service install <PASTE_TOKEN>
```

### Option B — Linux VM, Docker
```bash
./vm-setup-linux.sh "<PASTE_TOKEN>"
# manual equivalent:
docker run -d --name httpbin -p 8080:8080 mccutchen/go-httpbin
curl http://localhost:8080/headers
sudo cloudflared service install <PASTE_TOKEN>
```

### Option C — Mac host, Docker
```bash
docker run -d --name httpbin -p 8080:8080 mccutchen/go-httpbin
cloudflared service install <PASTE_TOKEN>   # or: brew install cloudflared
```

> Self-signed / loopback is fine: the tunnel itself encrypts the hop to
> Cloudflare, so the origin needs no real cert (`no_tls_verify = true` in the
> ingress). Full-Strict is demonstrated separately on the Azure origin.

- httpbin image / binary: <https://github.com/mccutchen/go-httpbin>
- cloudflared install: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/>
- remotely-managed tunnels: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/remote-tunnel-permissions/>

## Step 3 — verify
```bash
# From anywhere on the internet, through Cloudflare:
curl -sS https://tunnel.<zone>/headers | jq .
```
- Dashboard: **Zero Trust → Networks → Tunnels** shows `fde-demo-tunnel`
  **Healthy** with one connector.

## How /secure coexists with the tunnel
`tunnel.<zone>` serves httpbin for normal paths (e.g. `/headers`). The
`/secure*` path is intercepted by the **Worker route** before it reaches the
tunnel origin:
- `tunnel.<zone>/headers` → httpbin (via tunnel)
- `tunnel.<zone>/secure`  → the identity Worker (behind Access)

Worker routes take precedence over the tunnel origin for matching patterns.
- <https://developers.cloudflare.com/workers/configuration/routing/routes/>

## Screenshots to capture for the report
- [ ] httpbin running on the VM (terminal / `docker ps`)
- [ ] `cloudflared` installed as a service / running
- [ ] Zero Trust → Networks → Tunnels: `fde-demo-tunnel` Healthy
- [ ] `curl https://tunnel.<zone>/headers` returning headers
