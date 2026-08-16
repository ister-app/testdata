#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Function to create the TV series structure
create_tv_series_structure () {
    local tv_series_dir="$1"

    # Loop through all TV series directories
    for series in "$tv_series_dir"/*; do
        if [ -d "$series" ]; then
            # The segment-detection show has bespoke episodes with real audio;
            # the generic 5x7 filler would pollute its season with silent files.
            case "$series" in *"Cicada"*) continue;; esac
            echo "Processing TV Series: $series"

            # Loop through Season directories
            for season_num in $(seq -w 1 5); do
                season_dir="$series/Season 0$season_num"

                # Create Season directory if it doesn't exist
                if [ ! -d "$season_dir" ]; then
                    mkdir -p "$season_dir"
                    echo "Created directory: $season_dir"
                fi

                # Check for episode files
                for episode_num in $(seq -w 1 7); do
                    episode_file="$season_dir/s0${season_num}e0${episode_num}.mkv"

                    # Create episode file if it doesn't exist
                    if [ ! -f "$episode_file" ]; then
                        episode_img="$season_dir/s01e0$episode_num.png"
                        if [ -f "$episode_img" ]; then
                          # The silent audio track matters: without any audio, mpv's only
                          # clock is the video output, and on a headless/GL-less player the
                          # file free-runs to EOF instantly.
                          ffmpeg -loop 1 -i "$episode_img" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -c:v mpeg4 -c:a aac -t 180 -pix_fmt yuv420p "$episode_file"
                        else
                          ffmpeg -f lavfi -i color=size=1280x720:rate=25:color=yellow -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -map 0 -map 1 -map 2 -metadata:s:v:0 language=deu -metadata:s:a:0 language=nld -t 180 "$episode_file"
                        fi
                        echo "Created file: $episode_file"
                    fi
                done
            done
        fi
    done
}

# Fixture for the server's intro/outro segment detection: three 300s episodes
# sharing an identical 35s audio intro and 25s audio outro around distinct
# middles (intro deliberately longer than the outro: on a short episode the
# whole file fits the detection window and the longest shared run wins).
# Audio is a deterministic two-tone step melody (a new chord every
# 0.5s) mixed with seeded pink noise — the broadband bed matters: sparse pure
# tones leave the fingerprinter's empty chroma bins to spectral leakage, which
# looks alike for any chord and matches spuriously across episodes.
create_segment_show_structure () {
    local season_dir="$1/Cicada (2021)/Season 01"
    [ -d "$1/Cicada (2021)" ] || return 0
    mkdir -p "$season_dir"

    # Two-tone step melody: chord index walks a 12-tone scale, pattern set by
    # the multiplier/offset pairs, so segments with different parameters are
    # musically uncorrelated while identical parameters give identical audio.
    melody () { # base1 mul1 off1 base2 mul2 off2 duration
        echo "aevalsrc='0.4*sin(2*PI*$1*pow(2\,mod($2*floor(2*t)+$3\,12)/12)*t)+0.25*sin(2*PI*$4*pow(2\,mod($5*floor(2*t)+$6\,12)/12)*t)':s=44100:d=$7"
    }

    local mid_mul1=(3 11 9) mid_off1=(2 6 10) mid_mul2=(4 8 10) mid_off2=(5 1 7)
    for i in 1 2 3; do
        local episode_file="$season_dir/s01e0$i.mkv"
        [ -f "$episode_file" ] && continue
        ffmpeg -f lavfi -i color=size=1280x720:rate=25:color=teal \
               -f lavfi -i "$(melody 220 7 1 440 5 4 35)" \
               -f lavfi -i "anoisesrc=colour=pink:seed=101:amplitude=0.08:d=35:sample_rate=44100" \
               -f lavfi -i "$(melody 260 "${mid_mul1[i-1]}" "${mid_off1[i-1]}" 520 "${mid_mul2[i-1]}" "${mid_off2[i-1]}" 240)" \
               -f lavfi -i "anoisesrc=colour=pink:seed=20$i:amplitude=0.08:d=240:sample_rate=44100" \
               -f lavfi -i "$(melody 196 5 9 392 7 2 25)" \
               -f lavfi -i "anoisesrc=colour=pink:seed=301:amplitude=0.08:d=25:sample_rate=44100" \
               -filter_complex "[1:a][2:a]amix=inputs=2:duration=first[ai];[3:a][4:a]amix=inputs=2:duration=first[am];[5:a][6:a]amix=inputs=2:duration=first[ao];[ai][am][ao]concat=n=3:v=0:a=1[a]" \
               -map 0:v -map "[a]" -c:v mpeg4 -c:a aac -t 300 -pix_fmt yuv420p "$episode_file"
        echo "Created file: $episode_file"
    done
}

create_movie_structure () {
    local movie_dir="$1"
    # Check if the directory exists
    if [ ! -d "$movie_dir" ]; then
        echo "Directory does not exist: $movie_dir"
        return 1
    fi
    # Loop through all _background.jpg files in the directory
    for background_jpg_file in "$movie_dir"/*-background.jpg; do
        # Check if the file exists
        if [ -f "$background_jpg_file" ]; then
            # Get the base name without the extension
            base_name="${background_jpg_file%-background.jpg}"
            new_file="${base_name}.mkv"

            # Create the new file if it doesn't exist
            if [ ! -f "$new_file" ]; then
                # Silent audio track: see the episode variant above — without it, a
                # player with no working video output free-runs to EOF instantly.
                ffmpeg -loop 1 -i "$background_jpg_file" -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -c:v mpeg4 -c:a aac -t 180 -pix_fmt yuv420p "$new_file"
                echo "Created file: $new_file"
            else
                echo "File already exists: $new_file"
            fi
        fi
    done
}

create_music_structure () {
    local music_dir="$1"

    # Loop through all artist directories
    for artist_dir in "$music_dir"/*; do
        if [ -d "$artist_dir" ]; then
            echo "Processing Artist: $artist_dir"

            # Loop through album directories
            for album_dir in "$artist_dir"/*; do
                if [ -d "$album_dir" ]; then
                    echo "Processing Album: $album_dir"

                    # Create track files
                    for track_num in $(seq -w 1 7); do
                        track_file="$album_dir/$track_num - Track $track_num.flac"
                        if [ ! -f "$track_file" ]; then
                            ffmpeg -f lavfi -i "sine=frequency=440:duration=30" -ar 44100 "$track_file" -loglevel error
                            echo "Created file: $track_file"
                        fi
                    done
                fi
            done
        fi
    done
}

# Process root-level directories
[ -d "$SCRIPT_DIR/tv" ] && create_tv_series_structure "$SCRIPT_DIR/tv"
[ -d "$SCRIPT_DIR/tv" ] && create_segment_show_structure "$SCRIPT_DIR/tv"
[ -d "$SCRIPT_DIR/movies" ] && create_movie_structure "$SCRIPT_DIR/movies"
[ -d "$SCRIPT_DIR/music" ] && create_music_structure "$SCRIPT_DIR/music"

# Process node*/disk* subdirectories
for disk_dir in "$SCRIPT_DIR"/node*/disk*; do
    [ -d "$disk_dir/tv" ] && create_tv_series_structure "$disk_dir/tv"
    [ -d "$disk_dir/tv" ] && create_segment_show_structure "$disk_dir/tv"
    [ -d "$disk_dir/movies" ] && create_movie_structure "$disk_dir/movies"
    [ -d "$disk_dir/music" ] && create_music_structure "$disk_dir/music"
done
