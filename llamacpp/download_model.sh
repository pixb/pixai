#!/bin/bash
# Download script for Qwen2.5-1.5B GGUF model

MODEL_NAME="Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/${MODEL_NAME}"
FALLBACK_URL="https://hf-mirror.com/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/${MODEL_NAME}"

echo "Downloading ${MODEL_NAME}..."

# Try HuggingFace first
if curl -L --connect-timeout 30 -o "${MODEL_NAME}" "${MODEL_URL}"; then
    echo "Downloaded successfully!"
    mv "${MODEL_NAME}" ./models/
else
    echo "HuggingFace download failed, trying hf-mirror..."
    if curl -L --connect-timeout 30 -o "${MODEL_NAME}" "${FALLBACK_URL}"; then
        echo "Downloaded successfully!"
        mv "${MODEL_NAME}" ./models/
    else
        echo "Download failed. Please manually download from:"
        echo "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF"
        exit 1
    fi
fi
