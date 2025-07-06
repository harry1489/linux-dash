#!/bin/bash

# --- Open WebUI Installation Script for Rocky Linux 9 (New Server) ---

echo "Starting Open WebUI installation on Rocky Linux 9..."

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo."
   exit 1
fi

# 1. Update the system
echo "Updating the system. This may take a few minutes..."
dnf update -y

# 2. Install Docker if not already installed
echo "Checking for Docker installation..."
if ! command -v docker &> /dev/null
then
    echo "Docker not found. Installing Docker..."
    dnf install -y dnf-plugins-core
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker service
    echo "Starting and enabling Docker service..."
    systemctl start docker
    systemctl enable docker

    # Add current user to docker group to run docker commands without sudo (optional, but recommended)
    echo "Adding current user to docker group. You may need to log out and back in for this to take effect."
    usermod -aG docker "$SUDO_USER"
else
    echo "Docker is already installed."
fi

# 3. Install Git (needed for cloning the Open WebUI repository if using source, but we'll use Docker directly)
echo "Ensuring git is installed..."
dnf install -y git

# 4. Pull and run Open WebUI using Docker Compose
echo "Setting up Open WebUI with Docker Compose..."

# Create a directory for Open WebUI
mkdir -p ~/open-webui
cd ~/open-webui

# Create a docker-compose.yml file
cat <<EOL > docker-compose.yml
version: '3.8'
services:
  open-webui:
    image: ghcr.io/open-webui/open-webui:latest
    container_name: open-webui
    ports:
      - "8080:8080" # You can change the host port (e.g., "9000:8080")
    volumes:
      - ./data:/app/backend/data
    environment:
      - OLLAMA_API_BASE_URL=http://172.17.0.1:11434 # This assumes Ollama is running on the host machine.
                                                 # 172.17.0.1 is the default Docker bridge IP for the host.
                                                 # If Ollama is on a different IP, adjust this.
                                                 # If Ollama is on a different server, replace 172.17.0.1 with its IP.
    restart: always
EOL

# Bring up the Docker Compose services
echo "Bringing up Open WebUI container..."
docker compose up -d

# 5. Open firewall port for Open WebUI
echo "Opening port 8080 in firewall..."
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

echo ""
echo "Open WebUI installation complete!"
echo "If you added your user to the 'docker' group, you might need to log out and back in for changes to take effect."
echo "You can check the container status with: docker ps -a"
echo "To stop Open WebUI: cd ~/open-webui && docker compose down"
echo "To start Open WebUI: cd ~/open-webui && docker compose up -d"
echo ""
echo "SELinux Note: If you encounter permission issues later, especially with Docker, you might need to adjust SELinux policies or temporarily set it to permissive mode."
echo "  To set permissive: setenforce 0"
echo "  To make permanent (edit /etc/selinux/config): SELINUX=permissive"
