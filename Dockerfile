# Utilise une image de base stable contenant déjà Python et CUDA
FROM runpod/pytorch:2.1.0-py3.10-cuda11.8.0-ubuntu22.04

# Évite les messages de confirmation pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

# Met à jour la liste des logiciels et installe Nginx avec le module RTMP
RUN apt-get update && \
    apt-get install -y nginx libnginx-mod-rtmp && \
    apt-get clean

# Configure le serveur RTMP pour accepter un flux vidéo
RUN echo "rtmp { server { listen 1935; chunk_size 4096; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# Crée un script qui démarrera Nginx puis Deep-Live-Cam au lancement du Pod
RUN echo '#!/bin/bash\n\
nginx\n\
cd /workspace/Deep-Live-Cam\n\
source venv/bin/activate\n\
python run.py --execution-provider cuda --frame-processor face_swapper\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# Indique les ports qui seront ouverts pour recevoir le flux vidéo et pour l'interface
EXPOSE 1935 80
