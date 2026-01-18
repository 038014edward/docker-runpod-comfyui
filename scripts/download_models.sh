#!/bin/bash
set -euo pipefail

# Download all models listed in configs/models.txt using aria2c.
# Environment variables:
#   MODELS_DIR: where to store models (default: /workspace/models)
#   COMFY_MODELS_DIR: ComfyUI models path to optionally link (default: /app/models)
#   MODEL_JOBS: max concurrent downloads (default: 4)
#   CIVITAI_TOKEN / HUGGING_FACE_TOKEN: optional auth tokens

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$REPO_ROOT/configs/models.txt}"
MODELS_DIR="${MODELS_DIR:-/workspace/models}"
COMFY_MODELS_DIR="${COMFY_MODELS_DIR:-/app/models}"
MODEL_JOBS="${MODEL_JOBS:-4}"
CIVITAI_TOKEN="${CIVITAI_TOKEN:-}"
HUGGING_FACE_TOKEN="${HUGGING_FACE_TOKEN:-}"

trim() {
    local var="$1"
    var="${var#${var%%[![:space:]]*}}"
    var="${var%${var##*[![:space:]]}}"
    echo "$var"
}

ensure_aria2() {
    if ! command -v aria2c >/dev/null 2>&1; then
        echo "aria2c not found. Install it first (e.g. apt-get update && apt-get install -y aria2)." >&2
        exit 1
    fi
}

link_models_dir() {
    # If ComfyUI models dir does not exist, symlink it to the persistent directory.
    [ "$MODELS_DIR" = "$COMFY_MODELS_DIR" ] && return
    if [ -L "$COMFY_MODELS_DIR" ]; then
        return
    fi
    if [ -e "$COMFY_MODELS_DIR" ]; then
        echo "ComfyUI models path $COMFY_MODELS_DIR exists; not replacing." >&2
        return
    fi
    ln -s "$MODELS_DIR" "$COMFY_MODELS_DIR"
}

download_model() {
    local url="$1"
    local subdir="$2"
    local filename="$3"
    local target_dir="$MODELS_DIR/$subdir"
    local final_url="$url"
    local headers=()

    mkdir -p "$target_dir"
    if [ -f "$target_dir/$filename" ]; then
        echo "[skip] $filename already exists"
        return
    fi

    if [[ "$final_url" =~ civitai\.com ]] && [ -n "$CIVITAI_TOKEN" ]; then
        if [[ "$final_url" == *"?"* ]]; then
            final_url="${final_url}&token=${CIVITAI_TOKEN}"
        else
            final_url="${final_url}?token=${CIVITAI_TOKEN}"
        fi
    fi

    if [[ "$final_url" =~ huggingface\.co ]] && [ -n "$HUGGING_FACE_TOKEN" ]; then
        headers+=("--header=Authorization: Bearer ${HUGGING_FACE_TOKEN}")
    fi

    echo "[get] $filename -> $target_dir"
    timeout 3600 aria2c --console-log-level=warn -c -x16 -s16 -k1M "${headers[@]}" "$final_url" -d "$target_dir" -o "$filename"
}

process_models_list() {
    local active=0
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "models list not found: $CONFIG_FILE" >&2
        return 0
    fi

    echo "Downloading models to $MODELS_DIR (jobs=$MODEL_JOBS)"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        IFS='|' read -r url subdir filename <<<"$line"
        url="$(trim "${url:-}")"; subdir="$(trim "${subdir:-checkpoints}")"; filename="$(trim "${filename:-}")"
        [ -z "$url" ] && continue
        [ -z "$subdir" ] && subdir="checkpoints"
        [ -z "$filename" ] && filename="$(basename "$url")"

        download_model "$url" "$subdir" "$filename" &
        active=$((active + 1))
        if [ "$active" -ge "$MODEL_JOBS" ]; then
            wait -n || true
            active=$((active - 1))
        fi
    done < "$CONFIG_FILE"

    echo "Waiting for remaining $active job(s)..."
    wait || echo "warning: some downloads did not complete" >&2
}

main() {
    ensure_aria2
    mkdir -p "$MODELS_DIR"
    link_models_dir
    process_models_list
}

main "$@"
