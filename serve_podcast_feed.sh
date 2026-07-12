#!/bin/bash
# Generates a small podcast RSS feed (3 mp3 episodes, cover) and serves it on localhost, so the
# subscribe → refresh → download → play flow can be tested without internet.
#
# Usage: ./serve_podcast_feed.sh [port]     (default 8123)
# Then subscribe in the app with: http://<your-ip>:8123/feed.xml

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
PORT="${1:-8123}"
FEED_DIR="$SCRIPT_DIR/podcast-feed"
BASE_URL="http://$(hostname -I | awk '{print $1}'):$PORT"

mkdir -p "$FEED_DIR/audio"

# Cover
if [ ! -f "$FEED_DIR/cover.jpg" ]; then
    ffmpeg -f lavfi -i "color=size=600x600:color=indigo" -frames:v 1 "$FEED_DIR/cover.jpg" -loglevel error
fi

# Three episodes of spoken-word-ish audio
for i in 1 2 3; do
    file="$FEED_DIR/audio/episode_$i.mp3"
    if [ ! -f "$file" ]; then
        ffmpeg -f lavfi -i "sine=frequency=$((200 + i * 60)):duration=60" -ar 44100 -b:a 64k "$file" -loglevel error
        echo "Created $file"
    fi
done

# RSS feed with iTunes tags; pubDates spread over three days.
cat > "$FEED_DIR/feed.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
  <channel>
    <title>Ister Test Cast</title>
    <description>A locally served test podcast for Ister development.</description>
    <language>nl</language>
    <itunes:author>Ister Testdata</itunes:author>
    <itunes:image href="$BASE_URL/cover.jpg"/>
    <item>
      <title>Aflevering 3 — de nieuwste</title>
      <guid>ister-test-ep-3</guid>
      <description>De nieuwste aflevering.</description>
      <pubDate>$(date -R -d '-1 day' 2>/dev/null || date -R)</pubDate>
      <enclosure url="$BASE_URL/audio/episode_3.mp3" type="audio/mpeg" length="$(stat -c%s "$FEED_DIR/audio/episode_3.mp3")"/>
      <itunes:duration>60</itunes:duration>
      <itunes:episode>3</itunes:episode>
    </item>
    <item>
      <title>Aflevering 2</title>
      <guid>ister-test-ep-2</guid>
      <description>De middelste aflevering.</description>
      <pubDate>$(date -R -d '-2 days' 2>/dev/null || date -R)</pubDate>
      <enclosure url="$BASE_URL/audio/episode_2.mp3" type="audio/mpeg" length="$(stat -c%s "$FEED_DIR/audio/episode_2.mp3")"/>
      <itunes:duration>60</itunes:duration>
      <itunes:episode>2</itunes:episode>
    </item>
    <item>
      <title>Aflevering 1</title>
      <guid>ister-test-ep-1</guid>
      <description>De oudste aflevering.</description>
      <pubDate>$(date -R -d '-3 days' 2>/dev/null || date -R)</pubDate>
      <enclosure url="$BASE_URL/audio/episode_1.mp3" type="audio/mpeg" length="$(stat -c%s "$FEED_DIR/audio/episode_1.mp3")"/>
      <itunes:duration>60</itunes:duration>
      <itunes:episode>1</itunes:episode>
    </item>
  </channel>
</rss>
EOF

echo "Feed:      $BASE_URL/feed.xml"
echo "Subscribe with that URL in the Ister app (server needs a PODCAST library configured)."
cd "$FEED_DIR" && python3 -m http.server "$PORT" --bind 0.0.0.0
