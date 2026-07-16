#!/bin/bash
# Generates a small podcast RSS feed (via create_podcast_feed.sh) and serves it on localhost, so the
# subscribe → refresh → download → play flow can be tested without internet.
#
# Usage: ./serve_podcast_feed.sh [port]     (default 8123)
# Then subscribe in the app with: http://<your-ip>:8123/feed.xml

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PORT="${1:-8123}"
BASE_URL="http://$(hostname -I | awk '{print $1}'):$PORT"

"$SCRIPT_DIR/create_podcast_feed.sh" "$BASE_URL"

echo "Feed:      $BASE_URL/feed.xml"
echo "Subscribe with that URL in the Ister app (server needs a PODCAST library configured)."
cd "$SCRIPT_DIR/podcast-feed" && python3 -m http.server "$PORT" --bind 0.0.0.0
