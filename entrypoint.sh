#!/bin/bash
set -e

# 在 entrypoint.sh 開始前強制終止所有殘留的 rclone 進程
pkill -9 rclone || true
sleep 1

# --- 環境變數設定 ---
NETWORK_DIR="/workspace"
INPUT_DIR="/app/input"
OUTPUT_DIR="/app/output"
WORKFLOW_DIR="/app/user/default/workflows"
MANAGER_CONFIG="/app/user/__manager/config.ini"

echo "--- Edward Lee 的 ComfyUI 環境初始化 ---"
echo "--- 工作目錄: ${NETWORK_DIR} ---"

# 1. 從 R2 下載資料到 /workspace（如果憑證存在）
echo "[info] 嘗試從 R2 同步資料..."
if [ -z "$CLOUDFLARE_KEY_ID" ] || [ -z "$CLOUDFLARE_TOKEN" ]; then
    echo "[warn] R2 credentials not found (CLOUDFLARE_KEY_ID or CLOUDFLARE_TOKEN not set)" >&2
elif ! r2-sync download 2>&1; then
    EXIT_CODE=$?
    echo "[error] R2 同步失敗 (exit code: $EXIT_CODE)" >&2
    echo "[warn] 使用本地 /workspace" >&2
else
    echo "[info] R2 資料同步完成"
fi

# 2. 建立必要的資料夾結構
mkdir -p "${NETWORK_DIR}/input" "${NETWORK_DIR}/output" "${NETWORK_DIR}/workflows"

# 3. 建立軟連結 (input/output)
rm -rf "${INPUT_DIR}" "${OUTPUT_DIR}"
ln -s "${NETWORK_DIR}/input" "${INPUT_DIR}"
ln -s "${NETWORK_DIR}/output" "${OUTPUT_DIR}"

# 4. 建立 Workflow 軟連結 (確保工作流不消失)
mkdir -p "/app/user/default"
rm -rf "${WORKFLOW_DIR}"
ln -s "${NETWORK_DIR}/workflows" "${WORKFLOW_DIR}"

# 5. 強制鎖定介面語係為英文 (English)
mkdir -p "/app/user/__manager"
if [ ! -f "$MANAGER_CONFIG" ]; then
    echo "[config]" > "$MANAGER_CONFIG"
    echo "language = en-US" >> "$MANAGER_CONFIG"
else
    # 如果檔案已存在，則修改 language 這一行
    sed -i 's/language = .*/language = en-US/' "$MANAGER_CONFIG"
fi

echo "--- 軟連結與語系設定完成 ---"

# 6. 下載模型到容器內部 /app/models（優先使用 R2 同步的 model 清單），加入重試避免啟動早期 DNS 未就緒
echo "[info] 開始下載模型..."
if [ -f "/workspace/model-list/models.txt" ]; then
    echo "[info] 使用 R2 同步的模型清單: /workspace/model-list/models.txt"
else
    echo "[info] 使用內建模型清單: /opt/comfy-configs/models.txt"
fi
DOWNLOAD_OK=0
for i in {1..5}; do
    if download-models; then
        DOWNLOAD_OK=1
        break
    fi
    echo "[warn] download-models failed on try $i, retrying in 20s" >&2
    sleep 20
done
[ "$DOWNLOAD_OK" -eq 0 ] && echo "[warn] model download skipped after retries" >&2

# 7. 啟動 ComfyUI
echo "--- 啟動 ComfyUI ---"
python3 main.py --listen 0.0.0.0 --port 8188