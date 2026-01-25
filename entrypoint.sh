#!/bin/bash

# --- 環境變數設定 ---
NETWORK_DIR="/workspace"
INPUT_DIR="/app/input"
OUTPUT_DIR="/app/output"
WORKFLOW_DIR="/app/user/default/workflows"
MANAGER_CONFIG="/app/user/__manager/config.ini"

echo "--- Edward Lee 的 ComfyUI 環境初始化 ---"
echo "--- 掛載點: ${NETWORK_DIR} ---"

# 1. 建立外部持久化資料夾 (如果網路磁碟是空的)
mkdir -p "${NETWORK_DIR}/input" "${NETWORK_DIR}/output" "${NETWORK_DIR}/workflows"

# 2. 建立軟連結 (input/output)
rm -rf "${INPUT_DIR}" "${OUTPUT_DIR}"
ln -s "${NETWORK_DIR}/input" "${INPUT_DIR}"
ln -s "${NETWORK_DIR}/output" "${OUTPUT_DIR}"

# 3. 建立 Workflow 軟連結 (確保工作流不消失)
mkdir -p "/app/user/default"
rm -rf "${WORKFLOW_DIR}"
ln -s "${NETWORK_DIR}/workflows" "${WORKFLOW_DIR}"

# 4. 強制鎖定介面語係為英文 (English)
mkdir -p "/app/user/__manager"
if [ ! -f "$MANAGER_CONFIG" ]; then
    echo "[config]" > "$MANAGER_CONFIG"
    echo "language = en-US" >> "$MANAGER_CONFIG"
else
    # 如果檔案已存在，則修改 language 這一行
    sed -i 's/language = .*/language = en-US/' "$MANAGER_CONFIG"
fi

echo "--- 軟連結與語系設定完成，啟動 ComfyUI ---"

# 5. 下載模型到容器內部 /app/models（不使用 /workspace 持久化磁碟），加入重試避免啟動早期 DNS 未就緒
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

# 6. 啟動 ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188