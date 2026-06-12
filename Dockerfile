# Utilise l'image PyTorch officielle avec CUDA 11.8 et Python 3.10
FROM pytorch/pytorch:2.1.0-cuda11.8-cudnn8-runtime

# Évite les interactions pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

# Installe Nginx avec le module RTMP et les outils nécessaires
RUN apt-get update && \
    apt-get install -y nginx libnginx-mod-rtmp && \
    apt-get clean

# Configure le serveur RTMP
RUN echo "rtmp { server { listen 1935; chunk_size 4096; application live { live on; record off; } } }" > /etc/nginx/conf.d/rtmp.conf

# Script de démarrage qui lance Nginx puis Deep-Live-Cam (si le code est présent dans /workspace)
RUN echo '#!/bin/bash\n\
nginx\n\
cd /workspace/Deep-Live-Cam 2>/dev/null || true\n\
if [ -f /workspace/Deep-Live-Cam/venv/bin/activate ]; then\n\
    source /workspace/Deep-Live-Cam/venv/bin/activate\n\
    python /workspace/Deep-Live-Cam/run.py --execution-provider cuda --frame-processor face_swapper &\n\
fi\n\
sleep infinity' > /start_services.sh && chmod +x /start_services.sh

# Expose les ports RTMP (1935) et HTTP (80)
EXPOSE 1935 80
