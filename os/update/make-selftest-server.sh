#!/usr/bin/env bash
# Prepare a fake "GitHub releases" directory for the in-VM update self-test:
#   <dir>/releases.json, <dir>/SHA256SUMS, <dir>/alhajda-update-<v>.tar.gz
# The VM reaches the host's http server at 10.0.2.2 (QEMU user networking).
# Usage: os/update/make-selftest-server.sh <dir> [version] [port] [host-as-seen-by-guest]
set -euo pipefail
DIR="$1"; V="${2:-99.0.0}"; PORT="${3:-8099}"; HOST="${4:-10.0.2.2}"
mkdir -p "$DIR"
OUT="$DIR" ALHAJDA_VERSION="$V" bash "$(dirname "$0")/build-update-bundle.sh" --selftest
( cd "$DIR" && sha256sum "alhajda-update-${V}.tar.gz" > SHA256SUMS )
BASE="http://${HOST}:${PORT}"
cat > "$DIR/releases.json" <<JSON
[
  {"tag_name": "os-v0.0.1", "draft": false, "assets": []},
  {"tag_name": "os-v${V}", "draft": false, "prerelease": true, "assets": [
    {"name": "alhajda-update-${V}.tar.gz", "browser_download_url": "${BASE}/alhajda-update-${V}.tar.gz"},
    {"name": "SHA256SUMS", "browser_download_url": "${BASE}/SHA256SUMS"}
  ]}
]
JSON
python3 -m json.tool "$DIR/releases.json" >/dev/null
echo "selftest api: ${BASE}/releases.json"
