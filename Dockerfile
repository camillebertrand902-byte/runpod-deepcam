# ============================================================================
# BASE : Bureau KasmVNC (Ubuntu 22.04) – compatible GPU RunPod
# ============================================================================
FROM madiator2011/kasm-runpod-desktop:mldesk

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# ============================================================================
# 1. Mise à jour et installation des paquets systèmes (dont FFmpeg, compilateurs)
# ============================================================================
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
    && apt-get clean

# ============================================================================
# 2. Google Chrome (pour tester les flux HLS / WebRTC)
# ============================================================================
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# ============================================================================
# 3. OBS Studio (dernière version)
# ============================================================================
RUN apt-get update && apt-get install -y obs-studio \
    && apt-get clean

# ============================================================================
# 4. Serveur RTMP (Nginx) – ultra low latency
# ============================================================================
RUN apt-get update && apt-get install -y nginx libnginx-mod-rtmp \
    && apt-get clean
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ============================================================================
# 5. TensorRT (accélération maximale pour RTX 4090)
# ============================================================================
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository ppa:graphics-drivers/ppa \
    && apt-get update && apt-get install -y \
    nvidia-cuda-toolkit \
    libnvinfer8 libnvinfer-dev libnvinfer-plugin8 \
    && apt-get clean

# ============================================================================
# 6. Python 3.10 et dépendances globales
# ============================================================================
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
RUN python3.10 -m pip install --upgrade pip setuptools wheel

# ============================================================================
# 7. Installation des dépendances Python "machine de guerre"
# ============================================================================
# PyTorch avec CUDA 11.8
RUN pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
# ONNX Runtime GPU + TensorRT
RUN pip install onnxruntime-gpu==1.18.0 tensorrt
# OpenCV, PySide6, InsightFace, MediaPipe
RUN pip install opencv-python==4.10.0.84 opencv-contrib-python==4.10.0.84
RUN pip install PySide6==6.6.1
RUN pip install insightface==0.7.3
RUN pip install mediapipe
# Autres dépendances
RUN pip install numpy scikit-learn pillow scipy tqdm matplotlib
# Outils de packaging
RUN pip install pyinstaller
# Git (déjà installé)
# FFmpeg Python bindings
RUN pip install ffmpeg-python

# ============================================================================
# 8. Script de démarrage persistant (lance Nginx + prépare Deep-Live-Cam)
# ============================================================================
RUN echo '#!/bin/bash\n\
nginx\n\
echo "✅ Serveur RTMP actif sur le port 1935 (low latency)"\n\
echo "📺 Envoyez votre flux RTMP depuis IP Webcam Pro vers rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Bureau KasmVNC – identifiants : kasm_user / password"\n\
echo "📂 Volume persistant monté sur /workspace"\n\
\n\
# Cloner Deep-Live-Cam dans /workspace s’il n’existe pas\n\
if [ ! -d /workspace/Deep-Live-Cam ]; then\n\
    echo "⚙️ Clonage de Deep-Live-Cam..."\n\
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
    # Téléchargement des modèles (si liens valides)\n\
    wget -O models/inswapper_128_fp16.onnx https://github.com/face-swap/inswapper/releases/download/v1.0.0/inswapper_128_fp16.onnx || true\n\
    wget -O models/GFPGANv1.4.pth https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.4.pth || true\n\
    echo "✅ Deep-Live-Cam prêt dans /workspace/Deep-Live-Cam"\n\
fi\n\
\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# ============================================================================
# 9. Ports exposés (SSH, RTMP, HTTP)
# ============================================================================
EXPOSE 22 1935 80
