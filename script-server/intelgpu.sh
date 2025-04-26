#!/bin/bash

set -e  # Exit on error

# Uninstall conflicting packages
sudo apt remove -y containerd docker.io docker-compose

# Install dependencies
sudo apt update
sudo apt install -y ca-certificates curl gnupg lsb-release intel-gpu-tools clinfo vainfo

# Add Docker’s official GPG key and repository
sudo mkdir -m 0755 -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Enable Intel GPU for Docker containers
sudo usermod -aG docker mosgarage
sudo usermod -aG video mosgarage  # Ensure access to GPU devices

# Install Intel GPU runtime
sudo apt install -y intel-opencl-icd intel-media-va-driver libmfx1 libva-drm2 libva-x11-2

# Verify GPU detection
lspci | grep -i 'vga\|3d'
clinfo | grep 'Intel'

# Configure Docker to use Intel GPU runtime
sudo mkdir -p /etc/docker
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "runtimes": {
    "intel-gpu": {
      "path": "/usr/bin/intel_gpu_runtime"
    }
  }
}
EOF

# Restart Docker to apply changes
sudo systemctl restart docker

# Test GPU inside a container
docker run --rm --device /dev/dri --group-add video debian bash -c "ls -l /dev/dri && clinfo"

echo "Intel GPU support is now enabled for Docker! Please log out and log back in for group changes to take effect."
