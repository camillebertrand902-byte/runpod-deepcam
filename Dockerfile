FROM nvidia/cuda:12.1.0-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_VISIBLE_DEVICES=0
ENV TORCH_CUDA_ARCH_LIST="8.9"
ENV OMP_NUM_THREADS=8
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

USER root

# 1. Mettre à jour les dépôts et installer les paquets système en plusieurs couches
RUN echo "deb http://archive.ubuntu.com/ubuntu jammy main universe restricted multiverse" > /etc/apt/sources.list && \
    echo "deb http://archive.ubuntu.com/ubuntu jammy-updates main universe restricted multiverse" >> /etc/apt/sources.list && \
    echo "deb http://archive.ubuntu.com/ubuntu jammy-backports main universe restricted multiverse" >> /etc/apt/sources.list && \
    echo "deb http://security.ubuntu.com/ubuntu jammy-security main universe restricted multiverse" >> /etc/apt/sources.list && \
    apt-get update

# 2. Installer tigervnc en premier (pour avoir vncpasswd)
RUN apt-get install -y --no-install-recommends tigervnc-common tigervnc-standalone-server

# 3. Installer le reste des paquets
RUN apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3 python3-dev python3-venv \
    nginx libnginx-mod-rtmp \
    xfce4 xfce4-goodies \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    obs-studio \
    && apt-get clean

# 4. Vérifier que vncpasswd existe (optionnel, mais rassurant)
RUN which vncpasswd || (apt-get update && apt-get install -y tigervnc-common)

# 5. Installer Google Chrome
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb

# 6. Installer noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# 7. Configurer TigerVNC (création du mot de passe)
RUN mkdir -p /root/.vnc && \
    echo "runpod" | vncpasswd -f > /root/.vnc/passwd && \
    chmod 600 /root/.vnc/passwd
COPY --chmod=755 <<-"EOF" /root/.vnc/xstartup
#!/bin/bash
startxfce4 &
EOF

# 8. Configurer Nginx RTMP
RUN echo "rtmp { server { listen 1935; chunk_size 8192; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# 9. Installer les dépendances Python globales
RUN python3 -m pip install --upgrade pip setuptools wheel && \
    pip install tensorrt && \
    pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118 && \
    pip install onnxruntime-gpu==1.18.0 && \
    pip install opencv-python==4.10.0.84 opencv-contrib-python && \
    pip install PySide6==6.6.1 && \
    pip install insightface==0.7.3 && \
    pip install mediapipe && \
    pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# 10. Script de démarrage
RUN echo '#!/bin/bash\n\
vncserver :1 -geometry 1920x1080 -depth 24 -localhost no\n\
/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 8080 &\n\
nginx\n\
echo ""\n\
echo "============================================================"\n\
echo "✅ Serveur RTMP actif sur le port 1935"\n\
echo "📺 Envoyez votre flux RTMP vers rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Bureau accessible via : http://<IP_DU_POD>:8080/vnc.html"\n\
echo "   Mot de passe VNC : runpod"\n\
echo "📂 Volume persistant monté sur /workspace"\n\
echo "============================================================"\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# 11. Ports exposés
EXPOSE 22 80 1935 8080 5901

CMD ["/start_services.sh"]
