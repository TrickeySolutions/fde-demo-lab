#!/usr/bin/env bash
# Upload country flag SVGs to the PRIVATE R2 bucket (assignment step 7d).
#
# Objects are keyed by lowercase ISO 3166-1 alpha-2 code, e.g. gb.svg, us.svg,
# so the Worker can look them up as `${country}.svg`. Flags are pulled from
# flagcdn.com (SVG) unless a matching file already exists in assets/flags/.
#
# Usage:
#   scripts/upload-flags.sh [--local] [CODE ...]
#     --local     seed the local wrangler dev R2 (for `wrangler dev`), not remote
#     CODE ...    country codes to upload (default: a representative set)
#
# Requires (for remote uploads):
#   export CLOUDFLARE_API_TOKEN="<token with Workers R2 edit>"
#   export CLOUDFLARE_ACCOUNT_ID="<account id>"
set -euo pipefail
cd "$(dirname "$0")/.."

BUCKET="${FLAGS_BUCKET:-fde-demo-flags}"
# Default to the REAL (remote) bucket; wrangler's r2 object commands otherwise
# operate on the local miniflare store. Pass --local to target local dev.
LOC_FLAG="--remote"
CODES=()

for arg in "$@"; do
  case "$arg" in
    --local) LOC_FLAG="--local" ;;
    *) CODES+=("$arg") ;;
  esac
done

# Default set: common demo origins + a spread of continents.
if [[ ${#CODES[@]} -eq 0 ]]; then
  CODES=(gb us ie fr de es it nl pt au nz ca in sg jp br za ae)
fi

WRANGLER=(npx wrangler)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

for code in "${CODES[@]}"; do
  code=$(echo "$code" | tr '[:upper:]' '[:lower:]')
  src="assets/flags/${code}.svg"
  file="$TMP/${code}.svg"
  if [[ -f "$src" ]]; then
    cp "$src" "$file"
  else
    echo "Fetching ${code}.svg from flagcdn.com ..."
    curl -fsSL "https://flagcdn.com/${code}.svg" -o "$file" || {
      echo "  ! no flag for '${code}', skipping"; continue; }
  fi
  echo "Uploading ${code}.svg -> ${BUCKET} (${LOC_FLAG})"
  "${WRANGLER[@]}" r2 object put "${BUCKET}/${code}.svg" \
    --file="$file" --content-type="image/svg+xml" "$LOC_FLAG"
done

echo "Done. Uploaded ${#CODES[@]} flag(s) to ${BUCKET} (${LOC_FLAG})."
