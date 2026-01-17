#!/bin/bash

NETWORK_DIR="/workspace"
INPUT_DIR="/app/input"
OUTPUT_DIR="/app/output"

echo "--- Edward Lee 的 ComfyUI 環境初始化 ---"
echo "--- 掛載點: $NETWORK_DIR ---"

# 建立外部資料夾 (如果網路磁碟是空的)
mkdir -p ${NETWORK_DIR}/input ${NETWORK_DIR}/output

# 建立軟連結：讓 /app/input 指向 /workspace/input
rm -rf $INPUT_DIR $OUTPUT_DIR
ln -s ${NETWORK_DIR}/input $INPUT_DIR
ln -s ${NETWORK_DIR}/output $OUTPUT_DIR

echo "--- 軟連結建立完成，啟動 ComfyUI ---"
python3 main.py --listen 0.0.0.0 --port 8188