FROM kasmweb/ubuntu-jammy-desktop:1.14.0

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

USER root

# Écraser le fichier sources.list avec des miroirs Ubuntu valides (main, universe, restricted, multiverse)
RUN echo "deb http://archive.ubuntu.com/ubuntu jammy main universe restricted multiverse" > /etc/apt/sources.list && \
    echo "deb http://archive.ubuntu.com/ubuntu jammy-updates main universe restricted multiverse" >> /etc/apt/sources.list && \
    echo "deb http://archive.ubuntu.com/ubuntu jammy-backports main universe restricted multiverse" >> /etc/apt/sources.list && \
    echo "deb http://security.ubuntu.com/ubuntu jammy-security main universe restricted multiverse" >> /etc/apt/sources.list && \
    apt-get update

# Installation des paquets système
RUN apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3 python3-dev python3-venv \
    nginx libnginx-mod-rtmp \
    obs-studio \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    && apt-get clean

# Google Chrome
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# Configuration serveur RTMP (ultra low latency)
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# Dépendances Python globales (GPU + TensorRT + outils)
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip install tensorrt && \
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118 && \
    pip install onnxruntime-gpu==1.18.0 && \
    pip install opencv-python==4.10.0.84 opencv-contrib-python && \
    pip install PySide6==6.6.1 && \
    pip install insightface==0.7.3 && \
    pip install mediapipe && \
    pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# Script de démarrage (lance Nginx uniquement, KasmVNC déjà démarré par l'image)
RUN echo '#!/bin/bash\n\
nginx\n\
echo ""\n\
echo "============================================================"\n\
echo "✅ Serveur RTMP actif sur le port 1935 (low latency)"\n\
echo "📺 Envoyez votre flux RTMP depuis IP Webcam Pro vers :"\n\
echo "   rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Bureau KasmVNC accessible via HTTP (port 6901)"\n\
echo "   Identifiants : kasm_user / password"\n\
echo "📂 Votre volume persistant est monté sur /workspace"\n\
echo "============================================================"\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# Ports exposés
EXPOSE 6901 22 1935 80

CMD ["/start_services.sh"]
