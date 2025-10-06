#!/bin/bash

# Check arguments
if [[ $# -lt 2 ]]; then
	echo "Usage: $0 <file1> [file2 ...] <target_size_MB>"
	exit 1
fi

# Extract target size (last argument)
count=$#
target_size_mb="${!count}"

# All other arguments are input files
FILES=("${@:1:$(($count-1))}")

for INPUT in "${FILES[@]}"; do
	if [[ ! -f "$INPUT" ]]; then
		echo "Skipping $INPUT: file does not exist."
		continue
	fi

	output_file="${INPUT%.*}-$T_SIZEMB.mp4"

	duration_sec=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$INPUT")
	audio_bitrate_kbps=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of csv=p=0 "$INPUT")
	audio_bitrate_kbps=$(awk -v arate="$audio_bitrate_kbps" 'BEGIN { printf "%.0f", (arate / 1024) }')

	min_size_mb=$(awk -v arate="$audio_bitrate_kbps" -v duration="$duration_sec" 'BEGIN { printf "%.2f", ( (arate * duration) / 8192 ) }')
	size_ok=$(awk -v size="$target_size_mb" -v minsize="$min_size_mb" 'BEGIN { print (minsize < size) }')

	if [[ $size_ok -eq 0 ]]; then
		echo "Target size ${target_size_mb}MB is too small for $INPUT!"
		echo "Try values larger than ${min_size_mb}MB"
		continue
	fi

	T_ARATE=$audio_bitrate_kbps
	video_bitrate_kbps=$(awk -v size="$target_size_mb" -v duration="$duration_sec" -v audio_rate="$audio_bitrate_kbps" 'BEGIN { print  ( ( size * 8192.0 ) / ( 1.048576 * duration ) - audio_rate) }')

	echo "Processing $INPUT -> $output_file ..."
	ffmpeg -y -i "$INPUT" -c:v libx264 -b:v "$video_bitrate_kbps"k -pass 1 -an -f mp4 /dev/null && \
	ffmpeg -i "$INPUT" -c:v libx264 -b:v "$video_bitrate_kbps"k -pass 2 -c:a aac -b:a "$T_ARATE"k "$output_file"

	# Clean up FFmpeg 2-pass logs
	rm -f ffmpeg2pass-0.log ffmpeg2pass-0.log.mbtree
done