FROM madiator2011/kasm-runpod-desktop:mldesk

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

USER root

# ============================================================================
# 1. Ajout des PPA et mise à jour complète
# ============================================================================
RUN apt-get update && \
    apt-get install -y --no-install-recommends software-properties-common wget gnupg curl && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    add-apt-repository ppa:obsproject/obs-studio -y && \
    add-apt-repository ppa:ubuntu-x-swat/updates -y && \
    apt-get update

# ============================================================================
# 2. Installation massive des paquets système (tout en une seule couche)
# ============================================================================
RUN apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3.10 python3.10-venv python3.10-dev \
    nginx libnginx-mod-rtmp \
    libxcb-cursor0 libxcb-util1 libxcb-icccm4 libxcb-keysyms1 \
    libxcb-randr0 libxcb-shape0 libxcb-xinerama0 libxcb-xfixes0 \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    obs-studio && \
    apt-get clean

# ============================================================================
# 3. Google Chrome (téléchargement direct)
# ============================================================================
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    apt-get install -y ./google-chrome-stable_current_amd64.deb && \
    rm google-chrome-stable_current_amd64.deb

# ============================================================================
# 4. Configuration du serveur RTMP (low latency)
# ============================================================================
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ============================================================================
# 5. Environnement Python global (TensorRT, PyTorch, ONNX, etc.)
# ============================================================================
RUN python3.10 -m pip install --upgrade pip setuptools wheel && \
    pip install tensorrt && \
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118 && \
    pip install onnxruntime-gpu==1.18.0 && \
    pip install opencv-python==4.10.0.84 opencv-contrib-python && \
    pip install PySide6==6.6.1 && \
    pip install insightface==0.7.3 && \
    pip install mediapipe && \
    pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# ============================================================================
# 6. Script de démarrage (lance nginx et affiche les infos)
# ============================================================================
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

# ============================================================================
# 7. Ports exposés (KasmVNC, SSH, RTMP, HTTP)
# ============================================================================
EXPOSE 6901 22 1935 80

CMD ["/start_services.sh"]
