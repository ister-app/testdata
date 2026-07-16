#!/bin/bash
# Generates the comic test library: series directories with CBZ volumes (zipped jpg pages)
# and a series cover, following the server's comic grammar:
#   comics/{Series Name (start year)}/Volume N.cbz + cover.jpg
# Like create_mkv.sh, all media is generated locally and never committed.

set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Creates a comic page jpg (solid color with page dimensions) if it doesn't exist.
create_page () {
    local file="$1"
    local color="$2"
    if [ ! -f "$file" ]; then
        ffmpeg -f lavfi -i "color=size=400x600:color=$color" -frames:v 1 "$file" -loglevel error
    fi
}

# Builds a CBZ of 5 pages. Usage: create_cbz <output.cbz> <color>
create_cbz () {
    local output="$1"
    local color="$2"
    if [ -f "$output" ]; then
        return
    fi
    local tmp
    tmp=$(mktemp -d)
    for i in 1 2 3 4 5; do
        create_page "$tmp/page_0$i.jpg" "$color"
    done
    if command -v zip >/dev/null 2>&1; then
        (cd "$tmp" && zip -q -j "$output.tmp.zip" page_*.jpg && mv "$output.tmp.zip" "$output")
    else
        python3 - "$output" "$tmp" <<'PYEOF'
import sys, zipfile, glob, os
output, tmp = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(output, "w") as z:
    for page in sorted(glob.glob(os.path.join(tmp, "page_*.jpg"))):
        z.write(page, os.path.basename(page))
PYEOF
    fi
    rm -rf "$tmp"
    echo "Created file: $output"
}

# Creates a series: directory, cover and volumes.
# Usage: create_series <library_dir> <series_dir_name> <color> <volumes>
create_series () {
    local library_dir="$1"
    local series="$2"
    local color="$3"
    local volumes="$4"
    local dir="$library_dir/$series"
    mkdir -p "$dir"
    if [ ! -f "$dir/cover.jpg" ]; then
        ffmpeg -f lavfi -i "color=size=600x900:color=$color" -frames:v 1 "$dir/cover.jpg" -loglevel error
    fi
    for v in $(seq 1 "$volumes"); do
        create_cbz "$dir/Volume $v.cbz" "$color"
    done
}

LIBRARY="$SCRIPT_DIR/node1/disk1/comics"
mkdir -p "$LIBRARY"

create_series "$LIBRARY" "Falcon (1998)" "darkorange" 2
create_series "$LIBRARY" "Badger" "teal" 2

echo "Comic library generated under $LIBRARY"
