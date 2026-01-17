# 1. 基底鏡像：使用 NVIDIA CUDA 12.4 開發版
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# 2. 環境變數設定
ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PATH="/usr/local/cuda/bin:${PATH}"

# 3. 安裝系統依賴 (加入 ffmpeg 用於影片處理)
RUN apt-get update && apt-get install -y \
    python3.10 python3-pip git git-lfs wget curl \
    libgl1 libglib2.0-0 libgoogle-perftools-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# 4. 升級 pip 並安裝 Pytorch (對應 CUDA 12.4)
RUN pip3 install --upgrade pip
RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# 5. 安裝 ComfyUI 主程式 (注意這裡的 . 代表安裝在 /app 根目錄)
WORKDIR /app
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . \
    && pip3 install -r requirements.txt

# 6. 安裝 Custom Nodes (整合 Edward 的清單)
WORKDIR /app/custom_nodes

# --- 基礎管理與工具 ---
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    git clone https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git && \
    git clone https://github.com/rgthree/rgthree-comfy.git && \
    git clone https://github.com/civitai/civitai_comfy_nodes.git

# --- 工作流核心增強 ---
RUN git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    git clone https://github.com/chrisgoringe/cg-use-everywhere.git

# --- 影像處理與 ControlNet/IPAdapter ---
RUN git clone https://github.com/cubiq/ComfyUI_IPAdapter_plus.git && \
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git

# --- Impact Pack (需處理 submodule) ---
RUN git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git && \
    cd ComfyUI-Impact-Pack && git submodule update --init --recursive && cd .. && \
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git

# --- 進階影像與影片 (LivePortrait, Florence2, VHS) ---
RUN git clone https://github.com/PowerHouseMan/ComfyUI-AdvancedLivePortrait.git && \
    git clone https://github.com/kijai/ComfyUI-Florence2.git && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git

# --- GGUF 模型支援 ---
RUN git clone https://github.com/city96/ComfyUI-GGUF.git && \
    git clone https://github.com/calcuis/gguf.git

# 7. 自動安裝所有節點的 Python 依賴 (這是加速啟動的關鍵)
# 使用 find 找出所有 requirements.txt 並安裝，忽略錯誤以防某個插件依賴衝突卡住流程
RUN find . -maxdepth 2 -name "requirements.txt" -exec pip3 install -r {} \; || true

# 8. 配置啟動環境
WORKDIR /app
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8188
ENTRYPOINT ["/entrypoint.sh"]