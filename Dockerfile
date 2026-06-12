FROM madiator2011/kasm-runpod-desktop:mldesk

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# ============================================================================
# Mise à jour et installation des paquets (compatibles Ubuntu 20.04)
# ============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3.10 python3.10-venv python3.10-dev \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    && apt-get clean

# ============================================================================
# Installation des bibliothèques X11 manquantes (via PPA si nécessaire)
# ============================================================================
RUN add-apt-repository ppa:ubuntu-x-swat/updates -y && \
    apt-get update && apt-get install -y \
    libxcb-cursor0 libxcb-util1 libxcb-icccm4 libxcb-keysyms1 \
    libxcb-randr0 libxcb-shape0 libxcb-xinerama0 libxcb-xfixes0 || true

# ============================================================================
# OBS Studio via PPA officiel
# ============================================================================
RUN add-apt-repository ppa:obsproject/obs-studio -y && \
    apt-get update && apt-get install -y obs-studio

# ============================================================================
# Google Chrome
# ============================================================================
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# ============================================================================
# Serveur RTMP (Nginx)
# ============================================================================
RUN apt-get install -y nginx libnginx-mod-rtmp
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ============================================================================
# TensorRT (installé via pip + système)
# ============================================================================
RUN apt-get install -y software-properties-common && \
    add-apt-repository ppa:graphics-drivers/ppa -y && \
    apt-get update && apt-get install -y \
    libnvinfer8 libnvinfer-dev libnvinfer-plugin8 || true

# ============================================================================
# Python 3.10 et dépendances globales
# ============================================================================
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
RUN python3.10 -m pip install --upgrade pip setuptools wheel

# ============================================================================
# Installation des dépendances Python
# ============================================================================
RUN pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
RUN pip install onnxruntime-gpu==1.18.0 tensorrt
RUN pip install opencv-python==4.10.0.84 opencv-contrib-python==4.10.0.84
RUN pip install PySide6==6.6.1
RUN pip install insightface==0.7.3
RUN pip install mediapipe
RUN pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# ============================================================================
# Script de démarrage
# ============================================================================
RUN echo '#!/bin/bash\n\
nginx\n\
echo "✅ Serveur RTMP actif sur le port 1935"\n\
echo "📺 Envoyez votre flux RTMP vers rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Bureau KasmVNC – identifiants : kasm_user / password"\n\
if [ ! -d /workspace/Deep-Live-Cam ]; then\n\
    cd /workspace\n\
    git clone https://github.com/hacksider/Deep-Live-Cam.git\n\
    cd Deep-Live-Cam\n\
    python3.10 -m venv venv\n\
    source venv/bin/activate\n\
    pip install --upgrade pip\n\
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118\n\
    pip install onnxruntime-gpu==1.18.0 tensorrt opencv-python PySide6 insightface mediapipe\n\
    pip install -r requirements.txt\n\
    mkdir -p models\n\
    wget -O models/inswapper_128_fp16.onnx https://github.com/face-swap/inswapper/releases/download/v1.0.0/inswapper_128_fp16.onnx || true\n\
    wget -O models/GFPGANv1.4.pth https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.4.pth || true\n\
fi\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

EXPOSE 22 1935 80
