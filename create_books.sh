#!/bin/bash
# Generates the book test libraries: plain epubs, audiobook folders (numbered mp3s) and
# EPUB 3 media-overlay ("karaoke") epubs with embedded audio + SMIL timing.
# Like create_mkv.sh, all media is generated locally and never committed.

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Creates a cover jpg (solid color with the title burned in) if it doesn't exist.
create_cover () {
    local file="$1"
    local color="$2"
    if [ ! -f "$file" ]; then
        ffmpeg -f lavfi -i "color=size=600x900:color=$color" -frames:v 1 "$file" -loglevel error
        echo "Created file: $file"
    fi
}

# Creates a spoken-word-ish mp3 of the given duration (sine sweep) if it doesn't exist.
create_audio () {
    local file="$1"
    local duration="$2"
    if [ ! -f "$file" ]; then
        ffmpeg -f lavfi -i "sine=frequency=330:duration=$duration" -ar 44100 -b:a 64k "$file" -loglevel error
        echo "Created file: $file"
    fi
}

# Writes one chapter xhtml with sentence spans (ids par_0..par_4) used by the SMIL overlays.
write_chapter_xhtml () {
    local file="$1"
    local title="$2"
    cat > "$file" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
<head><title>$title</title></head>
<body>
<h1 id="par_0">$title</h1>
<p><span id="par_1">This is the first sentence of $title.</span>
<span id="par_2">Here is the second sentence, a bit longer than the first one.</span>
<span id="par_3">The third sentence carries the story onward.</span>
<span id="par_4">And the fourth sentence closes the chapter.</span></p>
</body>
</html>
EOF
}

# Builds an epub. With overlays: 2s of audio per sentence span (5 spans = 10s per chapter),
# a SMIL file per chapter and media:duration/media-overlay entries in the OPF.
# Usage: create_epub <output.epub> <title> <author> <year> <chapters> <with_overlays>
create_epub () {
    local output="$1"
    local title="$2"
    local author="$3"
    local year="$4"
    local chapters="$5"
    local with_overlays="$6"

    if [ -f "$output" ]; then
        echo "File already exists: $output"
        return
    fi

    local work
    work=$(mktemp -d)
    mkdir -p "$work/META-INF" "$work/OEBPS"

    printf 'application/epub+zip' > "$work/mimetype"

    cat > "$work/META-INF/container.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
EOF

    create_cover "$work/OEBPS/cover.jpg" "steelblue"

    local manifest="" spine="" durations=""
    for i in $(seq -w 1 "$chapters"); do
        write_chapter_xhtml "$work/OEBPS/chapter_$i.xhtml" "Chapter $i"
        if [ "$with_overlays" = "true" ]; then
            mkdir -p "$work/OEBPS/audio"
            create_audio "$work/OEBPS/audio/chapter_$i.mp3" 10
            cat > "$work/OEBPS/chapter_$i.smil" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<smil xmlns="http://www.w3.org/ns/SMIL" xmlns:epub="http://www.idpf.org/2007/ops" version="3.0">
  <body>
    <seq id="seq_$i" epub:textref="chapter_$i.xhtml" epub:type="chapter">
$(for p in 0 1 2 3 4; do
    begin=$((p * 2)); end=$(((p + 1) * 2))
    echo "      <par id=\"par_${i}_$p\"><text src=\"chapter_$i.xhtml#par_$p\"/><audio src=\"audio/chapter_$i.mp3\" clipBegin=\"$begin.000s\" clipEnd=\"$end.000s\"/></par>"
done)
    </seq>
  </body>
</smil>
EOF
            manifest="$manifest    <item id=\"chapter_$i\" href=\"chapter_$i.xhtml\" media-type=\"application/xhtml+xml\" media-overlay=\"smil_$i\"/>\n"
            manifest="$manifest    <item id=\"smil_$i\" href=\"chapter_$i.smil\" media-type=\"application/smil+xml\"/>\n"
            manifest="$manifest    <item id=\"audio_$i\" href=\"audio/chapter_$i.mp3\" media-type=\"audio/mpeg\"/>\n"
            durations="$durations    <meta property=\"media:duration\" refines=\"#smil_$i\">0:00:10.000</meta>\n"
        else
            manifest="$manifest    <item id=\"chapter_$i\" href=\"chapter_$i.xhtml\" media-type=\"application/xhtml+xml\"/>\n"
        fi
        spine="$spine    <itemref idref=\"chapter_$i\"/>\n"
    done

    local total_duration=""
    if [ "$with_overlays" = "true" ]; then
        total_seconds=$((10#$chapters * 10))
        total_duration="    <meta property=\"media:duration\">0:00:$(printf '%02d' $total_seconds).000</meta>\n$durations"
    fi

    cat > "$work/OEBPS/content.opf" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:identifier id="uid">urn:uuid:$(cat /proc/sys/kernel/random/uuid)</dc:identifier>
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
    <dc:language>en</dc:language>
    <dc:date>$year-01-01</dc:date>
    <dc:description>A generated test book called $title by $author.</dc:description>
    <meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>
$(printf "%b" "$total_duration")  </metadata>
  <manifest>
    <item id="cover-image" href="cover.jpg" media-type="image/jpeg" properties="cover-image"/>
$(printf "%b" "$manifest")  </manifest>
  <spine>
$(printf "%b" "$spine")  </spine>
</package>
EOF

    # mimetype must be the first entry and stored uncompressed; audio is stored too so the
    # server's Range fast path for STORED entries gets exercised.
    (cd "$work" && zip -X -0 -q book.zip mimetype)
    if [ -d "$work/OEBPS/audio" ]; then
        (cd "$work" && zip -rq -0 book.zip OEBPS/audio)
    fi
    (cd "$work" && zip -rq book.zip META-INF OEBPS -x "OEBPS/audio/*")
    mv "$work/book.zip" "$output"
    rm -rf "$work"
    echo "Created file: $output"
}

# Creates an audiobook folder of numbered mp3 chapters (zero-based, underscore separated,
# matching real-world audiobook rips) + cover.jpg.
create_audiobook () {
    local book_dir="$1"
    mkdir -p "$book_dir"
    create_cover "$book_dir/cover.jpg" "darkolivegreen"
    for i in $(seq -w 0 5); do
        create_audio "$book_dir/00${i}_Chapter_$i.mp3" 30
    done
}

create_books_structure () {
    local books_dir="$1"
    echo "Processing Books: $books_dir"

    # Author with birth year: one book available as epub AND audiobook folder (same book name).
    local owl_dir="$books_dir/Owl (1950)"
    mkdir -p "$owl_dir"
    create_epub "$owl_dir/Night Flight (2015).epub" "Night Flight" "Owl" 2015 3 false
    create_audiobook "$owl_dir/Night Flight (2015)"

    # Author without year: a plain epub, and a media-overlay epub WITHOUT any "(karaoke)"
    # suffix — overlay detection must come from the epub contents, not the filename.
    local hedgehog_dir="$books_dir/Hedgehog"
    mkdir -p "$hedgehog_dir"
    create_epub "$hedgehog_dir/Winter Sleep.epub" "Winter Sleep" "Hedgehog" 2020 3 false
    create_epub "$hedgehog_dir/Spring Walk.epub" "Spring Walk" "Hedgehog" 2021 3 true
}

create_books_structure "$SCRIPT_DIR/node1/disk1/books"
create_books_structure "$SCRIPT_DIR/node2/disk1/books"
