#!/usr/bin/env bash
# Encode a video (for example a Higgsfield download) for the store "How it works" slot.
# Usage: bash scripts/encode-store-video.sh path/to/video.mp4 [poster-second] [name]
# Writes store/assets/<name>.mp4, <name>.webm and <name>-poster.jpg (no audio, 1280 wide).
# name defaults to how-it-works; the band-spin background film uses: ... video.mp4 5 band-spin
# Needs ffmpeg (macOS: brew install ffmpeg). Set OUT=dir to write somewhere else.
set -euo pipefail
in="${1:?usage: encode-store-video.sh <video.mp4> [poster-second]}"
at="${2:-4}"
name="${3:-how-it-works}"
out="${OUT:-$(cd "$(dirname "$0")/.." && pwd)/store/assets}"
command -v ffmpeg >/dev/null || { echo "ffmpeg not found (macOS: brew install ffmpeg)" >&2; exit 1; }
[ -f "$in" ] || { echo "no such file: $in" >&2; exit 1; }
mkdir -p "$out"
ffmpeg -v error -y -i "$in" -an -vf "scale=1280:-2,format=yuv420p" -c:v libx264 -profile:v high -crf 26 -preset slow -movflags +faststart "$out/$name.mp4"
ffmpeg -v error -y -i "$in" -an -vf "scale=1280:-2" -c:v libvpx-vp9 -crf 36 -b:v 0 -row-mt 1 "$out/$name.webm"
ffmpeg -v error -y -ss "$at" -i "$in" -frames:v 1 -vf "scale=1280:-2" -q:v 4 "$out/$name-poster.jpg"
ls -l "$out"/"$name"*
