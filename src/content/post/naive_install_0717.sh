#!/bin/bash

# ==============================================================================
#                       All-in-One Server Deployment Script
#
# This script provides a menu-driven interface to:
#   1. Install/Repair essential tools (Git, Docker, NVM, Node, pnpm, Gemini CLI)
#   2. Deploy NaiveProxy with a custom-built Caddy (and install Naive client)
#   3. Deploy Vaultwarden via Docker
#   4. Deploy MoonTV via Docker
#
# Usage:
#   1. Save this script as deploy.sh
#   2. Make it executable: chmod +x deploy.sh
#   3. Run with sudo for full functionality: sudo ./deploy.sh
#
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

# --- Global Variables ---
DOMAIN=""
EMAIL=""
USERNAME=""
PASSWORD=""
PROXY_PATH=""
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
    echo -e "     (Git, Docker, NVM, Node, pnpm, Gemini CLI)"
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
    DEFAULT_PROXY_PATH="/mysecretpath"

    read -p "請輸入您的主域名 [${DEFAULT_DOMAIN}]: " CUSTOM_DOMAIN
    DOMAIN=${CUSTOM_DOMAIN:-$DEFAULT_DOMAIN}
    read -p "請輸入您的 Email (用於 TLS 證書) [${DEFAULT_EMAIL}]: " CUSTOM_EMAIL
    EMAIL=${CUSTOM_EMAIL:-$DEFAULT_EMAIL}
    read -p "請輸入 NaiveProxy 的使用者名稱 [${DEFAULT_USERNAME}]: " CUSTOM_USERNAME
    USERNAME=${CUSTOM_USERNAME:-$DEFAULT_USERNAME}
    read -p "請輸入 NaiveProxy 的密碼 [${DEFAULT_PASSWORD}]: " CUSTOM_PASSWORD
    PASSWORD=${CUSTOM_PASSWORD:-$DEFAULT_PASSWORD}
    read -p "請輸入 NaiveProxy 的專用代理路徑 [${DEFAULT_PROXY_PATH}]: " CUSTOM_PROXY_PATH
    PROXY_PATH=${CUSTOM_PROXY_PATH:-$DEFAULT_PROXY_PATH}
    CONFIG_SET=true
    print_success "基本資訊設定完成！"
    echo
}

# Check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_warning "Docker 尚未安裝。"
        print_warning "請先選擇菜單中的 '1. 安裝/修復常用工具' 來安裝 Docker。"
        return 1
    fi
    return 0
}

# Option 1: Install Common Tools
install_common_tools() {
    print_info "開始執行系統工具安裝/修復程序..."

    print_info "Step 1.1: 移除任何系統級的 Node.js..."
    apt-get purge -y nodejs npm > /dev/null 2>&1 || true
    apt-get autoremove -y > /dev/null 2>&1
    print_success "舊的 Node.js 套件已被清除。"

    print_info "Step 1.2: 安裝 Git 和 Netcat..."
    apt-get install -y git netcat-openbsd
    print_success "Git 和 Netcat (nc) 已成功安裝。"

    print_info "Step 2.1: 為使用者 '$TARGET_USER' 安裝 nvm..."
    sudo -u "$TARGET_USER" bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash'
    print_success "nvm 已安裝於 $TARGET_HOME/.nvm"

    print_info "Step 2.2: 使用 nvm 安裝 Node.js v22..."
    sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && nvm install 22"
    print_success "Node.js v22 已成功安裝。"

    print_info "Step 2.3: 啟用 Corepack 並安裝 pnpm..."
    sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && corepack enable && corepack prepare pnpm@latest --activate"
    print_success "pnpm 已透過 Corepack 成功安裝。"

    print_info "Step 2.4: 安裝 Gemini CLI..."
    read -p "是否要安裝 Google Gemini CLI? (y/N): " confirm_gemini
    if [[ "$confirm_gemini" =~ ^[yY](es)*$ ]]; then
        sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && npm install -g @google/gemini-cli"
        print_success "Google Gemini CLI 已成功安裝。"
    else
        print_warning "已跳過安裝 Gemini CLI。"
    fi

    print_info "Step 3: 為 Debian 系統設定 Docker..."
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    print_info "正在安裝 Docker Engine, CLI, 和 Compose plugin..."
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    print_success "Docker 已成功安裝。"

    print_info "Step 4: 為使用者 '$TARGET_USER' 設定 Docker 免 sudo..."
    if ! getent group docker > /dev/null; then
        groupadd docker
        print_success "已創建 'docker' 群組。"
    fi
    usermod -aG docker "$TARGET_USER"
    print_success "使用者 '$TARGET_USER' 已被加入 'docker' 群組。"

    print_success "工具安裝/修復程序已完成！"
    print_warning "重要：需要重新登入終端機才能讓所有變更生效 (nvm 和 docker 免 sudo)。"
}

# Option 2: Deploy NaiveProxy + Caddy (Full version)
deploy_naiveproxy() {
    interactive_setup
    print_info "--- 開始完整部署 NaiveProxy + Caddy ---"

    print_info "步驟 2.1: 清理舊的 Caddy 和 Go 安裝..."
    if systemctl is-active --quiet caddy.service; then
        systemctl stop caddy
    fi
    apt-get purge -y caddy golang-go > /dev/null 2>&1 || true
    apt-get autoremove -y > /dev/null 2>&1
    rm -rf /usr/local/go
    print_success "舊環境已清理完畢。"

    print_info "步驟 2.2: 安裝最新的 Go 語言環境..."
    GO_LATEST_VERSION=$(curl -s "https://go.dev/VERSION?m=text" | head -n 1)
    GO_FILENAME="${GO_LATEST_VERSION}.linux-amd64.tar.gz"
    DOWNLOAD_URL="https://go.dev/dl/${GO_FILENAME}"
    echo "正在下載 ${DOWNLOAD_URL}"
    curl -L -o "/tmp/${GO_FILENAME}" "${DOWNLOAD_URL}"
    tar -C /usr/local -xzf "/tmp/${GO_FILENAME}"
    rm "/tmp/${GO_FILENAME}"
    # 永久性地設定 Go 的 PATH
    if [ ! -f "/etc/profile.d/go.sh" ]; then
        echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh
    fi
    source /etc/profile.d/go.sh
    print_success "Go 已成功安裝。 $(go version)"

    print_info "步驟 2.3: 編譯包含 forwardproxy 插件的 Caddy..."
    export GOPATH=/root/go
    /usr/local/go/bin/go install github.com/caddyserver/xcaddy/cmd/xcaddy@latest
    $GOPATH/bin/xcaddy build --with github.com/caddyserver/forwardproxy@caddy2
    print_success "Caddy 編譯成功。"

    print_info "步驟 2.4: 安裝 Caddy 二進位檔..."
    mv ./caddy /usr/bin/caddy
    chmod +x /usr/bin/caddy
    print_success "Caddy 已安裝至 /usr/bin/caddy。"

    print_info "步驟 2.5: 設定 Caddy 系統服務與 Caddyfile..."
    groupadd --system caddy || true
    useradd --system --gid caddy --home-dir /var/lib/caddy --shell /usr/sbin/nologin caddy || true
    mkdir -p /etc/caddy /var/www/html /var/log/caddy /var/lib/caddy
    chown -R caddy:caddy /etc/caddy /var/www/html /var/log/caddy /var/lib/caddy
    
    tee /etc/caddy/Caddyfile > /dev/null <<EOF
# This Caddyfile is auto-generated to support both a website and a proxy.

${DOMAIN} {
    tls ${EMAIL}
    log {
        output file /var/log/caddy/${DOMAIN}.log
    }

    # ROUTE 1: Handle proxy traffic on the dedicated secret path.
    route ${PROXY_PATH} {
        forward_proxy {
            basic_auth ${USERNAME} ${PASSWORD}
            probe_resistance ${DOMAIN}
        }
    }

    # ROUTE 2: Handle all other traffic by serving the website.
    file_server {
        root /var/www/html
    }
}
EOF
    chown caddy:caddy /etc/caddy/Caddyfile

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
    print_success "Caddy 系統服務與 Caddyfile 設定完成。"

    print_info "步驟 2.6: 啟動 Caddy 服務並下載網站內容..."
    systemctl daemon-reload
    systemctl enable --now caddy
    mkdir -p /var/www/html
    WEBSITE_URL="https://raw.githubusercontent.com/stallonefennec/writings/main/src/content/post/bigdays.tar.gz"
    WEBSITE_ARCHIVE="/tmp/bigdays.tar.gz"
    echo "Downloading website content from ${WEBSITE_URL}"
    curl -L -o "${WEBSITE_ARCHIVE}" "${WEBSITE_URL}"
    echo "Extracting content to /var/www/html/"
    tar -xzf "${WEBSITE_ARCHIVE}" -C /var/www/html/
    echo "Setting ownership for web content..."
    chown -R caddy:caddy /var/www/html
    echo "Cleaning up temporary archive..."
    rm "${WEBSITE_ARCHIVE}"
    print_success "Caddy 服務已啟動且網站內容已部署。"

    # --- 【新增功能】安裝 NaiveProxy 客戶端工具 ---
    print_info "步驟 2.7: 安裝 NaiveProxy 客戶端工具 (naive)..."
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/klzgrad/naiveproxy/releases/latest" | grep -Po '"tag_name": "\K.*?(?=")')
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        ARCH="linux-x64"
    elif [ "$ARCH" = "aarch64" ]; then
        ARCH="linux-arm64"
    else
        echo "Unsupported architecture for NaiveProxy binary: $ARCH"
        print_warning "無法安裝 NaiveProxy 客戶端工具。"
        # Do not exit the whole script, just skip this part
    fi

    if [ -n "$ARCH" ]; then
        NAIVE_FILENAME="naiveproxy-${LATEST_VERSION}-${ARCH}.tar.xz"
        DOWNLOAD_URL="https://github.com/klzgrad/naiveproxy/releases/download/${LATEST_VERSION}/${NAIVE_FILENAME}"
        echo "正在從 ${DOWNLOAD_URL} 下載"
        rm -f "/tmp/${NAIVE_FILENAME}"
        curl -L -o "/tmp/${NAIVE_FILENAME}" "${DOWNLOAD_URL}"
        tar -xf "/tmp/${NAIVE_FILENAME}" -C /tmp
        mv "/tmp/naiveproxy-${LATEST_VERSION}-${ARCH}/naive" /usr/local/bin/
        chmod +x /usr/local/bin/naive
        rm -rf "/tmp/naiveproxy-${LATEST_VERSION}-${ARCH}"
        print_success "NaiveProxy 客戶端工具 'naive' 已安裝至 /usr/local/bin/"
    fi

    print_success "NaiveProxy + Caddy 完整部署完成！"
    echo "您的網站位址: https://${DOMAIN}"
    echo "您的 NaiveProxy 位址: https://${USERNAME}:${PASSWORD}@${DOMAIN}${PROXY_PATH}"
}

# Option 3: Deploy Vaultwarden
deploy_vaultwarden() {
    if ! check_docker; then return; fi
    interactive_setup
    print_info "開始部署 Vaultwarden..."
    local DEPLOY_DIR="$TARGET_HOME/docker_deploys/vaultwarden"
    sudo -u "$TARGET_USER" mkdir -p "${DEPLOY_DIR}/data"

    sudo -u "$TARGET_USER" tee "${DEPLOY_DIR}/docker-compose.yml" > /dev/null <<EOF
version: '3'
services:
  vaultwarden:
    image: vaultwarden/server:latest
    container_name: vaultwarden
    restart: always
    ports:
      - "127.0.0.1:8080:80"
    volumes:
      - ./data:/data
EOF

    print_info "正在啟動 Vaultwarden 容器..."
    (cd "${DEPLOY_DIR}" && docker compose up -d)

    print_info "正在更新 Caddy 設定..."
    # Check if the block already exists to prevent duplicates
    if ! grep -q "vaultwarden.${DOMAIN}" /etc/caddy/Caddyfile; then
        tee -a /etc/caddy/Caddyfile > /dev/null <<EOF

# --- Vaultwarden Service ---
vaultwarden.${DOMAIN} {
    tls ${EMAIL}
    reverse_proxy localhost:8080
    log {
        output file /var/log/caddy/vaultwarden.${DOMAIN}.log
    }
}
EOF
        systemctl reload caddy
        print_success "Vaultwarden 已部署！位址: https://vaultwarden.${DOMAIN}"
    else
        print_warning "Vaultwarden 的 Caddy 設定已存在，跳過更新。"
    fi
}

# Option 4: Deploy MoonTV
deploy_moontv() {
    if ! check_docker; then return; fi
    interactive_setup
    print_info "開始部署 MoonTV..."
    local DEPLOY_DIR="$TARGET_HOME/docker_deploys/moontv"
    sudo -u "$TARGET_USER" mkdir -p "${DEPLOY_DIR}"

    sudo -u "$TARGET_USER" tee "${DEPLOY_DIR}/docker-compose.yml" > /dev/null <<EOF
services:
  moontv:
    image: ghcr.io/senshinya/moontv:latest
    container_name: moontv
    restart: unless-stopped
    ports:
      - '127.0.0.1:3000:3000'
    environment:
      - PASSWORD=moontv
EOF

    print_info "正在啟動 MoonTV 容器..."
    (cd "${DEPLOY_DIR}" && docker compose up -d)

    print_info "正在更新 Caddy 設定..."
    if ! grep -q "moon.${DOMAIN}" /etc/caddy/Caddyfile; then
        tee -a /etc/caddy/Caddyfile > /dev/null <<EOF

# --- MoonTV Service ---
moon.${DOMAIN} {
    tls ${EMAIL}
    reverse_proxy localhost:3000
    log {
        output file /var/log/caddy/moon.${DOMAIN}.log
    }
}
EOF
        systemctl reload caddy
        print_success "MoonTV 已部署！位址: https://moon.${DOMAIN}"
    else
        print_warning "MoonTV 的 Caddy 設定已存在，跳過更新。"
    fi
}

# --- Main Logic ---

# 1. Ensure the script is run with sudo privileges
if [ "$EUID" -ne 0 ]; then
    print_warning "此腳本需要超級使用者權限。請使用 'sudo' 來運行。"
    exit 1
fi

# Get the user who invoked sudo, not root
TARGET_USER=${SUDO_USER:-$(whoami)}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

# Set non-interactive frontend to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Main menu loop
while true; do
    show_main_menu
    read -p "請輸入您的選擇 [1-5]: " choice

    case $choice in
        1)
            install_common_tools
            ;;
        2)
            deploy_naiveproxy
            ;;
        3)
            deploy_vaultwarden
            ;;
        4)
            deploy_moontv
            ;;
        5)
            echo "正在退出腳本。再見！"
            break
            ;;
        *)
            print_warning "無效的選擇，請重新輸入。"
            ;;
    esac
    read -p "按 Enter 鍵返回主菜單..."
done