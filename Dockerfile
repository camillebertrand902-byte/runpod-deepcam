# ============================================================================
# 1. Image de base KasmVNC (Ubuntu Jammy, KasmVNC pré-installé)
# ============================================================================
FROM kasmweb/ubuntu-jammy-desktop:1.14.0

ENV DEBIAN_FRONTEND=noninteractive

# ============================================================================
# 2. Installation des paquets système
# ============================================================================
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3.10 python3.10-venv python3.10-dev \
    libxcb-cursor0 libxcb-util1 libxcb-icccm4 libxcb-keysyms1 \
    libxcb-randr0 libxcb-shape0 libxcb-xinerama0 libxcb-xfixes0 \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    nginx libnginx-mod-rtmp \
    obs-studio \
    && apt-get clean

# ============================================================================
# 3. Google Chrome
# ============================================================================
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# ============================================================================
# 4. Configuration Nginx RTMP (ultra low latency)
# ============================================================================
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ============================================================================
# 5. Installation TensorRT (via pip)
# ============================================================================
RUN python3.10 -m pip install --upgrade pip setuptools wheel && \
    pip install tensorrt

# ============================================================================
# 6. Dépendances Python globales
# ============================================================================
RUN pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
RUN pip install onnxruntime-gpu==1.18.0
RUN pip install opencv-python==4.10.0.84 opencv-contrib-python==4.10.0.84
RUN pip install PySide6==6.6.1
RUN pip install insightface==0.7.3
RUN pip install mediapipe
RUN pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# ============================================================================
# 7. Script de démarrage (lance Nginx)
# ============================================================================
RUN echo '#!/bin/bash\n\
nginx\n\
echo "✅ Serveur RTMP actif sur le port 1935 (low latency)"\n\
echo "📺 Envoyez votre flux RTMP depuis IP Webcam Pro vers rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Bureau KasmVNC accessible via HTTP (port 6901) – identifiants : kasm_user / password"\n\
echo "📂 Votre volume persistant est monté sur /workspace"\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# ============================================================================
# 8. Ports exposés
# ============================================================================
EXPOSE 6901 22 1935 80
