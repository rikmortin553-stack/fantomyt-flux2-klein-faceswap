# RTX 5090 / Blackwell / FLUX2 Klein FaceSwap
FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    TORCH_CUDA_ARCH_LIST="12.0" \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH"

# 1) System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3-pip \
    git \
    wget \
    curl \
    aria2 \
    ffmpeg \
    ca-certificates \
    build-essential \
    ninja-build \
    pkg-config \
    libgl1 \
    libglib2.0-0 && \
    rm -rf /var/lib/apt/lists/*

# 2) Python and venv
RUN python3.11 -m venv /opt/venv

# 3) pip / setuptools / wheel
RUN /opt/venv/bin/pip install --upgrade pip setuptools wheel

# 4) PyTorch for Blackwell / CUDA 12.8
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# 5) Base Python libraries
RUN pip install \
    numpy \
    Cython \
    pycocotools \
    opencv-python-headless \
    imageio \
    kornia \
    onnxruntime-gpu==1.24.3 \
    ultralytics \
    scikit-image \
    piexif \
    pandas \
    matplotlib \
    pillow \
    scipy \
    segment-anything \
    sqlalchemy \
    spandrel \
    soundfile \
    jupyterlab \
    GitPython \
    dill \
    matrix-client \
    pedalboard

# 6) Prepare ComfyUI inside image
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-build && \
    cd /comfy-build && \
    pip install -r requirements.txt

# 7) Runtime entrypoint
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3000 8888
CMD ["/bin/bash", "/start.sh"]
