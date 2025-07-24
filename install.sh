#!/bin/bash
# bachkhoabk47@gmail.com

# OpenCPS is the open source Core Public Services software
# Copyright (C) 2016-present OpenCPS community

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.


############## Installing for Ubuntu (Updated for modern Docker) #####################################

DIR="`pwd`"
DIR_CURR=$DIR/docker-compose-allinone

############### Check Ubuntu and root permissions ########################
# Check if running on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    echo "Error: This script only supports Ubuntu. Please run on Ubuntu system."
    exit 1
fi

echo "Detected Ubuntu system - proceeding with installation..."

# Check root permissions
if [ "$EUID" -ne 0 ]; then
    echo "You are not running with root permission. Please run with sudo:"
    echo "sudo bash $0"
    exit 1
else
    echo "Good! You are running with root permission!"
fi

app_update() {
    echo "Updating package lists..."
    apt-get update -y
    apt-get install -y curl wget ca-certificates gnupg lsb-release
}

install_git() {
    if which git >/dev/null; then
        echo "git is already installed"
    else
        echo "Installing git..."
        apt-get install -y git
    fi
}

install_docker() {
    if which docker >/dev/null; then
        echo "Docker is already installed"
        docker --version
    else
        echo "Installing Docker using official Docker repository..."
        
        # Remove old versions
        apt-get remove -y docker docker-engine docker.io containerd runc
        
        # Add Docker's official GPG key
        mkdir -p /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        
        # Add Docker repository
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        apt-get update -y
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        
        # Add current user to docker group if not root
        if [ "$SUDO_USER" ]; then
            usermod -aG docker "$SUDO_USER"
            echo "Added user $SUDO_USER to docker group"
        fi
        
        echo "Docker installed successfully!"
        docker --version
    fi

    # Check if docker-compose is available (either standalone or plugin)
    if docker compose version >/dev/null 2>&1; then
        echo "Docker Compose plugin is available"
        docker compose version
    elif which docker-compose >/dev/null; then
        echo "Docker Compose standalone is available"
        docker-compose --version
    else
        echo "Installing Docker Compose standalone as fallback..."
        # Get latest version
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
        curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        echo "Docker Compose installed successfully!"
        docker-compose --version
    fi
}

setup_dependencies() {
    echo "Setting up dependencies for OpenCPS deployment..."
    app_update
    install_git
    install_docker
    
    echo "All dependencies installed successfully!"
}

# Run setup
setup_dependencies

######################## DEPLOYING OPENCPS APPLICATION ##################
# Skip downloading - using existing docker-compose-allinone folder

echo "Working directory: $DIR_CURR"

if [ ! -d "$DIR_CURR" ] || [ ! -f "$DIR_CURR/docker-compose.yml" ]; then
    echo "Error: docker-compose-allinone folder not found or missing docker-compose.yml file"
    echo "Please ensure $DIR_CURR exists and contains docker-compose.yml"
    exit 1
fi

echo "Found existing docker-compose-allinone folder. Starting OpenCPS containers..."
cd "$DIR_CURR"

# Use docker compose (new syntax) or docker-compose (fallback)
if docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose.yml up -d
else
    docker-compose -f docker-compose.yml up -d
fi

echo "Done! You can open browser at: http://localhost:8080 to access the application."
echo "Please wait a few minutes for all services to start completely."

# Post-installation instructions
echo ""
echo "=== POST-INSTALLATION NOTES ==="
if [ "$SUDO_USER" ]; then
    echo "User $SUDO_USER has been added to the docker group."
    echo "Please log out and log back in, or run 'newgrp docker' to use docker without sudo."
fi
echo "You can check container status with: docker ps"
echo "To stop all containers: cd $DIR_CURR && docker compose down"
echo "To view logs: cd $DIR_CURR && docker compose logs"