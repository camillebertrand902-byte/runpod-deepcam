FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive

# ======================
# Outils système de base
# ======================
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    ffmpeg \
    ca-certificates \
    && apt-get clean

# ======================
# Google Chrome
# ======================
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && apt-get clean

# ======================
# OBS Studio
# ======================
RUN apt-get update && apt-get install -y --no-install-recommends \
    obs-studio \
    && apt-get clean

# ======================
# Serveur RTMP (Nginx)
# ======================
RUN apt-get update && apt-get install -y nginx libnginx-mod-rtmp \
    && apt-get clean

# Configuration RTMP
RUN echo "rtmp { server { listen 1935; chunk_size 4096; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ======================
# Dépendances graphiques supplémentaires
# (nécessaires pour OBS/Chrome sous X11)
# ======================
RUN apt-get update && apt-get install -y \
    libxcb-cursor0 \
    libxcb-util1 \
    libxcb-icccm4 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-shape0 \
    libxcb-xinerama0 \
    libxcb-xfixes0 \
    libgl1-mesa-dri \
    libgl1-mesa-glx \
    && apt-get clean

# ======================
# Script de démarrage
# (lance Nginx, puis laisse l'utilisateur démarrer le reste depuis le bureau)
# ======================
RUN echo '#!/bin/bash\n\
nginx\n\
echo "✅ Nginx RTMP démarré sur le port 1935"\n\
echo "📺 Envoie ton flux depuis IP Webcam Pro vers rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Tu peux maintenant lancer Deep-Live-Cam et OBS depuis le bureau."\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# Ports exposés
EXPOSE 1935 80
