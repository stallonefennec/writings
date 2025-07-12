#!/bin/bash

# ==============================================================================
#           System Repair & Essentials Installer for Debian
#
# This script performs a clean installation of Node.js, pnpm, and Docker.
# It is specifically designed to fix previous installation issues by:
#   1. Purging any system-level Node.js/npm packages.
#   2. Installing nvm (Node Version Manager) for the primary user.
#   3. Using nvm to install Node.js v22+.
#   4. Using Corepack to install the latest pnpm.
#   5. Installing the latest Docker Engine and Compose for DEBIAN.
#   6. Configuring Docker to be run by the current user without sudo.
#
# Usage:
#   1. Save this script as repair_install.sh
#   2. Make it executable: chmod +x repair_install.sh
#   3. Run with sudo: sudo ./repair_install.sh
#
# ==============================================================================

# --- Color Definitions ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Helper Functions ---
print_info() {
    echo -e "\n${BLUE}[INFO] $1${NC}"
}

print_success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# --- Script Start ---
# 1. Ensure the script is run with sudo privileges
if [ "$EUID" -ne 0 ]; then
  print_warning "This script requires superuser privileges. Please run with: sudo ./repair_install.sh"
  exit 1
fi

# Get the user who invoked sudo, not root
TARGET_USER=${SUDO_USER:-$(whoami)}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# Set non-interactive frontend to avoid prompts during installation
export DEBIAN_FRONTEND=noninteractive

print_info "Starting system repair for user '$TARGET_USER'..."

# --- Section 1: Clean System and Install Node.js, pnpm via nvm ---
print_info "Step 1: Removing any system-level Node.js installations..."
apt-get purge -y nodejs npm
apt-get autoremove -y
print_success "Old Node.js packages have been purged."

print_info "Installing nvm for user '$TARGET_USER'..."
# Run the nvm install script as the target user
sudo -u "$TARGET_USER" bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
print_success "nvm installed in $TARGET_HOME/.nvm"

print_info "Installing Node.js v22 using nvm..."
# Source nvm and install Node.js in a subshell as the target user
sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && nvm install 22"
print_success "Node.js v22 has been successfully installed."

print_info "Enabling Corepack and installing pnpm..."
# Enable corepack and install pnpm as the target user
sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && corepack enable && corepack prepare pnpm@latest --activate"
print_success "pnpm has been successfully installed via Corepack."


# --- Section 2: Install Docker ---
print_info "Step 2: Setting up Docker for Debian..."

# Install prerequisite packages
apt-get install -y ca-certificates curl
print_success "Prerequisite packages installed."

# Add Docker's official GPG key for Debian
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
print_success "Docker GPG key added."

# Add the Docker repository for Debian
OS_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $OS_CODENAME stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null
print_success "Docker repository for Debian ($OS_CODENAME) configured."

# Update package lists and install Docker Engine
apt-get update
print_info "Installing Docker Engine, CLI, and Compose plugin..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
print_success "Docker has been successfully installed."


# --- Section 3: Post-Installation Configuration ---
print_info "Step 3: Configuring Docker for non-root user '$TARGET_USER'..."
if id -nG "$TARGET_USER" | grep -qw "docker"; then
    print_info "User '$TARGET_USER' is already in the 'docker' group."
else
    usermod -aG docker "$TARGET_USER"
    print_success "User '$TARGET_USER' has been added to the 'docker' group."
fi

# --- Section 4: Final Verification ---
print_info "Step 4: Installation summary:"
echo "-------------------------------------"
# Verify nvm-installed tools by running the checks as the target user
NODE_VER=$(sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && node -v")
NPM_VER=$(sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && npm -v")
PNPM_VER=$(sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && pnpm -v")
echo "Node version:    $NODE_VER (via nvm)"
echo "npm version:     $NPM_VER (via nvm)"
echo "pnpm version:    $PNPM_VER (via Corepack)"
echo -n "Docker version:  "
docker --version
echo -n "Compose version: "
docker compose version
echo "-------------------------------------"

print_success "Repair and installation script finished successfully!"
print_warning "IMPORTANT: A terminal restart (or logout/login) is required for all changes to take effect."
print_warning "This is needed for nvm/pnpm to be available and to use 'docker' without 'sudo'."