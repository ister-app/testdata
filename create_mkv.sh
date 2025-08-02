#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Function to create the TV series structure
create_tv_series_structure () {
    local tv_series_dir="$1"

    # Loop through all TV series directories
    for series in "$tv_series_dir"/*; do
        if [ -d "$series" ]; then
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
                    episode_file="$season_dir/s01e0$episode_num.mkv"

                    # Create episode file if it doesn't exist
                    if [ ! -f "$episode_file" ]; then
                        episode_img="$season_dir/s01e0$episode_num.png"
                        if [ -f "$episode_img" ]; then
                          ffmpeg -loop 1 -i "$episode_img" -c:v mpeg4 -t 180 -pix_fmt yuv420p "$episode_file"
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

create_movie_structure () {
    local movie_dir="$1"
    # Check if the directory exists
    if [ ! -d "$movie_dir" ]; then
        echo "Directory does not exist: $movie_dir"
        return 1
    fi
    # Loop through all _background.jpg files in the directory
    for background_jpg_file in "$movie_dir"/*_background.jpg; do
        # Check if the file exists
        if [ -f "$background_jpg_file" ]; then
            # Get the base name without the extension
            base_name="${background_jpg_file%_background.jpg}"
            new_file="${base_name}.mkv"

            # Create the new file if it doesn't exist
            if [ ! -f "$new_file" ]; then
                ffmpeg -loop 1 -i "$background_jpg_file" -c:v mpeg4 -t 180 -pix_fmt yuv420p "$new_file"
                echo "Created file: $new_file"
            else
                echo "File already exists: $new_file"
            fi
        fi
    done
}

create_tv_series_structure "$SCRIPT_DIR"/tv
create_movie_structure "$SCRIPT_DIR"/movies
