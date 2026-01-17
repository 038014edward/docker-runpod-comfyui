# 使用 NVIDIA CUDA 官方鏡像作為基底，確保 GPU 效能
FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04

# 設定環境變數，避免互動式安裝提問
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# 安裝系統層級依賴
RUN apt-get update && apt-get install -y \
    python3.10 python3-pip git git-lfs wget curl libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# 升級 pip 並安裝核心框架
RUN pip3 install --upgrade pip
RUN pip3 install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# 下載 ComfyUI 主程式並封裝在鏡像內 (NVMe 速度)
WORKDIR /app
RUN git clone https://github.com/comfyanonymous/ComfyUI.git . \
    && pip3 install -r requirements.txt

# 安裝常用的自訂節點 (如 Manager)
WORKDIR /app/custom_nodes
RUN git clone https://github.com/ltdrdata/ComfyUI-Manager.git

# 回到工作目錄並複製啟動腳本
WORKDIR /app
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 開放 ComfyUI 預設埠位
EXPOSE 8188

ENTRYPOINT ["/entrypoint.sh"]