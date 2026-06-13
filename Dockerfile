FROM kasmweb/ubuntu-jammy-desktop:1.14.0

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

USER root

# Activer tous les dépôts (main, universe, restricted, multiverse) sans utiliser add-apt-repository
RUN sed -i 's/^# deb /deb /' /etc/apt/sources.list && \
    apt-get update

# Installation des paquets système (noms corrigés)
RUN apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3 python3-dev python3-venv \
    nginx libnginx-mod-rtmp \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    && apt-get clean

# Google Chrome
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# OBS Studio (téléchargement direct, pas besoin de PPA)
RUN wget -q https://github.com/obsproject/obs-studio/releases/download/30.1.2/obs-studio-30.1.2-linux-x86_64.deb \
    && apt-get install -y ./obs-studio-30.1.2-linux-x86_64.deb || true \
    && rm -f obs-studio-30.1.2-linux-x86_64.deb

# Configuration RTMP
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# Dépendances Python globales (utilise python3)
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip install tensorrt && \
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118 && \
    pip install onnxruntime-gpu==1.18.0 && \
    pip install opencv-python==4.10.0.84 opencv-contrib-python && \
    pip install PySide6==6.6.1 && \
    pip install insightface==0.7.3 && \
    pip install mediapipe && \
    pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# Script de démarrage
RUN echo '#!/bin/bash\n\
nginx\n\
echo ""\n\
echo "============================================================"\n\
echo "✅ Serveur RTMP actif sur le port 1935"\n\
echo "📺 Envoyez votre flux RTMP vers rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Bureau KasmVNC sur port 6901 (kasm_user / password)"\n\
echo "📂 Volume persistant monté sur /workspace"\n\
echo "============================================================"\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

EXPOSE 6901 22 1935 80

CMD ["/start_services.sh"]
