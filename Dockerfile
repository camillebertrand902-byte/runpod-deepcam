# ==============================================================================
# DOCKERFILE - Machine de guerre pour Deep-Live-Cam
# Base : NVIDIA CUDA 12.1 + Ubuntu 22.04
# Bureau : KasmVNC (accès web port 6901)
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
    python3 python3-pip python3-dev python3-venv \
    nginx libnginx-mod-rtmp \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    # Dépendances KasmVNC
    libjpeg-turbo8 libxfont2 libxrandr2 libxrender1 libxcursor1 \
    libxi6 libxtst6 libx11-6 libxext6 libxfixes3 \
    xauth x11-xkb-utils xkb-data \
    python3-xdg \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==============================================================================
# 2. Création de l'utilisateur kasm_user
# ==============================================================================
RUN useradd -m -s /bin/bash kasm_user && \
    echo "kasm_user:password" | chpasswd && \
    echo "kasm_user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# ==============================================================================
# 3. Installation de KasmVNC
# FIX : on utilise la v1.3.0 compatible Ubuntu 22.04, et on installe les
#       dépendances manquantes manuellement via apt --fix-broken
# ==============================================================================
RUN wget -q https://github.com/kasmtech/KasmVNC/releases/download/v1.3.0/kasmvncserver_jammy_1.3.0_amd64.deb \
    && apt-get install -y ./kasmvncserver_jammy_1.3.0_amd64.deb || true \
    && apt-get install -f -y \
    && rm kasmvncserver_jammy_1.3.0_amd64.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Configurer KasmVNC : créer le répertoire de config et définir le mot de passe
RUN mkdir -p /home/kasm_user/.vnc && \
    echo "password" | vncpasswd -f > /home/kasm_user/.vnc/passwd && \
    chmod 600 /home/kasm_user/.vnc/passwd && \
    chown -R kasm_user:kasm_user /home/kasm_user/.vnc

# ==============================================================================
# 4. Google Chrome
# ==============================================================================
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ==============================================================================
# 5. Configuration Nginx RTMP (ultra low latency)
# ==============================================================================
RUN echo 'rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }' \
    > /etc/nginx/conf.d/rtmp.conf

# ==============================================================================
# 6. Dépendances Python globales
# FIX : PyTorch cu121 au lieu de cu118 (cohérence avec CUDA 12.1 de l'image)
# FIX : ajout de --break-system-packages pour Ubuntu 22.04
# ==============================================================================
RUN pip install --upgrade pip setuptools wheel --break-system-packages && \
    pip install --break-system-packages \
        torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 \
        --index-url https://download.pytorch.org/whl/cu121 && \
    pip install --break-system-packages \
        onnxruntime-gpu==1.16.3 \
        opencv-python==4.10.0.84 \
        opencv-contrib-python \
        PySide6==6.6.1 \
        insightface==0.7.3 \
        mediapipe \
        numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python \
        tensorrt

# ==============================================================================
# 7. Script de démarrage
# FIX : utilisation de printf pour éviter les problèmes d'interprétation de \n
#       dans RUN echo; et la commande correcte pour KasmVNC est vncserver
# ==============================================================================
RUN printf '#!/bin/bash\n\
set -e\n\
\n\
# Démarrer KasmVNC en tant que kasm_user\n\
sudo -u kasm_user vncserver :1 -geometry 1920x1080 -depth 24 -localhost no\n\
\n\
# Démarrer Nginx\n\
nginx\n\
\n\
echo ""\n\
echo "============================================================"\n\
echo "Serveur RTMP actif sur le port 1935 (low latency)"\n\
echo "Envoyez votre flux RTMP depuis IP Webcam Pro vers :"\n\
echo "   rtmp://<IP_DU_POD>/live/telephone"\n\
echo "Bureau KasmVNC accessible via HTTP (port 6901)"\n\
echo "   Identifiants : kasm_user / password"\n\
echo "Votre volume persistant est monte sur /workspace"\n\
echo "============================================================"\n\
\n\
# Garder le conteneur vivant\n\
exec sleep infinity\n\
' > /start_services.sh && chmod +x /start_services.sh

# ==============================================================================
# 8. Ports exposés
# ==============================================================================
EXPOSE 6901 1935 80 22

CMD ["/start_services.sh"]
