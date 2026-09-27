#!/usr/bin/env bash
# makevideo.sh - turn a movy.VideoExport frame dump (+ optional audio) into an
# H.264 mp4.
#
#   tools/makevideo.sh FRAMES_DIR OUT.mp4 [options]
#
#   --audio FILE      mux an audio track (wav / mp3 / ...), AAC 320k
#   --offset MS       A/V offset in ms, decimals fine (default 0). Positive =
#                     the video appears later than the audio (the audio is
#                     head-trimmed, sample-accurate); negative delays the audio.
#   --fps N           frame rate of the dump (default 60)
#   --size WxH        pad to this size, centered, no rescaling (default
#                     1920x1080; frames larger than that are kept native)
#   --native          no padding: the video is exactly the frame size
#   --crf N           H.264 quality, lower = better (default 16)
#
# Frame 0 is t = 0, so a sound track that starts at 0 is in sync by
# construction. With --audio the video ends at the shorter of the two.
#
# Needs ffmpeg (and ffprobe for the summary). Examples:
#
#   zig build run-glyph-reel -- export              # -> export/frame_*.png
#   tools/makevideo.sh export glyph-reel.mp4
#   tools/makevideo.sh export glyph-reel.mp4 --audio music.wav --offset 5
set -euo pipefail

usage() { sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[ $# -ge 2 ] || usage

IN="$1"
OUT="$2"
shift 2
AUDIO=""
OFFSET_MS="0"
FPS="60"
SIZE="1920x1080"
NATIVE=0
CRF="16"
while [ $# -gt 0 ]; do
    case "$1" in
        --audio) AUDIO="$2"; shift 2 ;;
        --offset) OFFSET_MS="$2"; shift 2 ;;
        --fps) FPS="$2"; shift 2 ;;
        --size) SIZE="$2"; shift 2 ;;
        --native) NATIVE=1; shift ;;
        --crf) CRF="$2"; shift 2 ;;
        *) echo "unknown option: $1"; usage ;;
    esac
done

command -v ffmpeg >/dev/null || { echo "ffmpeg not found"; exit 1; }
[ -f "$IN/frame_000000.png" ] || { echo "no $IN/frame_000000.png - export frames first"; exit 1; }
N_FRAMES=$(find "$IN" -maxdepth 1 -name 'frame_[0-9][0-9][0-9][0-9][0-9][0-9].png' | wc -l | tr -d ' ')

# frame size from the first PNG's IHDR (bytes 16..23, big-endian)
read -r FW FH < <(od -An -tu1 -j16 -N8 "$IN/frame_000000.png" |
    awk '{print $1*16777216+$2*65536+$3*256+$4, $5*16777216+$6*65536+$7*256+$8}')
PW=${SIZE%x*}
PH=${SIZE#*x}
if [ "$NATIVE" = 1 ] || [ "$FW" -gt "$PW" ] || [ "$FH" -gt "$PH" ]; then
    # H.264 / yuv420p needs even dimensions
    VF="pad=ceil(iw/2)*2:ceil(ih/2)*2:0:0:black"
    echo "frames ${FW}x${FH}, $N_FRAMES @ ${FPS}fps -> native size"
else
    VF="pad=${PW}:${PH}:(ow-iw)/2:(oh-ih)/2:black"
    echo "frames ${FW}x${FH}, $N_FRAMES @ ${FPS}fps -> padded to ${PW}x${PH}"
fi

AUDIO_ARGS=()
if [ -n "$AUDIO" ]; then
    AF="anull"
    SIGN=$(awk "BEGIN{print ($OFFSET_MS > 0) ? 1 : (($OFFSET_MS < 0) ? -1 : 0)}")
    if [ "$SIGN" = "1" ]; then
        TRIM=$(awk "BEGIN{printf \"%.6f\", $OFFSET_MS/1000}")
        AF="atrim=start=$TRIM,asetpts=PTS-STARTPTS"
        echo "A/V offset: video +${OFFSET_MS}ms late (audio head-trimmed ${TRIM}s)"
    elif [ "$SIGN" = "-1" ]; then
        DELAY=$(awk "BEGIN{printf \"%.3f\", -($OFFSET_MS)}")
        AF="adelay=${DELAY}:all=1"
        echo "A/V offset: video ${OFFSET_MS}ms early (audio delayed ${DELAY}ms)"
    fi
    AUDIO_ARGS=(-i "$AUDIO" -af "$AF" -c:a aac -b:a 320k -shortest)
fi

ffmpeg -hide_banner -loglevel warning -stats -y \
    -framerate "$FPS" -start_number 0 -i "$IN/frame_%06d.png" \
    ${AUDIO_ARGS[@]+"${AUDIO_ARGS[@]}"} \
    -vf "$VF" \
    -c:v libx264 -preset slow -crf "$CRF" -pix_fmt yuv420p \
    -movflags +faststart \
    "$OUT"

echo "wrote $OUT"
if command -v ffprobe >/dev/null; then
    ffprobe -v error -show_entries format=duration:stream=codec_name,width,height,r_frame_rate \
        -of default=noprint_wrappers=1 "$OUT"
fi
