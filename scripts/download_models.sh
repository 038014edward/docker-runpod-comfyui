#!/bin/bash
set -euo pipefail

# 使用 aria2c 下載 configs/models.txt 裡列出的所有模型到 /app/models。
# 可設定的環境變數：
#   MODELS_DIR: 模型儲存位置（預設：/app/models）
#   MODEL_JOBS: 最大並行下載數（預設：4）
#   CIVITAI_TOKEN / HUGGING_FACE_TOKEN: 可選的授權 Token

# 解析真實腳本路徑以避免 symlink 導致路徑錯誤
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# 追蹤是否有任何下載失敗，供外層重試判斷
FAIL=0
# 預設使用 volume 下的 /workspace/model-list/models.txt；若不存在則退回鏡像內的配置檔 (/opt/comfy-configs)
CONFIG_FILE="${CONFIG_FILE:-}"
if [ -z "$CONFIG_FILE" ]; then
    for candidate in /workspace/model-list/models.txt /opt/comfy-configs/models.txt; do
        if [ -f "$candidate" ]; then
            CONFIG_FILE="$candidate"
            break
        fi
    done
    # 若兩者皆不存在，仍將預設指向 volume 路徑，方便之後掛載時生效
    CONFIG_FILE="${CONFIG_FILE:-/workspace/model-list/models.txt}"
fi
MODELS_DIR="${MODELS_DIR:-/app/models}"
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
    if ! timeout 3600 aria2c --console-log-level=warn -c -x16 -s16 -k1M "${headers[@]}" "$final_url" -d "$target_dir" -o "$filename"; then
        FAIL=1
        return 1
    fi
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
            if ! wait -n; then FAIL=1; fi
            active=$((active - 1))
        fi
    done < "$CONFIG_FILE"

    echo "Waiting for remaining $active job(s)..."
    while [ "$active" -gt 0 ]; do
        if ! wait; then FAIL=1; fi
        active=$((active - 1))
    done
}

main() {
    ensure_aria2
    mkdir -p "$MODELS_DIR"
    process_models_list
    # 若任何任務失敗，回傳非零讓入口腳本可以重試
    if [ "$FAIL" -ne 0 ]; then
        echo "[warn] some downloads failed" >&2
        return 1
    fi
}

main "$@"
