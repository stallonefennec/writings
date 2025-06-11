#!/bin/bash

# ==============================================================================
#                 One-Click Essentials Installer for Ubuntu
#
# This script installs and configures:
#   - Common command-line utilities (curl, wget, htop, etc.)
#   - The latest version of Git from the official PPA
#   - The latest version of Docker Engine from the official Docker repository
#   - The latest version of Docker Compose (v2)
#
# Usage:
#   1. Save this script as install_essentials.sh
#   2. Make it executable: chmod +x install_essentials.sh
#   3. Run it: ./install_essentials.sh
#
# ==============================================================================

# --- Color Definitions ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---
print_info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# --- Script Start ---
# Ensure the script is run with sudo privileges
if [ "$EUID" -ne 0 ]; then
  print_warning "This script requires superuser privileges. Re-running with sudo..."
  sudo "$0" "$@"
  exit $?
fi

# Set non-interactive frontend to avoid prompts during installation
export DEBIAN_FRONTEND=noninteractive

# 1. Update and Upgrade System Packages
print_info "Updating package lists and upgrading the system..."
apt-get update && apt-get upgrade -y
print_success "System updated and upgraded."

# 2. Install Common Command-Line Utilities
print_info "Installing common utilities (curl, wget, unzip, htop, neofetch, iputils-ping)..."
apt-get install -y curl wget unzip htop neofetch iputils-ping software-properties-common ca-certificates apt-transport-https
print_success "Common utilities installed."

# 3. Install Latest Git
print_info "Adding Git PPA and installing the latest version..."
add-apt-repository ppa:git-core/ppa -y
apt-get update
apt-get install -y git
print_success "Latest Git installed."

# 4. Install Latest Docker Engine
print_info "Setting up Docker repository and installing Docker Engine..."
# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update

# Install Docker packages
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
print_success "Docker Engine installed."

# 5. Configure Docker for non-root user
CURRENT_USER=${SUDO_USER:-$(whoami)}
if id -nG "$CURRENT_USER" | grep -qw "docker"; then
    print_info "User '$CURRENT_USER' is already in the 'docker' group."
else
    print_info "Adding user '$CURRENT_USER' to the 'docker' group..."
    usermod -aG docker "$CURRENT_USER"
    print_warning "You need to log out and log back in for the group changes to take effect."
    print_warning "Alternatively, you can run 'newgrp docker' in your terminal."
fi
print_success "Docker non-root user configuration complete."

# 6. Install Docker Compose (Standalone v2) - Optional but recommended
# This step is technically redundant if docker-compose-plugin was installed, but good for standalone use.
print_info "Checking/Installing standalone Docker Compose v2..."
COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
DOCKER_COMPOSE_PATH="/usr/local/bin/docker-compose"
if [ -f "$DOCKER_COMPOSE_PATH" ]; then
    print_info "Standalone docker-compose already exists. Skipping installation."
else
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o $DOCKER_COMPOSE_PATH
    chmod +x $DOCKER_COMPOSE_PATH
    print_success "Standalone Docker Compose v2 installed at $DOCKER_COMPOSE_PATH"
fi


# 7. Clean up
print_info "Cleaning up apt cache..."
apt-get autoremove -y
apt-get clean
print_success "Cleanup complete."

# 8. Display Versions
print_info "Installation summary:"
echo "-------------------------------------"
git --version
docker --version
docker compose version
curl --version | head -n 1
wget --version | head -n 1
htop --version | head -n 1
echo "-------------------------------------"
print_success "All essential tools have been installed successfully!"
echo -e "${YELLOW}IMPORTANT: Please log out and log back in to use Docker without sudo.${NC}"