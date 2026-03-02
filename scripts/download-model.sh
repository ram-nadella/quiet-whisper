#!/bin/bash
set -e

MODEL_DIR="$HOME/Library/Application Support/WhisperDictation/models"
mkdir -p "$MODEL_DIR"

BASE_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

download_model() {
    local model_name=$1
    local filename="ggml-${model_name}.bin"
    local filepath="${MODEL_DIR}/${filename}"

    if [ -f "$filepath" ]; then
        echo "Model $model_name already exists at $filepath"
        return 0
    fi

    echo "Downloading $model_name (~1.5GB)..."
    curl -L --progress-bar -o "$filepath" "${BASE_URL}/${filename}"
    echo "Downloaded to $filepath"
}

case "${1:-large-v3-turbo}" in
    tiny.en)
        download_model "tiny.en"
        ;;
    large-v3-turbo)
        download_model "large-v3-turbo"
        ;;
    all)
        download_model "tiny.en"
        download_model "large-v3-turbo"
        ;;
    *)
        echo "Usage: $0 [tiny.en|large-v3-turbo|all]"
        exit 1
        ;;
esac
