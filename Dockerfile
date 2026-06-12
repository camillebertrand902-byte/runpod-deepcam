FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

ENV DEBIAN_FRONTEND=noninteractive

# ======================
# 1. Outils système de base
# ======================
# On ajoute 'gnupg' ici pour résoudre l'erreur et s'assurer que tout est bien installé.
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git vim nano sudo \
    ffmpeg \
    ca-certificates \
    gnupg \
    && apt-get clean

# ======================
# 2. Google Chrome (installation via le fichier .deb)
# ======================
# On télécharge le fichier .deb officiel et on l'installe directement,
# ce qui est plus simple et évite de gérer les clés GPG.
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
    && apt-get install -y ./google-chrome-stable_current_amd64.deb \
    && rm google-chrome-stable_current_amd64.deb \
    && apt-get clean

# ======================
# 3. OBS Studio
# ======================
RUN apt-get update && apt-get install -y --no-install-recommends \
    obs-studio \
    && apt-get clean

# ======================
# 4. Serveur RTMP (Nginx)
# ======================
RUN apt-get update && apt-get install -y nginx libnginx-mod-rtmp \
    && apt-get clean

# Configuration RTMP
RUN echo "rtmp { server { listen 1935; chunk_size 4096; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# ======================
# 5. Dépendances graphiques (pour OBS et Chrome)
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
# 6. Script de démarrage
# ======================
RUN echo '#!/bin/bash\n\
nginx\n\
echo "✅ Nginx RTMP démarré sur le port 1935"\n\
echo "📺 Envoie ton flux depuis IP Webcam Pro vers rtmp://<IP_DU_POD>/live/telephone"\n\
echo "🖥️ Tu peux maintenant lancer Deep-Live-Cam et OBS depuis le bureau."\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# Ports exposés
EXPOSE 1935 80
