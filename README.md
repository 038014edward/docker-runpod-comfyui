# docker-runpod-comfyui

基於 CUDA 12.4 的 ComfyUI 容器環境，內建常用自訂節點並在啟動時自動下載 `configs/models.txt` 列出的模型至 `/app/models`。

## 內容概覽

- 基底：`nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04`
- 主程式：ComfyUI（/app）
- 自訂節點：Manager、Custom-Scripts、rgthree、civitai 節點、essentials、Easy-Use、IPAdapter+、ControlNet Aux、KJNodes、Impact Pack/Subpack、AdvancedLivePortrait、Florence2、VideoHelperSuite、GGUF 支援等
- 模型：啟動時執行 `/usr/local/bin/download-models`，使用 `configs/models.txt` 清單，下載到 `/app/models`
- 服務埠：8188（已 EXPOSE）

## 建置映像

```bash
# 建置並指定標籤
docker build -t wavefunc/comfyui-wan2.1:latest .

# 登入 Docker Hub（若尚未登入）
docker login

# Push 到 Docker Hub
docker push wavefunc/comfyui-wan2.1:latest
```

若要同時建立多個標籤（例如 latest 與版本標籤）：

```bash
docker build -t wavefunc/comfyui-wan2.1:latest -t wavefunc/comfyui-wan2.1:v1.0 .
docker push wavefunc/comfyui-wan2.1:latest
docker push wavefunc/comfyui-wan2.1:v1.0
```

## 執行容器（RunPod 或一般 Docker）

```bash
docker run --gpus all \
  -p 8188:8188 \
  -v /your/persistent/workspace:/workspace \  # 可選：存放 input/output/workflows，非必須
  --name comfyui \
  comfyui:cuda124
```

啟動流程：

1) 建立並連結 `/workspace` 下的 input/output/workflows 到 `/app/*`
2) 下載模型到 `/app/models`（失敗會警告但不阻斷）
3) 啟動 ComfyUI：`python3 main.py --listen 0.0.0.0 --port 8188`

## 模型下載設定

- 清單：`configs/models.txt`，格式 `URL|subdir|filename`
- 下載目錄：`MODELS_DIR`（預設 `/app/models`）
- 並行數：`MODEL_JOBS`（預設 `4`）
- Token：`CIVITAI_TOKEN`、`HUGGING_FACE_TOKEN`（可選）
- 手動觸發：容器內執行 `download-models`

## 常用 Volume 路徑

- `/workspace/input` → `/app/input`
- `/workspace/output` → `/app/output`
- `/workspace/workflows` → `/app/user/default/workflows`
- 模型不預設持久化；若要持久化模型，請額外掛載 `/app/models`。

## Troubleshooting

- 模型未下載：檢查網路與 Token，或容器內手動執行 `download-models`
- 下載中斷：調降 `MODEL_JOBS`，或確認磁碟空間
- 自訂節點依賴缺失：在容器內手動安裝或於 Dockerfile 補充對應套件
