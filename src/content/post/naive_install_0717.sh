#!/bin/bash

# ==============================================================================
#                      All-in-One Server Deployment Script (v3.5 - Caddy Fix)
#
# This script provides a menu-driven interface to:
#   1. Install/Repair essential tools (Git, Docker, NVM, Node, Gemini, etc.)
#   2. Deploy NaiveProxy with a custom-built Caddy (with root-build fix)
#   3. Deploy Vaultwarden via Docker
#   4. Deploy MoonTV via Docker
#
# Changelog v3.5:
#   - Fixed Caddy startup failure by ensuring /var/lib/caddy exists with
#     correct permissions before starting the service. This makes the script
#     more robust for re-runs.
# ==============================================================================

# --- Color Definitions ---
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'

# --- Helper Functions ---
print_info() {
    echo -e "\n${C_BLUE}[INFO] $1${C_RESET}"
}

print_success() {
    echo -e "${C_GREEN}[SUCCESS] $1${C_RESET}"
}

print_warning() {
    echo -e "${C_YELLOW}[WARNING] $1${C_RESET}"
}

print_error() {
    echo -e "${C_RED}[ERROR] $1${C_RESET}"
}

# --- Global Variables ---
DOMAIN=""
EMAIL=""
USERNAME=""
PASSWORD=""
CONFIG_SET=false

# --- Function Definitions ---

# Show the main menu
show_main_menu() {
    clear
    echo -e "${C_CYAN}=====================================================${C_RESET}"
    echo -e "${C_CYAN} 全功能伺服器部署腳本 (All-in-One Deploy Script) ${C_RESET}"
    echo -e "${C_CYAN}=====================================================${C_RESET}"
    echo -e " 您想執行哪個操作？"
    echo
    echo -e " ${C_YELLOW}1.${C_RESET} 安裝/修復常用工具 (Install/Repair Common Tools)"
    echo -e "     (Git, Docker, NVM, Node, pnpm, Gemini CLI, Website)"
    echo
    echo -e " ${C_YELLOW}2.${C_RESET} 部署 NaiveProxy + Caddy (包含編譯)"
    echo
    echo -e " ${C_YELLOW}3.${C_RESET} 部署 Vaultwarden (使用 Docker)"
    echo
    echo -e " ${C_YELLOW}4.${C_RESET} 部署 MoonTV (使用 Docker)"
    echo
    echo -e " ${C_YELLOW}5.${C_RESET} 退出腳本 (Exit)"
    echo
    echo -e "${C_CYAN}-----------------------------------------------------${C_RESET}"
}

# Interactive setup for domain, email, etc.
interactive_setup() {
    if [ "$CONFIG_SET" = true ]; then
        return
    fi
    print_info "首次設定：請輸入您的基本資訊"
    DEFAULT_DOMAIN="fennec-lucky.com"
    DEFAULT_EMAIL="stalloneiv@gmail.com"
    DEFAULT_USERNAME="stallone"
    DEFAULT_PASSWORD="198964"

    read -p "請輸入您的主域名 [${DEFAULT_DOMAIN}]: " CUSTOM_DOMAIN
    DOMAIN=${CUSTOM_DOMAIN:-$DEFAULT_DOMAIN}
    read -p "請輸入您的 Email (用於 TLS 證書) [${DEFAULT_EMAIL}]: " CUSTOM_EMAIL
    EMAIL=${CUSTOM_EMAIL:-$DEFAULT_EMAIL}
    read -p "請輸入 NaiveProxy 的使用者名稱 [${DEFAULT_USERNAME}]: " CUSTOM_USERNAME
    USERNAME=${CUSTOM_USERNAME:-$DEFAULT_USERNAME}
    read -p "請輸入 NaiveProxy 的密碼 [${DEFAULT_PASSWORD}]: " CUSTOM_PASSWORD
    PASSWORD=${CUSTOM_PASSWORD:-$DEFAULT_PASSWORD}
    
    CONFIG_SET=true
    print_success "基本資訊設定完成！"
    echo
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed."
        print_warning "Please run '1. Install/Repair Common Tools' first to install Docker."
        return 1
    fi
    return 0
}

# Central function to generate Caddyfile based on running containers
update_caddyfile() {
    print_info "Generating Caddyfile based on active services..."
    mkdir -p /etc/caddy /var/log/caddy

    tee /etc/caddy/Caddyfile > /dev/null <<EOF
{
    order forward_proxy before file_server
}

:443, ${DOMAIN} {
    tls ${EMAIL}
    forward_proxy {
        basic_auth ${USERNAME} ${PASSWORD}
        probe_resistance
    }
    file_server {
        root /var/www/html
    }
    log {
        output file /var/log/caddy/main.${DOMAIN}.log
    }
}
EOF

    if docker ps -q --filter "name=vaultwarden" | grep -q .; then
        print_info "Vaultwarden container found. Adding to Caddyfile."
        cat >> /etc/caddy/Caddyfile <<EOF

vaultwarden.${DOMAIN} {
    reverse_proxy localhost:8080
    log {
        output file /var/log/caddy/vaultwarden.${DOMAIN}.log
    }
}
EOF
    fi

    if docker ps -q --filter "name=moontv" | grep -q .; then
        print_info "MoonTV container found. Adding to Caddyfile."
        cat >> /etc/caddy/Caddyfile <<EOF

moon.${DOMAIN} {
    reverse_proxy localhost:3000
    log {
        output file /var/log/caddy/moon.${DOMAIN}.log
    }
}
EOF
    fi

    chown -R caddy:caddy /etc/caddy /var/log/caddy
    if systemctl is-active --quiet caddy; then
        print_info "Reloading Caddy service to apply new configuration..."
        systemctl reload caddy
    fi
    print_success "Caddyfile has been updated."
}

# ==============================================================================
#            vvv THIS FUNCTION IS NOW RESTORED TO ITS FULL VERSION vvv
# ==============================================================================
# Option 1: Install Common Tools
install_common_tools() {
    print_info "Starting system tools installation..."

    print_info "Step 1.1: Removing any system-level Node.js..."
    apt-get purge -y nodejs npm > /dev/null 2>&1 || true
    apt-get autoremove -y > /dev/null 2>&1

    print_info "Step 1.2: Installing base packages (Git, Curl, etc.)..."
    apt-get update
    apt-get install -y git netcat-openbsd curl gnupg ca-certificates

    print_info "Step 2.1: Installing nvm for user '$TARGET_USER'..."
    sudo -u "$TARGET_USER" bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'

    print_info "Step 2.2: Installing Node.js v22 via nvm..."
    sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && nvm install 22"

    print_info "Step 2.3: Enabling Corepack and installing pnpm..."
    sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && corepack enable && corepack prepare pnpm@latest --activate"

    print_info "Step 2.4: Installing Gemini CLI..."
    read -p "Do you want to install Google Gemini CLI? (y/N): " confirm_gemini
    if [[ "$confirm_gemini" =~ ^[yY](es)*$ ]]; then
        sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && npm install -g @google/gemini-cli"
        print_success "Google Gemini CLI installed."
    else
        print_warning "Skipped Gemini CLI installation."
    fi

    print_info "Step 3: Setting up Docker repository for Debian..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    print_success "Docker installed."

    print_info "Step 4: Configuring Docker for user '$TARGET_USER' (no sudo)..."
    if ! getent group docker > /dev/null; then
        groupadd docker
    fi
    usermod -aG docker "$TARGET_USER"
    print_success "User '$TARGET_USER' added to 'docker' group."

    print_info "Step 5: Setting up camouflage website..."
    mkdir -p /var/www/html
    WEBSITE_URL="https://raw.githubusercontent.com/stallonefennec/writings/main/src/content/post/bigdays.tar.gz"
    WEBSITE_ARCHIVE="/tmp/bigdays.tar.gz"
    curl -L -o "${WEBSITE_ARCHIVE}" "${WEBSITE_URL}"
    tar -xzf "${WEBSITE_ARCHIVE}" -C /var/www/html/
    rm "${WEBSITE_ARCHIVE}"
    chown -R www-data:www-data /var/www/html
    print_success "Camouflage website deployed."
    
    print_success "Tools installation complete!"
    print_warning "IMPORTANT: You MUST log out and log back in for all changes (nvm, docker no-sudo) to take effect."
}

# ==============================================================================
#            vvv THIS FUNCTION HAS THE PROVEN ROOT-BUILD FIX vvv
# ==============================================================================
# Option 2: Deploy NaiveProxy
deploy_naiveproxy() {
    interactive_setup

    print_info "Starting NaiveProxy and Caddy installation..."
    set -e 

    print_info "Step 1: Uninstalling existing Caddy and old Go..."
    if systemctl list-units --type=service | grep -q caddy.service; then
        systemctl stop caddy || true
        systemctl disable caddy || true
    fi
    apt-get purge -y caddy golang-go > /dev/null 2>&1
    apt-get autoremove -y > /dev/null 2>&1
    rm -rf /usr/local/go /usr/bin/caddy /etc/caddy /var/lib/caddy /etc/systemd/system/caddy.service /usr/local/bin/xcaddy /root/go

    print_info "Step 2: Installing latest Go (as root)..."
    GO_LATEST_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
    GO_FILENAME="${GO_LATEST_VERSION}.linux-amd64.tar.gz"
    DOWNLOAD_URL="https://go.dev/dl/${GO_FILENAME}"
    curl -L -o "/tmp/${GO_FILENAME}" "${DOWNLOAD_URL}"
    tar -C /usr/local -xzf "/tmp/${GO_FILENAME}"
    rm "/tmp/${GO_FILENAME}"
    export PATH=$PATH:/usr/local/go/bin
    /usr/local/go/bin/go version

    print_info "Step 3: Building Caddy (as root, mimicking 0706.sh)..."
    /usr/local/go/bin/go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    print_info "Compiling Caddy using xcaddy from /root/go/bin..."
    /root/go/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2
    
    print_info "Step 4: Installing the new Caddy binary..."
    mv ./caddy /usr/bin/caddy
    chmod +x /usr/bin/caddy
    setcap cap_net_bind_service=+ep /usr/bin/caddy

    print_info "Step 5: Setting up Caddy user and systemd service..."
    groupadd --system caddy || true
    useradd --system --gid caddy --create-home --home-dir /var/lib/caddy \
        --shell /usr/sbin/nologin --comment "Caddy web server" caddy || true
    
    tee /etc/systemd/system/caddy.service > /dev/null <<'EOF'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target
[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
LimitNPROC=512
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
[Install]
WantedBy=multi-user.target
EOF

    print_info "Step 6: Downloading and installing NaiveProxy binary..."
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/klzgrad/naiveproxy/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then ARCH_SUFFIX="linux-x64"; elif [ "$ARCH" = "aarch64" ]; then ARCH_SUFFIX="linux-arm64"; else print_error "Unsupported architecture: $ARCH"; set +e; return 1; fi
    NAIVE_FILENAME="naiveproxy-${LATEST_VERSION}-${ARCH_SUFFIX}.tar.xz"
    DOWNLOAD_URL="https://github.com/klzgrad/naiveproxy/releases/download/${LATEST_VERSION}/${NAIVE_FILENAME}"
    curl -L -o "/tmp/${NAIVE_FILENAME}" "${DOWNLOAD_URL}"
    tar -xf "/tmp/${NAIVE_FILENAME}" -C /tmp
    mv "/tmp/naiveproxy-${LATEST_VERSION}-${ARCH_SUFFIX}/naive" /usr/local/bin/
    chmod +x /usr/local/bin/naive
    rm -rf "/tmp/naiveproxy-${LATEST_VERSION}-${ARCH_SUFFIX}" "/tmp/${NAIVE_FILENAME}"
    print_success "NaiveProxy binary installed to /usr/local/bin/naive"

    print_info "Step 7: Generating Caddyfile..."
    update_caddyfile

    print_info "Step 8: Setting permissions and starting Caddy..."
    # >>>>>>>> FIX START <<<<<<<<
    # Ensure Caddy's data directory exists and has correct permissions.
    # This is crucial because Step 1 removes it, and Step 5 might not recreate it
    # if the 'caddy' user already exists, causing TLS cert errors.
    print_info "Ensuring Caddy's data directory exists with correct permissions..."
    mkdir -p /var/lib/caddy
    chown -R caddy:caddy /var/lib/caddy
    # >>>>>>>> FIX END <<<<<<<<

    chown -R caddy:caddy /var/www/html
    systemctl daemon-reload
    systemctl enable --now caddy
    
    print_success "Caddy & NaiveProxy (forwardproxy) installation complete."
    systemctl status caddy --no-pager
    set +e 
}

# Option 3 & 4: Deploy Vaultwarden / MoonTV
deploy_vaultwarden() {
    if ! check_docker; then return; fi
    interactive_setup
    print_info "Deploying Vaultwarden..."
    local DEPLOY_DIR="$TARGET_HOME/docker_deploys/vaultwarden"
    sudo -u "$TARGET_USER" mkdir -p "${DEPLOY_DIR}/data"
    sudo -u "$TARGET_USER" tee "${DEPLOY_DIR}/docker-compose.yml" > /dev/null <<EOF
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    ports: ["127.0.0.1:8080:80"]
    volumes: ["./data:/data"]
EOF
    print_info "Starting Vaultwarden container..."
    (cd "${DEPLOY_DIR}" && sudo -u "$TARGET_USER" docker compose up -d)
    print_info "Updating Caddy configuration..."
    update_caddyfile
    print_success "Vaultwarden deployed! Access at: https://vaultwarden.${DOMAIN}"
}

deploy_moontv() {
    if ! check_docker; then return; fi
    interactive_setup
    print_info "Deploying MoonTV..."
    local DEPLOY_DIR="$TARGET_HOME/docker_deploys/moontv"
    sudo -u "$TARGET_USER" mkdir -p "${DEPLOY_DIR}"
    sudo -u "$TARGET_USER" tee "${DEPLOY_DIR}/docker-compose.yml" > /dev/null <<EOF
services:
  moontv:
    image: ghcr.io/senshinya/moontv:latest
    container_name: moontv
    restart: unless-stopped
    ports: ['127.0.0.1:3000:3000']
    environment: [PASSWORD=moontv]
EOF
    print_info "Starting MoonTV container..."
    (cd "${DEPLOY_DIR}" && sudo -u "$TARGET_USER" docker compose up -d)
    print_info "Updating Caddy configuration..."
    update_caddyfile
    print_success "MoonTV deployed! Access at: https://moon.${DOMAIN}"
}

# --- Main Logic ---
if [ "$EUID" -ne 0 ]; then
    print_error "This script requires superuser privileges. Please run with 'sudo'."
    exit 1
fi
TARGET_USER=${SUDO_USER:-$(whoami)}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
export DEBIAN_FRONTEND=noninteractive
while true; do
    show_main_menu
    read -p "請輸入您的選擇 [1-5]: " choice
    case $choice in
        1) install_common_tools ;;
        2) deploy_naiveproxy ;;
        3) deploy_vaultwarden ;;
        4) deploy_moontv ;;
        5) echo "Exiting script. Goodbye!"; break ;;
        *) print_warning "Invalid choice, please try again." ;;
    esac
    read -p "Press Enter to return to the main menu..."
done