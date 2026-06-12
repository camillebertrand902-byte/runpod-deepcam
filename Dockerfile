# ============================================================================
# Base : KasmVNC (Ubuntu 20.04) – bureau graphique fonctionnel
# ============================================================================
FROM madiator2011/kasm-runpod-desktop:mldesk

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

USER root

# ============================================================================
# 1. Ajout des dépôts pour paquets modernes (deadsnakes, obs-studio, xcb)
# ============================================================================
RUN apt-get update && apt-get install -y software-properties-common wget gnupg && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    add-apt-repository ppa:obsproject/obs-studio -y && \
    add-apt-repository ppa:ubuntu-x-swat/updates -y && \
    apt-get update

# ============================================================================
# 2. Installation des paquets système (en deux passes pour éviter les erreurs)
# ============================================================================
# 2a. Paquets de base + Python 3.10
RUN apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3.10 python3.10-venv python3.10-dev \
    nginx libnginx-mod-rtmp \
    && apt-get clean

# 2b. Bibliothèques X11 (maintenant disponibles via le PPA ubuntu-x-swat)
RUN apt-get install -y \
    libxcb-cursor0 libxcb-util1 libxcb-icccm4 libxcb-keysyms1 \
    libxcb-randr0 libxcb-shape0 libxcb-xinerama0 libxcb-xfixes0 \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    && apt-get clean

# 2c. OBS Studio (depuis le PPA obsproject)
RUN apt-get install -y obs-studio && apt-get clean

# ============================================================================
# 3. Google Chrome (téléchargement direct)
# ============================================================================
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# ============================================================================
# 4. Configuration Nginx RTMP (low latency)
# ============================================================================
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ============================================================================
# 5. TensorRT via pip (version Python)
# ============================================================================
RUN python3.10 -m pip install --upgrade pip setuptools wheel && \
    pip install tensorrt

# ============================================================================
# 6. Dépendances Python globales (PyTorch, ONNX, etc.)
# ============================================================================
RUN pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
RUN pip install onnxruntime-gpu==1.18.0
RUN pip install opencv-python==4.10.0.84 opencv-contrib-python==4.10.0.84
RUN pip install PySide6==6.6.1
RUN pip install insightface==0.7.3
RUN pip install mediapipe
RUN pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# ============================================================================
# 7. Script de démarrage (lance Nginx + affiche infos)
# ============================================================================
RUN echo '#!/bin/bash\n\
nginx\n\
echo "=========================================="\n\
echo "✅ Serveur RTMP actif sur le port 1935"\n\
echo "📺 Envoyez votre flux RTMP vers rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Bureau KasmVNC accessible via HTTP (port 6901)"\n\
echo "   Identifiants : kasm_user / password"\n\
echo "📂 Votre volume persistant est monté sur /workspace"\n\
echo "=========================================="\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# ============================================================================
# 8. Ports exposés
# ============================================================================
EXPOSE 22 80 1935 6901

# ============================================================================
# 9. Commande par défaut
# ============================================================================
CMD ["/start_services.sh"]
