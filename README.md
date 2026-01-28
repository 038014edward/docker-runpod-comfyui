# docker-runpod-comfyui

基於 CUDA 12.4 的 ComfyUI 容器環境，內建常用自訂節點並在啟動時自動下載 `models.txt`（預設讀取 `/workspace/model-list/models.txt`，若無則退回內建 `configs/models.txt`）列出的模型至 `/app/models`。

## 內容概覽

- 基底：`nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04`
- 主程式：ComfyUI（/app）
- 自訂節點：Manager、Custom-Scripts、rgthree、civitai 節點、essentials、Easy-Use、IPAdapter+、ControlNet Aux、KJNodes、Impact Pack/Subpack、AdvancedLivePortrait、Florence2、VideoHelperSuite、GGUF 支援等
- 模型：啟動時執行 `/usr/local/bin/download-models`，預設使用 `/workspace/model-list/models.txt`（若不存在則使用內建 `configs/models.txt`），下載到 `/app/models`
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

### 掛載 Cloudflare R2（comfyui-volume/workspace）

由於 RunPod 不支援 FUSE，改用 **手動同步** 方式：

**環境變數設定**（在 RunPod Template）：

- `CLOUDFLARE_KEY_ID={{ RUNPOD_SECRET_CLOUDFLARE_KEY_ID }}`
- `CLOUDFLARE_TOKEN={{ RUNPOD_SECRET_CLOUDFLARE_TOKEN }}`
- （可選）`S3FS_ENDPOINT=https://f0ab5339fbc3a504a9228b91458c40d2.r2.cloudflarestorage.com`
- （可選）`S3FS_PREFIX=workspace`

**手動同步指令**（在容器內執行）：

```bash
# 從 R2 下載最新資料到 /workspace
r2-sync download   # 或 r2-sync down / r2-sync pull

# 上傳 /workspace 到 R2
r2-sync upload     # 或 r2-sync up / r2-sync push
```

**建議工作流程**：

1. Pod 啟動後：`r2-sync download` 載入之前的工作
2. 工作完成後：`r2-sync upload` 保存到 R2
3. 重要節點隨時執行 `r2-sync upload` 備份

- 掛載失敗時會回退為本地 `/workspace`，並顯示警告。

## 模型下載設定

- 清單：優先讀取 `/workspace/model-list/models.txt`，找不到時退回 `configs/models.txt`；格式 `URL|subdir|filename`
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
