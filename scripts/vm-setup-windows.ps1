<#
.SYNOPSIS
  Prepare a Windows UTM VM as the private Tunnel origin (assignment step 4),
  without Docker: native go-httpbin on :8080 + cloudflared connector.

.DESCRIPTION
  1. Installs cloudflared (winget) if missing.
  2. Downloads the latest go-httpbin Windows binary and starts it on :8080.
  3. If -TunnelToken is supplied, installs cloudflared as a service with it.

  Run in an ELEVATED PowerShell. Get the token on your Mac with:
     cd fde-demo-lab/terraform && tofu output -raw tunnel_token

.EXAMPLE
  ./vm-setup-windows.ps1 -TunnelToken "eyJ..."
#>
param(
  [string]$TunnelToken = "",
  [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

Write-Host "==> Installing cloudflared (if missing)..."
if (-not (Get-Command cloudflared -ErrorAction SilentlyContinue)) {
  winget install --id Cloudflare.cloudflared --accept-source-agreements --accept-package-agreements
} else {
  Write-Host "    cloudflared already present."
}

Write-Host "==> Fetching latest go-httpbin Windows binary..."
$dest = Join-Path $env:USERPROFILE "go-httpbin"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$exe = Join-Path $dest "go-httpbin.exe"

if (-not (Test-Path $exe)) {
  $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/mccutchen/go-httpbin/releases/latest" `
    -Headers @{ "User-Agent" = "fde-demo" }
  $asset = $rel.assets | Where-Object { $_.name -match "windows" -and $_.name -match "amd64" } | Select-Object -First 1
  if (-not $asset) { throw "Could not find a windows/amd64 asset in the latest go-httpbin release." }
  $tmp = Join-Path $env:TEMP $asset.name
  Write-Host "    downloading $($asset.name)"
  Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tmp -Headers @{ "User-Agent" = "fde-demo" }
  if ($asset.name -match "\.zip$") {
    Expand-Archive -Path $tmp -DestinationPath $dest -Force
    $found = Get-ChildItem -Path $dest -Recurse -Filter "go-httpbin*.exe" | Select-Object -First 1
    if ($found) { Copy-Item $found.FullName $exe -Force }
  } elseif ($asset.name -match "\.tar\.gz$") {
    tar -xzf $tmp -C $dest
    $found = Get-ChildItem -Path $dest -Recurse -Filter "go-httpbin*.exe" | Select-Object -First 1
    if ($found) { Copy-Item $found.FullName $exe -Force }
  } else {
    Copy-Item $tmp $exe -Force
  }
}
if (-not (Test-Path $exe)) { throw "go-httpbin.exe not found after download." }

Write-Host "==> Starting go-httpbin on :$Port ..."
Get-Process go-httpbin -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $exe -ArgumentList "-port","$Port" -WindowStyle Hidden
Start-Sleep -Seconds 2
try {
  $r = Invoke-WebRequest -Uri "http://localhost:$Port/headers" -UseBasicParsing -TimeoutSec 5
  Write-Host "    httpbin OK ($($r.StatusCode)) on http://localhost:$Port/headers"
} catch {
  Write-Warning "    could not reach http://localhost:$Port/headers yet — check the go-httpbin window."
}

if ($TunnelToken -ne "") {
  Write-Host "==> Installing cloudflared service with the tunnel token..."
  cloudflared service install $TunnelToken
  Write-Host "    Done. Check: Zero Trust -> Networks -> Tunnels (fde-demo-tunnel Healthy)."
} else {
  Write-Host "==> No -TunnelToken given. When ready, run:"
  Write-Host "    cloudflared service install <TOKEN>"
}

Write-Host "==> Verify from anywhere:  curl https://tunnel.<zone>/headers"
