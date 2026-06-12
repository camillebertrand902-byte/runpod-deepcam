# =============================================================================
# ULTIME DOCKERFILE POUR DEEP-LIVE-CAM SUR RUNPOD
# Base : KasmVNC Ubuntu 20.04 (bureau accessible via navigateur)
# Inclus : Python 3.10, PyTorch 2.1.0 (CUDA 11.8), ONNX Runtime GPU 1.18.0,
#         TensorRT, Nginx RTMP, OBS Studio, Google Chrome, MediaPipe,
#         InsightFace, OpenCV, PySide6, et toutes dépendances.
# =============================================================================

FROM madiator2011/kasm-runpod-desktop:mldesk

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

USER root

# =============================================================================
# 1. Ajout des dépôts supplémentaires (PPA)
# =============================================================================
RUN apt-get update && apt-get install -y software-properties-common wget gnupg curl

# PPA pour Python 3.10 (deadsnakes)
RUN add-apt-repository ppa:deadsnakes/ppa -y
# PPA pour OBS Studio
RUN add-apt-repository ppa:obsproject/obs-studio -y
# PPA pour bibliothèques X11 récentes (facultatif mais utile)
RUN add-apt-repository ppa:ubuntu-x-swat/updates -y

# Mise à jour complète après ajout des dépôts
RUN apt-get update

# =============================================================================
# 2. Paquets système de base + serveur RTMP
# =============================================================================
RUN apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3.10 python3.10-venv python3.10-dev \
    nginx libnginx-mod-rtmp \
    && apt-get clean

# =============================================================================
# 3. Bibliothèques graphiques et accélération GPU
# =============================================================================
RUN apt-get install -y \
    libxcb-cursor0 libxcb-util1 libxcb-icccm4 libxcb-keysyms1 \
    libxcb-randr0 libxcb-shape0 libxcb-xinerama0 libxcb-xfixes0 \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    && apt-get clean

# =============================================================================
# 4. OBS Studio et Google Chrome
# =============================================================================
RUN apt-get install -y obs-studio
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# =============================================================================
# 5. Configuration serveur RTMP (ultra low latency)
# =============================================================================
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# =============================================================================
# 6. Python : mise à jour pip, installation de TensorRT
# =============================================================================
RUN python3.10 -m pip install --upgrade pip setuptools wheel
RUN pip install tensorrt

# =============================================================================
# 7. Installation des dépendances Python "métier"
# =============================================================================
# PyTorch avec CUDA 11.8 (compatible RTX 4090)
RUN pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 \
    --index-url https://download.pytorch.org/whl/cu118

# ONNX Runtime GPU
RUN pip install onnxruntime-gpu==1.18.0

# Vision par ordinateur et interface graphique
RUN pip install opencv-python==4.10.0.84 opencv-contrib-python==4.10.0.84
RUN pip install PySide6==6.6.1

# Reconnaissance faciale et analysis
RUN pip install insightface==0.7.3
RUN pip install mediapipe

# Utilitaires scientifiques et généraux
RUN pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# (Optionnel) Pour éviter les warnings
RUN pip install --upgrade numpy

# =============================================================================
# 8. Script de démarrage (lance Nginx et affiche les infos)
# =============================================================================
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
echo ""\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# =============================================================================
# 9. Ports exposés (KasmVNC, SSH, RTMP, HTTP)
# =============================================================================
EXPOSE 6901 22 1935 80

# =============================================================================
# 10. Commande par défaut
# =============================================================================
CMD ["/start_services.sh"]
