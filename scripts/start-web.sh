#!/usr/bin/env bash
# Build the wasm bundle and serve it locally. Stops the server on Ctrl-C.
# Useful for iterative web-demo work; for a clean build run scripts/build-web.sh.
set -euo pipefail

cd "$(dirname "$0")/.."

PORT="${PORT:-8000}"
DIST=web/dist

./scripts/build-web.sh

URL="http://localhost:$PORT/"
echo "==> serving $DIST at $URL (Ctrl-C to stop)"

# Open the page in the default browser on macOS; ignore failures elsewhere.
if [[ "$(uname -s)" == "Darwin" ]]; then
    (sleep 0.5 && open "$URL") &
fi

exec python3 -m http.server -d "$DIST" "$PORT"
