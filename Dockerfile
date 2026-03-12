# RTX 4090 / image-oriented ComfyUI build for FLUX2 Klein FaceSwap workflow
FROM runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# 1) System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
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

# 2) Python tooling
RUN pip install --upgrade pip setuptools wheel

# 3) Stable image-workflow dependency base for RTX 4090
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

# 4) Cache ComfyUI inside the image
RUN git clone https://github.com/comfyanonymous/ComfyUI.git /comfy-cache && \
    cd /comfy-cache && \
    pip install -r requirements.txt

# 5) Runtime entrypoint
COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 3000 8888
CMD ["/bin/bash", "/start.sh"]
