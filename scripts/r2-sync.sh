#!/bin/bash
# R2 手動同步工具

WORKSPACE_DIR="/workspace"
R2_BUCKET="${S3FS_BUCKET:-comfyui-volume}"
R2_PREFIX="${S3FS_PREFIX:-workspace}"
R2_ENDPOINT="${S3FS_ENDPOINT:-https://f0ab5339fbc3a504a9228b91458c40d2.r2.cloudflarestorage.com}"
R2_ACCESS_KEY="${CLOUDFLARE_KEY_ID:-${RUNPOD_SECRET_CLOUDFLARE_KEY_ID:-${AWS_ACCESS_KEY_ID:-}}}"
R2_SECRET_KEY="${CLOUDFLARE_TOKEN:-${RUNPOD_SECRET_CLOUDFLARE_TOKEN:-${AWS_SECRET_ACCESS_KEY:-}}}"

# 檢查 rclone 安裝
check_rclone() {
    if ! command -v rclone &> /dev/null; then
        echo "[error] rclone is not installed. Install with: apt-get install -y rclone" >&2
        return 1
    fi
    # 檢查 rclone 可執行文件狀態
    if [ ! -x "$(command -v rclone)" ]; then
        echo "[error] rclone is not executable. Try: chmod +x $(command -v rclone)" >&2
        return 1
    fi
    return 0
}

# 檢查憑證
if [ -z "$R2_ACCESS_KEY" ] || [ -z "$R2_SECRET_KEY" ]; then
    echo "[error] R2 credentials not found. Set CLOUDFLARE_KEY_ID and CLOUDFLARE_TOKEN." >&2
    exit 1
fi

# 設定 rclone 配置
setup_rclone() {
    mkdir -p ~/.config/rclone
    cat > ~/.config/rclone/rclone.conf <<EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = $R2_ACCESS_KEY
secret_access_key = $R2_SECRET_KEY
endpoint = $R2_ENDPOINT
acl = private
EOF
    chmod 600 ~/.config/rclone/rclone.conf
}

case "${1:-}" in
    download|down|pull)
        echo "[info] Downloading from R2: r2:$R2_BUCKET/$R2_PREFIX/ -> $WORKSPACE_DIR"
        if ! check_rclone; then
            echo "[error] rclone check failed" >&2
            exit 1
        fi
        setup_rclone
        mkdir -p "$WORKSPACE_DIR"
        if rclone sync -P r2:$R2_BUCKET/$R2_PREFIX/ $WORKSPACE_DIR/ 2>&1; then
            echo "[done] Download complete"
        else
            echo "[error] rclone sync failed with exit code $?" >&2
            exit 1
        fi
        ;;
    upload|up|push)
        echo "[info] Uploading to R2: $WORKSPACE_DIR -> r2:$R2_BUCKET/$R2_PREFIX/"
        if ! check_rclone; then
            echo "[error] rclone check failed" >&2
            exit 1
        fi
        setup_rclone
        if rclone sync -P $WORKSPACE_DIR/ r2:$R2_BUCKET/$R2_PREFIX/ 2>&1; then
            echo "[done] Upload complete"
        else
            echo "[error] rclone sync failed with exit code $?" >&2
            exit 1
        fi
        ;;
    *)
        echo "Usage: $(basename $0) {download|upload}"
        echo "  download (down/pull): Download from R2 to /workspace"
        echo "  upload (up/push):     Upload /workspace to R2"
        exit 1
        ;;
esac
