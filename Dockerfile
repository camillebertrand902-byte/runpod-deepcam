#!/bin/bash
# ============================================================================
# Script d'installation ultime pour Deep-Live-Cam sur RunPod
# À exécuter UNE SEULE FOIS dans /workspace
# ============================================================================

set -e  # Arrêt en cas d'erreur

WORKSPACE="/workspace"
cd $WORKSPACE

echo "=========================================="
echo "🚀 Installation de l'environnement ultime"
echo "=========================================="

# 1. Mise à jour système et paquets de base
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget curl git vim nano sudo \
    build-essential cmake \
    ffmpeg libavcodec-extra \
    python3.10 python3.10-venv python3.10-dev \
    libxcb-cursor0 libxcb-util1 libxcb-icccm4 libxcb-keysyms1 \
    libxcb-randr0 libxcb-shape0 libxcb-xinerama0 libxcb-xfixes0 \
    libgl1-mesa-dri libgl1-mesa-glx \
    libvulkan1 mesa-vulkan-drivers \
    ocl-icd-opencl-dev opencl-headers \
    nginx libnginx-mod-rtmp \
    obs-studio

# 2. Google Chrome
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
sudo apt install -y ./google-chrome-stable_current_amd64.deb
rm google-chrome-stable_current_amd64.deb

# 3. Configuration Nginx RTMP
sudo tee /etc/nginx/conf.d/rtmp.conf > /dev/null <<EOF
rtmp {
    server {
        listen 1935;
        chunk_size 8192;
        application live {
            live on;
            record off;
        }
    }
}
EOF
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl start nginx

# 4. TensorRT via pip (version CPU-only, mais compatible)
pip install tensorrt

# 5. Environnement Python global (optionnel, mais utile)
sudo update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1
python3.10 -m pip install --upgrade pip setuptools wheel

# 6. Installation des dépendances Python "machine de guerre"
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
pip install onnxruntime-gpu==1.18.0
pip install opencv-python==4.10.0.84 opencv-contrib-python==4.10.0.84
pip install PySide6==6.6.1
pip install insightface==0.7.3
pip install mediapipe
pip install numpy scikit-learn pillow scipy tqdm matplotlib ffmpeg-python pyinstaller

# 7. Cloner Deep-Live-Cam et configurer son venv
if [ ! -d "$WORKSPACE/Deep-Live-Cam" ]; then
    git clone https://github.com/hacksider/Deep-Live-Cam.git
fi
cd Deep-Live-Cam
python3.10 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 --index-url https://download.pytorch.org/whl/cu118
pip install onnxruntime-gpu==1.18.0 opencv-python PySide6 insightface mediapipe
pip install -r requirements.txt

# Télécharger les modèles
mkdir -p models
wget -O models/inswapper_128_fp16.onnx https://github.com/face-swap/inswapper/releases/download/v1.0.0/inswapper_128_fp16.onnx || echo "⚠️ Modèle inswapper non téléchargé (lien mort), il faudra le faire manuellement"
wget -O models/GFPGANv1.4.pth https://github.com/TencentARC/GFPGAN/releases/download/v1.3.0/GFPGANv1.4.pth || echo "⚠️ Modèle GFPGAN non téléchargé"

deactivate
cd ..

echo "=========================================="
echo "✅ Installation terminée !"
echo "📺 Pour envoyer votre flux RTMP :"
echo "   rtmp://<IP_DU_POD>/live/telephone"
echo "🖥️ Pour lancer Deep-Live-Cam :"
echo "   cd /workspace/Deep-Live-Cam && source venv/bin/activate && python run.py --execution-provider cuda --frame-processor face_swapper"
echo "=========================================="
