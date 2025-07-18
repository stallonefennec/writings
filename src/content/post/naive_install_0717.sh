#!/bin/bash

# ==============================================================================
#                       All-in-One Server Deployment Script
#
# This script provides a menu-driven interface to:
#   1. Install/Repair essential tools (Git, Docker, NVM, Node, pnpm, Gemini CLI)
#   2. Deploy NaiveProxy with a custom-built Caddy
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

    print_info "Step 1.2: 安裝 Git..."
    if ! command -v git &> /dev/null; then
        apt-get install -y git
        print_success "Git 安裝完成。"
    else
        print_info "Git 已經安裝。"
    fi

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
    sudo -u "$TARGET_USER" bash -c "source $TARGET_HOME/.nvm/nvm.sh && npm install -g @google/gemini-cli"
    print_success "Google Gemini CLI 已成功安裝。"

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
    rm "/tmp/${GO_