# ==============================================================================
# DOCKERFILE ULTIME - Machine de guerre pour Deep-Live-Cam
# Base : NVIDIA CUDA 12.1 + Ubuntu 22.04 (dépôts complets)
# Bureau : KasmVNC installé manuellement (accès web port 6901)
# ==============================================================================

FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

USER root

# ==============================================================================
# 1. Mise à jour des dépôts et installation des paquets de base
# ==============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
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

# ==============================================================================
# 2. Installation de KasmVNC (version officielle, sans erreur de dépendances)
# ==============================================================================
# Télécharger et installer KasmVNC
RUN wget -q https://github.com/kasmtech/KasmVNC/releases/download/v1.2.0/kasmvnc-1.2.0_amd64.deb \
    && apt-get install -y ./kasmvnc-1.2.0_amd64.deb \
    && rm kasmvnc-1.2.0_amd64.deb

# Configurer KasmVNC : définir le mot de passe et l'utilisateur par défaut
RUN echo "kasm_user:password" | chpasswd && \
    echo "kasm_user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ==============================================================================
# 3. Google Chrome
# ==============================================================================
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# ==============================================================================
# 4. Configuration du serveur RTMP (ultra low latency)
# ==============================================================================
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ==============================================================================
# 5. Dépendances Python globales (GPU + TensorRT + outils)
# ==============================================================================
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip install tensorrt && \
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118 && \
    pip install onnxruntime-gpu==1.18.0 && \
    pip install opencv-python==4.10.0.84 opencv-contrib-python && \
    pip install PySide6==6.6.1 && \
    pip install insightface==0.7.3 && \
    pip install mediapipe && \
    pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# ==============================================================================
# 6. Script de démarrage (lance KasmVNC, Nginx)
# ==============================================================================
RUN echo '#!/bin/bash\n\
# Démarrer KasmVNC (service)\n\
/usr/bin/kasmvncserver :1 -geometry 1920x1080 -depth 24 -localhost no\n\
# Démarrer Nginx\n\
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

# ==============================================================================
# 7. Ports exposés
# ==============================================================================
EXPOSE 6901 22 1935 80

CMD ["/start_services.sh"]
