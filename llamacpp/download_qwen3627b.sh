#!/bin/bash

MODEL_REPO="unsloth/Qwen3.6-27B-GGUF"
FILENAME="Qwen3.6-27B-Q4_K_M.gguf"
OUTPUT_DIR="./models"
PROXY="http://192.168.1.7:1087"

echo "Downloading Qwen3.6-27B Q4_K_M GGUF model..."
echo "Repository: $MODEL_REPO"
echo "File: $FILENAME"
echo "Output: $OUTPUT_DIR/$FILENAME"

mkdir -p "$OUTPUT_DIR"

URL="https://huggingface.co/$MODEL_REPO/resolve/main/$FILENAME"

export HTTP_PROXY="$PROXY"
export HTTPS_PROXY="$PROXY"
export http_proxy="$PROXY"
export https_proxy="$PROXY"

echo "Starting download with curl -C (resume support)..."
curl -L -C - -o "$OUTPUT_DIR/$FILENAME" "$URL"

if [ $? -eq 0 ]; then
    SIZE=$(du -h "$OUTPUT_DIR/$FILENAME" 2>/dev/null | cut -f1)
    echo "Download complete! Model saved to: $OUTPUT_DIR/$FILENAME ($SIZE)"
else
    echo "Download failed. Run this script again to resume from where it left off."
fi