# ==============================================================================
# DOCKERFILE ULTIME – 100% fonctionnel pour RunPod
# Base : NVIDIA CUDA 12.1 + Ubuntu 22.04 (dépôts complets)
# Bureau : XFCE + TigerVNC + noVNC (accès navigateur port 8080)
# Services : Nginx RTMP (port 1935), OBS, Chrome
# ==============================================================================

FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

USER root

# ------------------------------------------------------------------------------
# 1. Configuration des dépôts Ubuntu (main, universe, restricted, multiverse)
# ------------------------------------------------------------------------------
RUN echo "deb http://archive.ubuntu.com/ubuntu jammy main universe restricted multiverse" > /etc/apt/sources.list && \
    echo "deb http://archive.ubuntu.com/ubuntu jammy-updates main universe restricted multiverse" >> /etc/apt/sources.list && \
    echo "deb http://archive.ubuntu.com/ubuntu jammy-backports main universe restricted multiverse" >> /etc/apt/sources.list && \
    echo "deb http://security.ubuntu.com/ubuntu jammy-security main universe restricted multiverse" >> /etc/apt/sources.list && \
    apt-get update

# ------------------------------------------------------------------------------
# 2. Installation de tous les paquets système (en une seule couche)
# ------------------------------------------------------------------------------
RUN apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3 python3-dev python3-venv \
    nginx libnginx-mod-rtmp \
    xfce4 xfce4-goodies \
    tigervnc-standalone-server tigervnc-common \
    obs-studio \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    && apt-get clean

# ------------------------------------------------------------------------------
# 3. Google Chrome (dernière version stable)
# ------------------------------------------------------------------------------
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# ------------------------------------------------------------------------------
# 4. noVNC (interface web pour VNC)
# ------------------------------------------------------------------------------
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# ------------------------------------------------------------------------------
# 5. Configuration TigerVNC (mot de passe : runpod)
# ------------------------------------------------------------------------------
RUN mkdir -p /root/.vnc && \
    echo "runpod" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd

# Fichier xstartup pour lancer XFCE
COPY --chmod=755 <<-"EOF" /root/.vnc/xstartup
#!/bin/bash
startxfce4 &
EOF

# ------------------------------------------------------------------------------
# 6. Configuration serveur RTMP (ultra low latency)
# ------------------------------------------------------------------------------
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ------------------------------------------------------------------------------
# 7. Dépendances Python (GPU + TensorRT + outils)
# ------------------------------------------------------------------------------
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip install tensorrt && \
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118 && \
    pip install onnxruntime-gpu==1.18.0 && \
    pip install opencv-python==4.10.0.84 opencv-contrib-python && \
    pip install PySide6==6.6.1 && \
    pip install insightface==0.7.3 && \
    pip install mediapipe && \
    pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# ------------------------------------------------------------------------------
# 8. Script de démarrage (lance VNC, noVNC, Nginx)
# ------------------------------------------------------------------------------
RUN echo '#!/bin/bash\n\
# Nettoyer les fichiers verrou X11\n\
rm -f /tmp/.X1-lock\n\
# Démarrer VNC sur le display :1\n\
vncserver :1 -geometry 1920x1080 -depth 24 -localhost no\n\
# Lancer le proxy noVNC\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 8080 &\n\
# Démarrer Nginx\n\
nginx\n\
echo ""\n\
echo "============================================================"\n\
echo "✅ Environnement prêt"\n\
echo "🌐 Bureau accessible sur http://$(hostname -I | cut -d" " -f1):8080/vnc.html"\n\
echo "🔑 Mot de passe VNC : runpod"\n\
echo "📡 RTMP : rtmp://$(hostname -I | cut -d" " -f1)/live/telephone"\n\
echo "📂 Volume persistant : /workspace"\n\
echo "============================================================"\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# ------------------------------------------------------------------------------
# 9. Ports exposés
# ------------------------------------------------------------------------------
EXPOSE 22 80 1935 8080 5901

CMD ["/start_services.sh"]
