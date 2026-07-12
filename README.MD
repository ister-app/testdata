# Test Data

Welcome to the Test Data repository for the Ister Media Server!

This repository contains test images generated using the [DeepAI Text-to-Image model](https://deepai.org/machine-learning-model/text2img).

### Contents
- The repository exclusively contains images.

### Creating MKV Files
To create MKV files from the images, simply run the `./create_mkv.sh` script. 
This script will utilize the background images as input to generate the corresponding MKV files.
If no background images are found it will create a yellow video stream MKV file.

### Creating Book Libraries
Run `./create_books.sh` to generate the `books/` library on node1/disk1 and node2/disk1. It creates:
- `Owl (1950)/Night Flight (2015).epub` — a plain epub, plus `Owl (1950)/Night Flight (2015)/` — the
  same book as an audiobook folder of zero-based numbered mp3 chapters (`000_Chapter_0.mp3`, …) with a `cover.jpg`.
- `Hedgehog/Winter Sleep.epub` — a plain epub.
- `Hedgehog/Spring Walk.epub` — an EPUB 3 **media-overlay** ("karaoke") epub: embedded mp3 audio (stored
  uncompressed), one SMIL file per chapter with `clipBegin`/`clipEnd` per sentence span and `media:duration`
  metadata. Deliberately named *without* a "(karaoke)" suffix — the server must detect overlays from the
  epub contents, never from the filename.

All generated book files are git-ignored, like the mkv/flac files.

### Serving a Test Podcast Feed
Run `./serve_podcast_feed.sh [port]` (default 8123) to generate a small RSS feed with three mp3
episodes and a cover, served with `python3 -m http.server`. Subscribe in the Ister app with the
printed feed URL (the server needs a `PODCAST` library configured). The generated `podcast-feed/`
directory is git-ignored.
