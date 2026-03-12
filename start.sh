#!/bin/bash
set -euo pipefail

WORKDIR=/workspace
COMFY_RUNTIME=/workspace/ComfyUI
COMFY_CACHE=/comfy-cache
CUSTOM_NODES_DIR="$COMFY_RUNTIME/custom_nodes"

mkdir -p "$WORKDIR" "$WORKDIR/output" "$WORKDIR/input" "$WORKDIR/temp" "$WORKDIR/models"
chmod -R 777 "$WORKDIR" || true

if [ ! -d "$COMFY_RUNTIME" ]; then
  cp -r "$COMFY_CACHE" "$COMFY_RUNTIME"
fi
chmod -R 777 "$COMFY_RUNTIME" || true

cd "$COMFY_RUNTIME"

mkdir -p "$CUSTOM_NODES_DIR"
chmod -R 777 "$CUSTOM_NODES_DIR" || true

install_custom_node() {
  local repo_url="$1"
  local dir_name="$2"

  cd "$CUSTOM_NODES_DIR"

  if [ ! -d "$dir_name/.git" ]; then
    git clone --depth 1 "$repo_url" "$dir_name"
  else
    git -C "$dir_name" pull --ff-only || true
  fi

  if [ -f "$dir_name/requirements.txt" ]; then
    pip install -r "$dir_name/requirements.txt" || true
  fi

  chmod -R 777 "$dir_name" || true
  cd "$COMFY_RUNTIME"
}

# Custom nodes from workflow
install_custom_node "https://github.com/rgthree/rgthree-comfy.git" "rgthree-comfy"
install_custom_node "https://github.com/yolain/ComfyUI-Easy-Use.git" "ComfyUI-Easy-Use"

# Added intentionally so Manager button exists in UI
install_custom_node "https://github.com/ltdrdata/ComfyUI-Manager.git" "ComfyUI-Manager"

# Fix ONNX after custom node installs
pip uninstall -y onnxruntime onnxruntime-gpu || true
pip install --no-deps --force-reinstall onnxruntime-gpu==1.24.3 || true

python - <<'PY' || true
try:
    import onnxruntime as ort
    print("[onnx] version:", ort.__version__)
    print("[onnx] providers:", ort.get_available_providers())
except Exception as e:
    print("[onnx][warn] import/providers check failed:", e)
PY

# Model directories
mkdir -p models/checkpoints
mkdir -p models/loras
mkdir -p models/vae
mkdir -p models/text_encoders
mkdir -p models/clip_vision
mkdir -p models/diffusion_models
mkdir -p models/controlnet
mkdir -p models/upscale_models
chmod -R 777 models || true

download_file() {
  local dst_dir="$1"
  local filename="$2"
  local url="$3"

  if [ -s "$dst_dir/$filename" ]; then
    echo "[skip] $filename already exists"
    return 0
  fi

  echo "[download] $filename"
  if ! aria2c \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --check-certificate=false \
    -x 16 -s 16 -k 1M \
    -d "$dst_dir" -o "$filename" "$url"; then
    wget --content-disposition -O "$dst_dir/$filename" "$url"
  fi

  test -s "$dst_dir/$filename"
  chmod 666 "$dst_dir/$filename" || true
}

download_hf_file() {
  local dst_dir="$1"
  local filename="$2"
  local url="$3"

  if [ -s "$dst_dir/$filename" ]; then
    echo "[skip] $filename already exists"
    return 0
  fi

  if [ -z "${HF_TOKEN:-}" ]; then
    echo "[error] HF_TOKEN not set, cannot download $filename from Hugging Face gated repo"
    exit 1
  fi

  echo "[download] $filename from Hugging Face"

  if ! aria2c \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --check-certificate=false \
    --header="Authorization: Bearer ${HF_TOKEN}" \
    -x 16 -s 16 -k 1M \
    -d "$dst_dir" -o "$filename" "$url"; then
    wget \
      --header="Authorization: Bearer ${HF_TOKEN}" \
      --content-disposition \
      -O "$dst_dir/$filename" "$url"
  fi

  test -s "$dst_dir/$filename"
  chmod 666 "$dst_dir/$filename" || true
}

download_civitai_file() {
  local dst_dir="$1"
  local filename="$2"
  local base_url="$3"
  local url="$base_url"

  if [ -s "$dst_dir/$filename" ]; then
    echo "[skip] $filename already exists"
    return 0
  fi

  if [ -n "${CIVITAI_TOKEN:-}" ] && [[ "$url" != *"token="* ]]; then
    if [[ "$url" == *"?"* ]]; then
      url="${url}&token=${CIVITAI_TOKEN}"
    else
      url="${url}?token=${CIVITAI_TOKEN}"
    fi
  fi

  echo "[download] $filename from CivitAI"
  if ! aria2c \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --check-certificate=false \
    -x 16 -s 16 -k 1M \
    -d "$dst_dir" -o "$filename" "$url"; then
    echo "[warn] aria2c failed for $filename, retrying with wget"
    if ! wget --content-disposition -O "$dst_dir/$filename" "$url"; then
      echo "[error] Failed to download $filename from CivitAI"
      echo "[hint] Add CIVITAI_TOKEN to your RunPod template if CivitAI returns 403"
      exit 1
    fi
  fi

  test -s "$dst_dir/$filename"
  chmod 666 "$dst_dir/$filename" || true
}

# =========================
# Public / gated models
# =========================

# diffusion_models
download_hf_file "models/diffusion_models" "flux-2-klein-9b.safetensors" "https://huggingface.co/black-forest-labs/FLUX.2-klein-9B/resolve/main/flux-2-klein-9b.safetensors?download=true"

# text_encoders
download_file "models/text_encoders" "qwen_3_8b.safetensors" "https://huggingface.co/DenRakEiw/qwen3_8b.safetensors/resolve/main/qwen3_8b.safetensors?download=true"

# vae
download_file "models/vae" "flux2-vae.safetensors" "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors"

# upscale_models
download_file "models/upscale_models" "4xPurePhoto-RealPLSKR.pth" "https://huggingface.co/mp3pintyo/upscale/resolve/8c80d55cdc2cc831912ece1848429cd3be52f9e1/4xPurePhoto-RealPLSKR.pth?download=true"

# loras
download_civitai_file "models/loras" "igbaddie-klein.safetensors" "https://civitai.com/api/download/models/2745709?type=Model&format=SafeTensor"

jupyter lab \
  --ip=0.0.0.0 \
  --port=8888 \
  --no-browser \
  --allow-root \
  --ServerApp.token='' \
  --ServerApp.password='' \
  --ServerApp.allow_origin='*' \
  --ServerApp.disable_check_xsrf=True \
  --ServerApp.root_dir=/workspace \
  > /workspace/jupyter.log 2>&1 &

python main.py --listen 0.0.0.0 --port 3000 --highvram --disable-auto-launch
