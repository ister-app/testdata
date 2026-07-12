#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

find "${SCRIPT_DIR}" -type f -name "*.mkv" -exec rm -f {} +
find "${SCRIPT_DIR}" -type f -name "*.flac" -exec rm -f {} +
