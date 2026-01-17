#!/bin/bash

echo "--- Edward Lee, 正在為您初始化高效能 ComfyUI 環境 ---"

# 定義路徑
NETWORK_DIR="/network-storage"
INPUT_DIR="/app/input"
OUTPUT_DIR="/app/output"

# 建立網路磁碟上的資料夾（如果不存在）
mkdir -p ${NETWORK_DIR}/input ${NETWORK_DIR}/output

# 處理軟連結：確保 input/output 指向持久化磁碟
rm -rf $INPUT_DIR $OUTPUT_DIR
ln -s ${NETWORK_DIR}/input $INPUT_DIR
ln -s ${NETWORK_DIR}/output $OUTPUT_DIR

echo "--- 軟連結配置完成，正在啟動 ComfyUI ---"

# ??? ComfyUI
python3 main.py --listen 0.0.0.0 --port 8188