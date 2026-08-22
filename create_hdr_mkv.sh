#!/bin/bash
# HDR / frame-rate fixtures for the player's SurfaceView video path:
# HDR10 passthrough (PQ/BT.2020), HLG, and Surface.setFrameRate matching.
# Every file carries a silent audio track: without one, mpv's only clock is
# the video output and a GL-less player free-runs to EOF instantly.

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
MOVIES_DIR="$SCRIPT_DIR/node1/disk1/movies"

# The colour description must go through x265-params: that writes the VUI into
# the HEVC bitstream itself, which is what survives remuxing and what mpv reads.
# ffmpeg's -color_trc/-color_primaries flags only tag the container stream and
# demonstrably do not reach the bitstream here.
hdr10_params="hdr10=1:colorprim=bt2020:transfer=smpte2084:colormatrix=bt2020nc:range=limited:master-display=G(13250,34500)B(7500,3000)R(34000,16000)WP(15635,16450)L(10000000,1):max-cll=1000,400"
hlg_params="colorprim=bt2020:transfer=arib-std-b67:colormatrix=bt2020nc:range=limited"

make_movie () {
    local file="$1"; shift
    local title="$1"; shift
    local plot="$1"; shift
    if [ ! -f "$MOVIES_DIR/$file.mkv" ]; then
        ffmpeg "$@" "$MOVIES_DIR/$file.mkv"
        echo "Created file: $MOVIES_DIR/$file.mkv"
    fi
    if [ ! -f "$MOVIES_DIR/$file.nfo" ]; then
        cat > "$MOVIES_DIR/$file.nfo" <<NFO
<?xml version="1.0" encoding="UTF-8" standalone="yes" ?>
<movie>
    <title>$title</title>
    <plot>$plot</plot>
    <premiered>2024-01-01</premiered>
    <year>2024</year>
</movie>
NFO
        echo "Created file: $MOVIES_DIR/$file.nfo"
    fi
}

# 4K60 HEVC HDR10 — the heavy passthrough / mediacodec-copy spike fixture.
make_movie "Aurora (2024)" "Aurora" \
    "Time-lapse footage of the northern lights, mastered in HDR10 at 4K." \
    -f lavfi -i "testsrc2=size=3840x2160:rate=60" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    -t 120 -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le \
    -x265-params "$hdr10_params" \
    -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
    -c:a aac

# 1080p 23.976 HEVC HDR10 — film cadence for Surface.setFrameRate, light HDR.
make_movie "Nocturne (2024)" "Nocturne" \
    "A pianist rehearses through the night, graded in HDR10 at film cadence." \
    -f lavfi -i "testsrc2=size=1920x1080:rate=24000/1001" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    -t 120 -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le \
    -x265-params "$hdr10_params" \
    -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
    -c:a aac

# 1080p50 SDR — the frame-rate-switch counterpart (no HDR involved).
make_movie "Meridian (2024)" "Meridian" \
    "A broadcast documentary shot at European broadcast frame rates." \
    -f lavfi -i "testsrc2=size=1920x1080:rate=50" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    -t 120 -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
    -c:a aac

# 1080p24 HDR10, calm content: slowly drifting gradients at moderate levels.
# testsrc2 flashes full-range PQ whites, which reads as violent brightness
# flicker on a real HDR panel — useless for judging output stability.
make_movie "Stilla (2024)" "Stilla" \
    "A meditative drift of colour fields, graded gently in HDR10." \
    -f lavfi -i "gradients=size=1920x1080:rate=24:speed=0.01" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    -t 120 -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le \
    -x265-params "$hdr10_params" \
    -color_primaries bt2020 -color_trc smpte2084 -colorspace bt2020nc \
    -c:a aac

# 1080p25 HEVC HLG — the broadcast-HDR variant (arib-std-b67).
make_movie "Lumen (2024)" "Lumen" \
    "A candle-lit concert registered in hybrid log-gamma." \
    -f lavfi -i "testsrc2=size=1920x1080:rate=25" \
    -f lavfi -i "anullsrc=channel_layout=stereo:sample_rate=44100" \
    -t 120 -c:v libx265 -preset ultrafast -pix_fmt yuv420p10le \
    -x265-params "$hlg_params" \
    -color_primaries bt2020 -color_trc arib-std-b67 -colorspace bt2020nc \
    -c:a aac
